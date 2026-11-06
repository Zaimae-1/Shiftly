import 'scanner_camera.dart';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

ScannerCamera createScannerCamera() => _NativeScannerCamera();

class _NativeScannerCamera implements ScannerCamera {
  CameraController? _controller;
  bool _disposed = false;
  @override
  Future<void> initialize() async {
    final cameras = await availableCameras();
    if (_disposed) return;
    if (cameras.isEmpty) throw CameraException('NoCamera', 'Tidak ada kamera');
    final selected = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      selected,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller = controller;
    await controller.initialize();
  }

  @override
  Widget buildPreview() => Center(child: CameraPreview(_controller!));
  @override
  Future<Uint8List> capture() async =>
      (await _controller!.takePicture()).readAsBytes();
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _controller?.dispose();
  }
}
