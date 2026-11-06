import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;
import 'scanner_camera.dart';

ScannerCamera createScannerCamera() => _BrowserScannerCamera();

class _BrowserScannerCamera implements ScannerCamera {
  web.MediaStream? _stream;
  web.HTMLVideoElement? _video;
  bool _disposed = false;

  @override
  Future<void> initialize() async {
    try {
      // Open the working default camera once. camera_web's availableCameras()
      // probes every input, so an inactive OBS camera can abort enumeration:
      // https://github.com/flutter/flutter/issues/194184
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(video: true.toJS, audio: false.toJS),
          )
          .toDart;
      if (_disposed) {
        for (final track in stream.getTracks().toDart) {
          track.stop();
        }
        return;
      }
      _stream = stream;
      final video = web.HTMLVideoElement()
        ..autoplay = true
        ..muted = true
        ..playsInline = true
        ..srcObject = stream;
      video.style
        ..width = '100%'
        ..height = '100%'
        ..objectFit = 'cover';
      // Match the front-camera preview convention. Captured JPEG stays unmirrored.
      if (stream
              .getVideoTracks()
              .toDart
              .firstOrNull
              ?.getSettings()
              .facingMode !=
          'environment') {
        video.style.transform = 'scaleX(-1)';
      }
      _video = video;
      await video.play().toDart;
    } catch (error) {
      await dispose();
      if ((error as JSAny).isA<web.DOMException>()) {
        final exception = error as web.DOMException;
        throw CameraException(exception.name, exception.message);
      }
      rethrow;
    }
  }

  @override
  Widget buildPreview() => HtmlElementView.fromTagName(
    tagName: 'div',
    onElementCreated: (element) {
      if (_disposed || _video == null) return;
      final host = element as web.HTMLElement;
      host.style
        ..width = '100%'
        ..height = '100%';
      host.appendChild(_video!);
    },
  );

  @override
  Future<Uint8List> capture() async {
    final video = _video;
    if (_disposed ||
        video == null ||
        video.videoWidth == 0 ||
        video.videoHeight == 0) {
      throw CameraException(
        'CameraNotReady',
        'Tunggu sampai gambar kamera terlihat.',
      );
    }
    final canvas = web.HTMLCanvasElement()
      ..width = video.videoWidth
      ..height = video.videoHeight;
    canvas.context2D.drawImage(video, 0, 0);
    return base64Decode(
      canvas.toDataURL('image/jpeg', 0.9.toJS).split(',').last,
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _video?.pause();
    _video?.srcObject = null;
    _video = null;
    final stream = _stream;
    _stream = null;
    if (stream != null) {
      for (final track in stream.getTracks().toDart) {
        track.stop();
      }
    }
  }
}
