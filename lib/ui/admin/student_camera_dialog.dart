import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../utils/face_recognizer.dart';
import '../../utils/scanner_camera.dart';
import '../face_scan_animation.dart';
import '../../utils/scanner_camera_stub.dart'
    if (dart.library.js_interop) '../../utils/scanner_camera_web.dart';

class StudentCameraDialog extends StatefulWidget {
  final FaceRecognizer recognizer;
  final ScannerCamera Function()? cameraFactory;
  const StudentCameraDialog({
    super.key,
    required this.recognizer,
    this.cameraFactory,
  });
  @override
  State<StudentCameraDialog> createState() => _StudentCameraDialogState();
}

class _StudentCameraDialogState extends State<StudentCameraDialog>
    with WidgetsBindingObserver {
  ScannerCamera? _camera;
  Timer? _countdown, _nextFrame;
  bool _opening = true, _active = false;
  String _hint = 'Menyiapkan pengenalan wajah…';
  int _seconds = 10, _session = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  void _stopTimers() {
    _countdown?.cancel();
    _nextFrame?.cancel();
  }

  Future<void> _release() async {
    final camera = _camera;
    _camera = null;
    try {
      await camera?.dispose();
    } catch (_) {
      /* Already released by platform. */
    }
  }

  bool _current(int session) => mounted && session == _session;

  @override
  void dispose() {
    _session++;
    _stopTimers();
    unawaited(_release());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        (state == AppLifecycleState.inactive && _active)) {
      _fail(
        'Kamera dihentikan saat berpindah aplikasi. Coba lagi ketika siap.',
      );
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    _session++;
    _stopTimers();
    unawaited(_release());
    setState(() {
      _opening = false;
      _active = false;
      _hint = message;
    });
  }

  Future<void> _start() async {
    _stopTimers();
    final session = ++_session;
    await _release();
    if (!_current(session)) return;
    setState(() {
      _opening = true;
      _active = false;
      _seconds = 10;
      _hint = 'Menyiapkan pengenalan wajah…';
    });
    try {
      await widget.recognizer.prepare().timeout(const Duration(seconds: 60));
      if (!_current(session)) return;
      final camera = widget.cameraFactory?.call() ?? createScannerCamera();
      _camera = camera;
      setState(() => _hint = 'Membuka kamera…');
      await camera.initialize().timeout(const Duration(seconds: 30));
      if (!_current(session)) return;
      setState(() {
        _opening = false;
        _active = true;
        _hint = 'Posisikan satu wajah di dalam bingkai. Foto diambil otomatis.';
      });
      _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_current(session)) return;
        if (_seconds <= 1) {
          _fail(
            'Wajah belum berhasil ditangkap dalam 10 detik. Dekati kamera dan coba lagi.',
          );
        } else {
          setState(() => _seconds--);
        }
      });
      _nextFrame = Timer(
        const Duration(milliseconds: 300),
        () => _scan(session, camera),
      );
    } catch (error) {
      if (!_current(session)) return;
      _fail(
        error is FaceRecognitionException
            ? error.message
            : error is CameraException &&
                  [
                    'permissionDenied',
                    'NotAllowedError',
                    'CameraAccessDenied',
                  ].contains(error.code)
            ? 'Akses kamera belum diizinkan. Izinkan kamera, lalu coba lagi.'
            : 'Kamera belum dapat dibuka. Periksa kamera default browser, lalu coba lagi.',
      );
    }
  }

  Future<void> _scan(int session, ScannerCamera camera) async {
    if (!_current(session) || !_active) return;
    try {
      final photo = await camera.capture();
      if (!_current(session) || !_active) return;
      // Validate a single usable face before returning a registration photo.
      await widget.recognizer.enroll(photo);
      if (!_current(session) || !_active) return;
      _stopTimers();
      setState(() {
        _active = false;
        _hint = 'Foto wajah berhasil ditangkap.';
      });
      await _release();
      if (mounted && session == _session) Navigator.pop(context, photo);
      return;
    } catch (error) {
      if (!_current(session) || !_active) return;
      setState(
        () => _hint = error is FaceRecognitionException
            ? error.message
            : 'Menunggu gambar kamera yang jelas…',
      );
    }
    if (_current(session) && _active) {
      _nextFrame = Timer(
        const Duration(milliseconds: 400),
        () => _scan(session, camera),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: const Color(0xFFF9FBFF),
    insetPadding: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ambil foto wajah',
                    style: TextStyle(
                      fontSize: 23,
                      color: Color(0xFF243653),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('close-student-camera'),
                  tooltip: 'Tutup kamera',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Satu wajah, menghadap kamera dengan pencahayaan cukup.',
              style: TextStyle(color: Color(0xFF71809A), height: 1.6),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 1.15,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0xFF202F44)),
                    if (_active && _camera != null)
                      IgnorePointer(child: _camera!.buildPreview()),
                    if (_opening)
                      const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFBAC8DC),
                        ),
                      ),
                    if (!_opening && !_active)
                      const Center(
                        child: Icon(
                          Icons.face_retouching_off_rounded,
                          size: 70,
                          color: Color(0xFFBAC8DC),
                        ),
                      ),
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: .64,
                        heightFactor: .76,
                        child: FaceScanAnimation(active: _active),
                      ),
                    ),
                    if (_active)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xCC243653),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              '${_seconds}s',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                _hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF356CD4),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (!_opening && !_active)
              FilledButton.icon(
                key: const ValueKey('retry-student-camera'),
                onPressed: _start,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    ),
  );
}
