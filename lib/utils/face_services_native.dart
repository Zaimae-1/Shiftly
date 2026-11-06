import 'dart:io';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'face_backend.dart';
import 'face_recognizer.dart';
import 'face_services_stub.dart' as desktop;
import 'mobile_face_engine.dart';
import 'mobile_face_recognizer.dart';
import 'native_local_data.dart';

// Use the real OS, not defaultTargetPlatform (which Flutter widget tests and
// themes may override). A Windows test runner must not load Android plugins.
FaceBackend get _backend => faceBackendFor(
  isWeb: false,
  platform: Platform.isAndroid
      ? TargetPlatform.android
      : Platform.isIOS
      ? TargetPlatform.iOS
      : TargetPlatform.windows,
);

FaceRecognizer createFaceRecognizer() => _backend == FaceBackend.mobileFaceNet
    ? MobileFaceRecognizer(MobileFaceEngine())
    : desktop.createFaceRecognizer();

StudentStore createStudentStore() => _backend == FaceBackend.mobileFaceNet
    ? MobileStudentStore()
    : desktop.createStudentStore();
