import 'dart:typed_data';
import 'package:attendance_app/utils/face_recognizer.dart';
import 'package:attendance_app/ui/attendance_history/attendance_history_screen.dart';

class TestFaceRecognizer implements FaceRecognizer {
  final bool recognize;
  final String? enrollmentError;
  final Future<FaceScanResult>? pending;
  FaceCapturePose pose;
  TestFaceRecognizer({
    this.recognize = true,
    this.enrollmentError,
    this.pending,
    this.pose = const FaceCapturePose(smiling: true, facingCamera: true),
  });
  @override
  Future<void> prepare() async {}
  @override
  Future<List<double>> enroll(Uint8List photo) async {
    if (enrollmentError != null) {
      throw FaceRecognitionException(enrollmentError!);
    }
    return List.filled(128, 0.0);
  }

  @override
  Future<FaceScanResult> scan(
    Uint8List photo,
    List<PreviewStudent> students,
  ) async {
    if (pending != null) return await pending!;
    if (!recognize) return const FaceScanResult(FaceScanStatus.unknown);
    return FaceScanResult(
      FaceScanStatus.matched,
      students.firstWhere((s) => s.id == 'azam'),
      pose,
    );
  }
}
