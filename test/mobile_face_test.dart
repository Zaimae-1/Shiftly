import 'dart:math' as math;
import 'package:attendance_app/ui/attendance_history/attendance_history_screen.dart';
import 'package:attendance_app/utils/face_backend.dart';
import 'package:attendance_app/utils/face_recognizer.dart';
import 'package:attendance_app/utils/mobile_face_preprocessing.dart';
import 'package:attendance_app/utils/mobile_face_recognizer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

class _Extractor implements MobileFaceExtractor {
  MobileFaceObservation result;
  _Extractor(this.result);
  @override
  Future<void> prepare() async {}
  @override
  Future<MobileFaceObservation> extract(Uint8List photo) async => result;
}

void main() {
  List<double> embedding(double angle) => [
    math.cos(angle),
    math.sin(angle),
    ...List.filled(190, 0.0),
  ];

  test(
    'Only native Android/iOS use MobileFaceNet; every browser keeps face-api',
    () {
      for (final platform in TargetPlatform.values) {
        expect(
          faceBackendFor(isWeb: true, platform: platform),
          FaceBackend.faceApi,
        );
        expect(
          faceBackendFor(isWeb: false, platform: platform),
          [TargetPlatform.android, TargetPlatform.iOS].contains(platform)
              ? FaceBackend.mobileFaceNet
              : FaceBackend.unsupported,
        );
      }
    },
  );

  test(
    'Mobile enrollment and scans match 192-D identities and isolate web embeddings',
    () async {
      final extractor = _Extractor(
        MobileFaceObservation(MobileFaceQuality.face, embedding(0)),
      );
      final recognizer = MobileFaceRecognizer(extractor);
      final descriptor = await recognizer.enroll(Uint8List(0));
      final student = PreviewStudent(
        'one',
        'Siswa',
        'XI',
        faceDescriptor: descriptor,
      );
      final webStudent = PreviewStudent(
        'web',
        'Browser',
        'XI',
        faceDescriptor: List.filled(128, 0),
      );
      expect(recognizer.embeddingProfile, same(mobileFaceProfile));
      expect(descriptor.length, 192);
      expect(
        (await recognizer.scan(Uint8List(0), [webStudent, student])).student,
        same(student),
      );
      expect(
        (await recognizer.scan(Uint8List(0), [webStudent])).status,
        FaceScanStatus.unknown,
      );
      expect(matchFace(List.filled(128, 0), [student]), isNull);
      extractor.result = MobileFaceObservation(
        MobileFaceQuality.face,
        embedding(1),
      );
      expect(
        (await recognizer.scan(Uint8List(0), [student])).status,
        FaceScanStatus.unknown,
      );
    },
  );

  test(
    'Mobile matching rejects ambiguous candidates, wrong lengths and nonfinite data',
    () {
      final first = PreviewStudent(
        'a',
        'A',
        'XI',
        faceDescriptor: embedding(0),
      );
      final second = PreviewStudent(
        'b',
        'B',
        'XI',
        faceDescriptor: embedding(.1),
      );
      expect(mobileFaceProfile.match(embedding(.04), [first, second]), isNull);
      expect(mobileFaceProfile.match(embedding(.2), [first]), same(first));
      expect(
        mobileFaceProfile.match([double.nan, ...List.filled(191, 0)], [first]),
        isNull,
      );
      expect(
        mobileFaceProfile.distance(embedding(0), List.filled(128, 0)),
        double.infinity,
      );
      // Admin duplicate detection uses the same mobile profile/threshold.
      expect(
        mobileFaceProfile.distance(embedding(.2), first.faceDescriptor!),
        lessThan(mobileFaceProfile.threshold),
      );
    },
  );

  test(
    'No face/multiple/unclear never produce enrollment or a named scan',
    () async {
      for (final quality in [
        MobileFaceQuality.noFace,
        MobileFaceQuality.multiple,
        MobileFaceQuality.unclear,
      ]) {
        final recognizer = MobileFaceRecognizer(
          _Extractor(MobileFaceObservation(quality)),
        );
        await expectLater(
          recognizer.enroll(Uint8List(0)),
          throwsA(isA<FaceRecognitionException>()),
        );
        final result = await recognizer.scan(Uint8List(0), []);
        expect(result.student, isNull);
        expect(result.status.name, quality.name);
      }
      final bad = MobileFaceRecognizer(
        _Extractor(const MobileFaceObservation(MobileFaceQuality.face, [0])),
      );
      await expectLater(
        bad.enroll(Uint8List(0)),
        throwsA(isA<FaceRecognitionException>()),
      );
      expect(
        () => normalizeMobileEmbedding(List.filled(192, 0)),
        throwsFormatException,
      );
    },
  );

  test(
    'RGB normalization uses the export convention and alignment preserves identity',
    () {
      final image = img.Image(width: 112, height: 112);
      img.fill(image, color: img.ColorRgb8(0, 128, 255));
      final input = mobileFaceInput((
        Uint8List.fromList(img.encodePng(image)),
        mobileFaceTemplate,
      ));
      expect(input.length, 112 * 112 * 3);
      final center = (56 * 112 + 56) * 3;
      expect(input[center], closeTo(-1, .0001));
      expect(input[center + 1], closeTo(0, .0001));
      expect(input[center + 2], closeTo(127 / 128, .0001));
    },
  );

  test(
    'Alignment undoes rotation, scale and translation in source coordinates',
    () {
      final image = img.Image(width: 300, height: 300);
      for (final pixel in image) {
        pixel.setRgb(pixel.x % 256, pixel.y % 256, 128);
      }
      const angle = .15, scale = 1.6;
      math.Point<double> transform(math.Point<double> point) => math.Point(
        scale * (math.cos(angle) * point.x - math.sin(angle) * point.y) + 30,
        scale * (math.sin(angle) * point.x + math.cos(angle) * point.y) + 10,
      );
      final input = mobileFaceInput((
        Uint8List.fromList(img.encodePng(image)),
        mobileFaceTemplate.map(transform).toList(),
      ));
      final source = transform(const math.Point(56, 56));
      final center = (56 * 112 + 56) * 3;
      expect(input[center], closeTo((source.x - 128) / 128, .012));
      expect(input[center + 1], closeTo((source.y - 128) / 128, .012));
      expect(
        () => mobileFaceInput((Uint8List(0), mobileFaceTemplate)),
        throwsFormatException,
      );
    },
  );

  test(
    'Camera EXIF orientation is baked before detection and large images are bounded',
    () {
      final image = img.Image(width: 1200, height: 600);
      image.exif.imageIfd.orientation = 6;
      final result = img.decodeJpg(
        prepareMobilePhoto(Uint8List.fromList(img.encodeJpg(image))),
      )!;
      expect(result.width, 480);
      expect(result.height, 960);
      expect(result.exif.imageIfd.orientation ?? 1, 1);
    },
  );
}
