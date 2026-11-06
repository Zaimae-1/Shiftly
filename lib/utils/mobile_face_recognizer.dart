import 'dart:typed_data';
import '../ui/attendance_history/attendance_history_screen.dart';
import 'face_recognizer.dart';
import 'mobile_face_preprocessing.dart';

enum MobileFaceQuality { face, noFace, multiple, unclear }

class MobileFaceObservation {
  final MobileFaceQuality quality;
  final List<double>? embedding;
  final FaceCapturePose? pose;
  const MobileFaceObservation(this.quality, [this.embedding, this.pose]);
}

abstract interface class MobileFaceExtractor {
  Future<void> prepare();
  Future<MobileFaceObservation> extract(Uint8List photo);
}

class MobileFaceRecognizer implements FaceRecognizer, ProfiledFaceRecognizer {
  final MobileFaceExtractor extractor;
  MobileFaceRecognizer(this.extractor);

  @override
  FaceEmbeddingProfile get profile => mobileFaceProfile;
  @override
  Future<void> prepare() => extractor.prepare();

  List<double> _embedding(MobileFaceObservation result) {
    try {
      return normalizeMobileEmbedding(result.embedding ?? []);
    } on FormatException {
      throw const FaceRecognitionException(
        'Ciri wajah belum dapat dibaca. Posisikan wajah dengan jelas dan coba lagi.',
      );
    }
  }

  @override
  Future<List<double>> enroll(Uint8List photo) async {
    await prepare();
    final result = await extractor.extract(photo);
    switch (result.quality) {
      case MobileFaceQuality.noFace:
        throw const FaceRecognitionException(
          'Wajah tidak ditemukan dalam foto. Gunakan foto wajah yang jelas.',
        );
      case MobileFaceQuality.multiple:
        throw const FaceRecognitionException(
          'Foto berisi lebih dari satu wajah. Gunakan foto satu siswa saja.',
        );
      case MobileFaceQuality.unclear:
        throw const FaceRecognitionException(
          'Wajah kurang jelas. Hadapkan wajah ke kamera dengan pencahayaan cukup.',
        );
      case MobileFaceQuality.face:
        return _embedding(result);
    }
  }

  @override
  Future<FaceScanResult> scan(
    Uint8List photo,
    List<PreviewStudent> students,
  ) async {
    await prepare();
    final result = await extractor.extract(photo);
    switch (result.quality) {
      case MobileFaceQuality.noFace:
        return const FaceScanResult(FaceScanStatus.noFace);
      case MobileFaceQuality.multiple:
        return const FaceScanResult(FaceScanStatus.multiple);
      case MobileFaceQuality.unclear:
        return const FaceScanResult(FaceScanStatus.unclear);
      case MobileFaceQuality.face:
        final student = profile.match(_embedding(result), students);
        return FaceScanResult(
          student == null ? FaceScanStatus.unknown : FaceScanStatus.matched,
          student,
          result.pose,
        );
    }
  }
}
