import 'dart:typed_data';
import '../ui/attendance_history/attendance_history_screen.dart';
import 'face_recognizer.dart';

FaceRecognizer createFaceRecognizer() => _UnsupportedRecognizer();
StudentStore createStudentStore() => _MemoryStudentStore();

class _UnsupportedRecognizer implements FaceRecognizer {
  @override
  Future<void> prepare() async => throw const FaceRecognitionException(
    'Di komputer, jalankan pengenalan wajah melalui Chrome. Di HP, gunakan aplikasi Android/iOS.',
  );
  @override
  Future<List<double>> enroll(Uint8List photo) async {
    await prepare();
    return [];
  }

  @override
  Future<FaceScanResult> scan(
    Uint8List photo,
    List<PreviewStudent> students,
  ) async {
    await prepare();
    return const FaceScanResult(FaceScanStatus.unknown);
  }
}

class _MemoryStudentStore implements StudentStore {
  @override
  Future<List<PreviewStudent>?> load() async => null;
  @override
  Future<void> save(List<PreviewStudent> students) async {}
}
