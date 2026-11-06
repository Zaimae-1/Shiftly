import 'face_recognizer.dart';
import 'face_services_stub.dart'
    if (dart.library.io) 'face_services_native.dart'
    if (dart.library.js_interop) 'face_services_web.dart'
    as platform;

final FaceRecognizer faceRecognizer = platform.createFaceRecognizer();
final StudentStore studentStore = platform.createStudentStore();
String? studentStorageProblem;
