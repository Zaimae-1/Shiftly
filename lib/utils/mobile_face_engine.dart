import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'face_recognizer.dart';
import 'mobile_face_preprocessing.dart';
import 'mobile_face_recognizer.dart';

/// Native only; never imported by the web build. This app-level service retains
/// the interpreter between scans. Each request is serialized, even if a UI
/// timeout has already stopped waiting for the preceding request.
class MobileFaceEngine implements MobileFaceExtractor {
  Interpreter? _interpreter;
  Future<void>? _preparing, _pending;
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: .10,
    ),
  );

  @override
  Future<void> prepare() {
    if (_interpreter != null) return Future.value();
    return _preparing ??= _load().whenComplete(() => _preparing = null);
  }

  Future<void> _load() async {
    Interpreter? interpreter;
    final options = InterpreterOptions()..threads = 2;
    try {
      interpreter = await Interpreter.fromAsset(
        'assets/models/mobilefacenet.tflite',
        options: options,
      );
      final input = interpreter.getInputTensor(0),
          output = interpreter.getOutputTensor(0);
      if (!listEquals(input.shape, [1, 112, 112, 3]) ||
          !listEquals(output.shape, [1, 192]) ||
          input.type != TensorType.float32 ||
          output.type != TensorType.float32) {
        throw StateError(
          'Model contract must be float32 [1,112,112,3] -> [1,192]',
        );
      }
      _interpreter = interpreter;
    } catch (error) {
      interpreter?.close();
      debugPrint('MobileFaceNet initialization: $error');
      throw const FaceRecognitionException(
        'MobileFaceNet belum dapat dimuat. Tutup dan buka kembali aplikasi, lalu coba lagi.',
      );
    } finally {
      options.delete();
    }
  }

  @override
  Future<MobileFaceObservation> extract(Uint8List photo) {
    final operation = (_pending ?? Future<void>.value()).then(
      (_) => _extract(photo),
    );
    final tail = operation.then<void>(
      (_) {},
      onError: (Object e, StackTrace s) {},
    );
    _pending = tail;
    tail.then((_) {
      if (identical(_pending, tail)) _pending = null;
    });
    return operation;
  }

  Future<MobileFaceObservation> _extract(Uint8List photo) async {
    await prepare();
    Directory? scratch;
    try {
      final upright = await compute(prepareMobilePhoto, photo);
      // ML Kit reads this exact upright image, so its landmarks and the model's
      // sampled pixels share one coordinate system on Android and iOS.
      scratch = await Directory(
        (await getTemporaryDirectory()).path,
      ).createTemp('hadir-face-');
      final file = File('${scratch.path}/upright.jpg');
      await file.writeAsBytes(upright, flush: true);
      final faces = await _detector.processImage(
        InputImage.fromFilePath(file.path),
      );
      if (faces.isEmpty) {
        return const MobileFaceObservation(MobileFaceQuality.noFace);
      }
      if (faces.length != 1) {
        return const MobileFaceObservation(MobileFaceQuality.multiple);
      }
      final face = faces.single;
      if (face.boundingBox.shortestSide < 64 ||
          (face.headEulerAngleY?.abs() ?? 90) > 25 ||
          (face.headEulerAngleX?.abs() ?? 90) > 25) {
        return const MobileFaceObservation(MobileFaceQuality.unclear);
      }
      final required = [
        FaceLandmarkType.leftEye,
        FaceLandmarkType.rightEye,
        FaceLandmarkType.noseBase,
        FaceLandmarkType.leftMouth,
        FaceLandmarkType.rightMouth,
      ];
      if (required.any((type) => face.landmarks[type] == null)) {
        return const MobileFaceObservation(MobileFaceQuality.unclear);
      }
      math.Point<double> point(FaceLandmarkType type) {
        final p = face.landmarks[type]!.position;
        return math.Point(p.x.toDouble(), p.y.toDouble());
      }

      final eyes = [point(required[0]), point(required[1])]
        ..sort((a, b) => a.x.compareTo(b.x));
      final mouth = [point(required[3]), point(required[4])]
        ..sort((a, b) => a.x.compareTo(b.x));
      if (eyes.last.x - eyes.first.x < 12) {
        return const MobileFaceObservation(MobileFaceQuality.unclear);
      }
      final input = await compute(mobileFaceInput, (
        upright,
        [...eyes, point(FaceLandmarkType.noseBase), ...mouth],
      ));
      final address = _interpreter!.address;
      final embedding = await compute(_runMobileInterpreter, (address, input));
      return MobileFaceObservation(
        MobileFaceQuality.face,
        normalizeMobileEmbedding(embedding),
        FaceCapturePose(
          smiling: (face.smilingProbability ?? 0) >= .7,
          facingCamera:
              (face.headEulerAngleY?.abs() ?? 90) <= 15 &&
              (face.headEulerAngleX?.abs() ?? 90) <= 15 &&
              (face.headEulerAngleZ?.abs() ?? 90) <= 12 &&
              (face.leftEyeOpenProbability ?? 0) >= .55 &&
              (face.rightEyeOpenProbability ?? 0) >= .55,
        ),
      );
    } on FormatException {
      return const MobileFaceObservation(MobileFaceQuality.unclear);
    } catch (error) {
      debugPrint('MobileFaceNet extraction: $error');
      throw const FaceRecognitionException(
        'Wajah belum dapat dianalisis. Coba ulang dengan foto yang lebih jelas.',
      );
    } finally {
      if (scratch != null) {
        try {
          await scratch.delete(recursive: true);
        } catch (_) {
          /* Temporary OS cache only. */
        }
      }
    }
  }
}

// A top-level worker avoids accidentally sending a detector/native resource
// captured by an instance closure to another isolate. Errors propagate normally.
List<double> _runMobileInterpreter((int, Float32List) request) {
  final (address, input) = request;
  // ByteBuffer keeps the declared tensor shape. A flat Dart list would
  // otherwise resize it to [37632] in tflite_flutter.
  final output = [List<double>.filled(192, 0)];
  Interpreter.fromAddress(address).run(input.buffer, output);
  return output.single;
}
