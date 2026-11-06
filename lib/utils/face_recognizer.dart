import 'dart:math' as math;
import 'dart:typed_data';
import '../ui/attendance_history/attendance_history_screen.dart';

enum FaceScanStatus { matched, noFace, multiple, unclear, unknown }

class FaceCapturePose {
  final bool smiling, facingCamera;
  const FaceCapturePose({required this.smiling, required this.facingCamera});
  bool get ready => smiling && facingCamera;
}

class FaceScanResult {
  final FaceScanStatus status;
  final PreviewStudent? student;
  final FaceCapturePose? pose;
  const FaceScanResult(this.status, [this.student, this.pose]);
}

abstract class FaceRecognizer {
  Future<void> prepare();
  Future<List<double>> enroll(Uint8List photo);
  Future<FaceScanResult> scan(Uint8List photo, List<PreviewStudent> students);
}

// Optional capability: existing browser recognizers and test doubles keep the
// original 128-dimensional profile. Never compare embeddings across engines.
abstract interface class ProfiledFaceRecognizer {
  FaceEmbeddingProfile get profile;
}

extension FaceRecognizerProfile on FaceRecognizer {
  FaceEmbeddingProfile get embeddingProfile => this is ProfiledFaceRecognizer
      ? (this as ProfiledFaceRecognizer).profile
      : webFaceProfile;
}

class FaceEmbeddingProfile {
  final String id;
  final int dimensions;
  final double threshold, margin;
  const FaceEmbeddingProfile(
    this.id,
    this.dimensions,
    this.threshold,
    this.margin,
  );

  double distance(List<double> a, List<double> b) {
    if (a.length != dimensions ||
        b.length != dimensions ||
        a.any((v) => !v.isFinite) ||
        b.any((v) => !v.isFinite)) {
      return double.infinity;
    }
    var sum = 0.0;
    for (var i = 0; i < dimensions; i++) {
      sum += math.pow(a[i] - b[i], 2);
    }
    return math.sqrt(sum);
  }

  PreviewStudent? match(
    List<double> descriptor,
    List<PreviewStudent> students,
  ) {
    final candidates = [
      for (final s in students)
        if (s.faceDescriptor != null)
          (student: s, distance: distance(descriptor, s.faceDescriptor!)),
    ]..sort((a, b) => a.distance.compareTo(b.distance));
    if (candidates.isEmpty || candidates.first.distance > threshold) {
      return null;
    }
    if (candidates.length > 1 &&
        candidates[1].distance - candidates[0].distance < margin) {
      return null;
    }
    return candidates.first.student;
  }
}

const webFaceProfile = FaceEmbeddingProfile('face-api-128-v1', 128, .48, .08);
// Specific to the bundled, L2-normalized 192-D model. Starting parameters must
// be validated on the school's enrollment/scan photos before live deployment.
const mobileFaceProfile = FaceEmbeddingProfile(
  'mobilefacenet-192-be4bc7cf-aligned-v1',
  192,
  .65,
  .10,
);

class FaceRecognitionException implements Exception {
  final String message;
  const FaceRecognitionException(this.message);
  @override
  String toString() => message;
}

// Conservative starting threshold, with a separation margin for lookalikes.
// This is a descriptor distance, not a percentage or an accuracy guarantee.
const faceMatchThreshold = .48;
const faceMatchMargin = .08;

double faceDistance(List<double> a, List<double> b) {
  return webFaceProfile.distance(a, b);
}

PreviewStudent? matchFace(
  List<double> descriptor,
  List<PreviewStudent> students,
) {
  return webFaceProfile.match(descriptor, students);
}

abstract class StudentStore {
  Future<List<PreviewStudent>?> load();
  Future<void> save(List<PreviewStudent> students);
}
