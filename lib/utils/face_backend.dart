import 'package:flutter/foundation.dart';

enum FaceBackend { faceApi, mobileFaceNet, unsupported }

FaceBackend faceBackendFor({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  // Browser HP remains on face-api.js. TFLite/ML Kit are native plugins, so a
  // narrow viewport or mobile user-agent must never switch the web backend.
  if (isWeb) return FaceBackend.faceApi;
  if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
    return FaceBackend.mobileFaceNet;
  }
  return FaceBackend.unsupported;
}
