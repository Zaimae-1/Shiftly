import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/ui/attendance_history/attendance_history_screen.dart';
import 'package:attendance_app/ui/admin/admin_screen.dart';
import '../utils/scanner_camera.dart';
import '../utils/scanner_camera_stub.dart'
    if (dart.library.js_interop) '../utils/scanner_camera_web.dart';
export '../utils/scanner_camera.dart' show ScannerCamera;
import '../utils/face_recognizer.dart';
import '../utils/face_services.dart';
import '../utils/current_location.dart';
import '../utils/attendance_data.dart';
import 'face_scan_animation.dart';
import '../utils/workforce_data.dart';
import 'workforce/assistant_panel.dart';
import 'workforce/workforce_board.dart';
import 'workforce/work_history_screen.dart';
import 'workforce/ui_motion.dart';
import 'workforce/app_notice.dart';
import 'workforce/shiftly_brand.dart';

const _ink = Color(0xFF243653);
const _muted = Color(0xFF71809A);
const _teal = Color(0xFF356CD4);
const _paper = Color(0xFFF9FBFF);
const _line = Color(0xFFDCE5F2);
const _amber = Color(0xFF916A35);
const _scanSeconds = 10;

enum _Phase { ready, opening, scanning, captured, saved, issue }

String _date(DateTime v) {
  const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  return '${days[v.weekday - 1]}, ${v.day} ${months[v.month - 1]} ${v.year}';
}

class HomeScreen extends StatefulWidget {
  final ScannerCamera Function()? cameraFactory;
  final FaceRecognizer? recognizer;
  final Future<String> Function()? locate;
  final DateTime Function()? now;
  const HomeScreen({
    super.key,
    this.cameraFactory,
    this.recognizer,
    this.locate,
    this.now,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _confirmationKey = GlobalKey();
  final _scannerKey = GlobalKey();

  void _revealPanel(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final target = key.currentContext;
      if (target != null && MediaQuery.sizeOf(context).width < 920) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.08,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  _Phase _phase = _Phase.ready;
  ScannerCamera? _camera;
  bool _cameraReady = false, _previewOpening = false;
  bool _homeVisible = true, _foreground = true;
  int _previewGeneration = 0;
  Future<bool>? _previewAttempt;
  bool get _canPreview => mounted && _homeVisible && _foreground;
  Future<void> _pendingRelease = Future<void>.value();
  int _cameraSession = 0;
  Uint8List? _photoBytes;
  bool _takingPhoto = false;
  String _openingLabel = 'Membuka kamera';
  String _scanHint = 'Posisikan wajah di dalam bingkai';
  String? _candidateId;
  int _candidateFrames = 0;
  int _poseFrames = 0;
  bool _awaitingSmile = false;
  int _failedScans = 0;
  bool _faceFailure = false, _callingAdmin = false, _adminCalled = false;
  Timer? _adminCallTimer;
  int _seconds = _scanSeconds;
  DateTime? _capturedAt;
  PreviewStudent? _capturedStudent;
  String? _location;
  Timer? _countdown, _result, _dayTimer;
  late DateTime _displayDay;
  bool _savingAttendance = false, _leaveMode = false;
  WorkScanAction? _capturedAction;
  final _leaveReason = TextEditingController();
  String _leaveKind = 'Sakit';
  String? _leaveError;
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  bool _today(PreviewAttendanceRecord r) => attendanceOnDay(r, _now);
  FaceRecognizer get _recognizer => widget.recognizer ?? faceRecognizer;
  String _issueTitle = '', _issueBody = '';
  IconData _issueIcon = Icons.info_outline_rounded;
  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    previewAttendanceRecords.addListener(_refresh);
    previewStudents.addListener(_refresh);
    _displayDay = _now;
    _scheduleNewDay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_canPreview) unawaited(_ensurePreview());
      unawaited(_syncAbsences());
    });
  }

  void _scheduleNewDay() {
    _dayTimer?.cancel();
    final now = _now;
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _dayTimer = Timer(midnight.difference(now), _checkDay);
  }

  Future<void> _syncAbsences() async {
    try {
      await synchronizeWorkerAbsences(now: _now);
    } catch (error) {
      debugPrint('Rekap Alpha belum diperbarui: $error');
    }
  }

  void _checkDay() {
    unawaited(_syncAbsences());
    if (!mounted) return;
    if (!sameAttendanceDay(_displayDay, _now)) {
      _displayDay = _now;
      _reset();
    } else {
      _refresh();
    }
    _scheduleNewDay();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _stop() {
    _countdown?.cancel();
    _result?.cancel();
  }

  @override
  void dispose() {
    _stop();
    _leaveReason.dispose();
    _adminCallTimer?.cancel();
    _dayTimer?.cancel();
    _cameraSession++;
    _previewGeneration++;
    unawaited(_releaseCamera());
    WidgetsBinding.instance.removeObserver(this);
    previewAttendanceRecords.removeListener(_refresh);
    previewStudents.removeListener(_refresh);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _checkDay();
      if (_canPreview) unawaited(_ensurePreview());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        (state == AppLifecycleState.inactive &&
            !_previewOpening &&
            _phase != _Phase.opening)) {
      _foreground = false;
      _reset(releasePreview: true);
    }
  }

  Future<bool> _ensurePreview() {
    if (!_canPreview) return Future.value(false);
    if (_cameraReady && _camera != null) return Future.value(true);
    final pending = _previewAttempt;
    if (pending != null) return pending;
    final attempt = _openPreview();
    _previewAttempt = attempt;
    attempt.then((_) {
      if (identical(_previewAttempt, attempt)) _previewAttempt = null;
    });
    return attempt;
  }

  Future<bool> _openPreview() async {
    final generation = _previewGeneration;
    setState(() => _previewOpening = true);
    await _pendingRelease;
    if (!_canPreview || generation != _previewGeneration) return false;
    final camera = widget.cameraFactory?.call() ?? createScannerCamera();
    _camera = camera;
    try {
      await camera.initialize().timeout(const Duration(seconds: 30));
      if (!_canPreview || generation != _previewGeneration) return false;
      setState(() => _cameraReady = true);
      return true;
    } catch (error) {
      if (_canPreview && generation == _previewGeneration) {
        debugPrint('Camera preview initialization: $error');
        await _releaseCamera();
        if (_canPreview && generation == _previewGeneration) {
          _issue(
            'Kamera belum tersedia',
            _cameraError(error),
            Icons.videocam_off_outlined,
          );
        }
      }
      return false;
    } finally {
      if (mounted && generation == _previewGeneration) {
        setState(() => _previewOpening = false);
      }
    }
  }

  void _suspendPreview() {
    _previewGeneration++;
    _previewAttempt = null;
    _previewOpening = false;
    unawaited(_releaseCamera());
  }

  Future<void> _retryPreview() async {
    _reset();
    await _ensurePreview();
  }

  Future<void> _releaseCamera() {
    final camera = _camera;
    _camera = null;
    _cameraReady = false;
    if (camera == null) return _pendingRelease;
    _pendingRelease = _pendingRelease.then((_) async {
      try {
        await camera.dispose();
      } catch (_) {
        /* Kamera sudah dilepas oleh platform. */
      }
    });
    return _pendingRelease;
  }

  String _cameraError(Object error) {
    if (error is TimeoutException) {
      return 'Kamera belum merespons. Tutup aplikasi kamera lain, lalu coba lagi.';
    }
    if (error is CameraException) {
      switch (error.code) {
        case 'CameraAccessDenied':
        case 'CameraAccessDeniedWithoutPrompt':
        case 'permissionDenied':
        case 'NotAllowedError':
          return 'Izinkan akses kamera di pengaturan situs atau aplikasi. Di browser, gunakan HTTPS atau localhost.';
        case 'CameraAccessRestricted':
          return 'Akses kamera dibatasi oleh pengaturan perangkat.';
        case 'NoCamera':
        case 'NotFoundError':
        case 'cameraNotFound':
          return 'Kamera tidak ditemukan. Sambungkan webcam atau gunakan HP yang memiliki kamera.';
        case 'NotReadableError':
        case 'cameraNotReadable':
          return 'Browser gagal membuka kamera yang dipilih. Periksa pilihan kamera default browser dan gunakan kamera bawaan atau webcam yang aktif.';
        default:
          return 'Kamera tidak dapat digunakan. Pastikan kamera tidak sedang dipakai aplikasi lain, lalu coba lagi.';
      }
    }
    return 'Kamera belum dapat dibuka di perangkat ini. Coba melalui Chrome atau browser HP.';
  }

  PreviewAttendanceRecord? _existing(PreviewStudent s) {
    for (final r in previewAttendanceRecords.value) {
      if (attendanceBelongsTo(r, s) && _today(r)) return r;
    }
    return null;
  }

  void _notice(
    String title,
    String body, {
    Color color = _teal,
    IconData icon = Icons.check_circle_outline_rounded,
  }) {
    showAppNotice(
      context,
      title: title,
      message: body,
      color: color,
      icon: icon,
    );
  }

  void _issue(
    String title,
    String body,
    IconData icon, {
    bool faceFailure = false,
  }) {
    _stop();
    _cameraSession++;
    setState(() {
      _phase = _Phase.issue;
      _issueTitle = title;
      _issueBody = body;
      _issueIcon = icon;
      _capturedAt = null;
      _capturedStudent = null;
      _photoBytes = null;
      _takingPhoto = false;
      _faceFailure = faceFailure;
      if (faceFailure) _failedScans++;
    });
    _notice(title, body, color: _amber, icon: icon);
  }

  Future<void> _start() async {
    _stop();
    _adminCallTimer?.cancel();
    _callingAdmin = false;
    _adminCalled = false;
    _faceFailure = false;
    _candidateId = null;
    _candidateFrames = 0;
    _poseFrames = 0;
    _awaitingSmile = false;
    _scanHint = 'Posisikan satu wajah di dalam bingkai';
    final session = ++_cameraSession;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _photoBytes = null;
    _location = null;
    _takingPhoto = false;
    setState(() {
      _phase = _Phase.opening;
      _openingLabel = _cameraReady ? 'Memuat AI' : 'Membuka kamera';
    });
    if (!await _ensurePreview()) return;
    if (!mounted || session != _cameraSession) return;
    setState(() => _openingLabel = 'Memuat AI');
    try {
      await _recognizer.prepare().timeout(const Duration(seconds: 60));
    } catch (error) {
      if (mounted && session == _cameraSession) {
        _issue(
          'Pengenalan wajah belum siap',
          error is FaceRecognitionException
              ? error.message
              : 'Model belum berhasil dimuat. Coba lagi.',
          Icons.psychology_outlined,
        );
      }
      return;
    }
    if (!mounted || session != _cameraSession) return;
    if (!_leaveMode) {
      setState(() => _openingLabel = 'Mengambil lokasi');
      try {
        final location = await (widget.locate ?? readAttendanceLocation)();
        if (!mounted || session != _cameraSession) return;
        if (location.trim().isEmpty) {
          throw const AttendanceLocationException(
            'Lokasi perangkat belum tersedia.',
          );
        }
        _location = location;
      } catch (error) {
        if (mounted && session == _cameraSession) {
          _issue(
            'Lokasi belum tersedia',
            error is AttendanceLocationException
                ? error.message
                : 'Periksa izin lokasi, lalu coba lagi.',
            Icons.location_off_outlined,
          );
        }
        return;
      }
    } else {
      _location = 'Izin / sakit · lokasi tidak diperlukan';
    }
    if (!mounted || session != _cameraSession) return;
    setState(() {
      _phase = _Phase.scanning;
      _seconds = _scanSeconds;
      _capturedAt = null;
      _capturedStudent = null;
    });
    _revealPanel(_scannerKey);
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_seconds <= 1) {
        _seconds = 0;
        _unrecognized();
      } else {
        setState(() => _seconds--);
      }
    });
    _result = Timer(
      const Duration(milliseconds: 300),
      () => _scanFrame(session),
    );
  }

  void _unrecognized() => _issue(
    _awaitingSmile ? 'Senyumnya belum tertangkap' : 'Foto tidak dikenali',
    _awaitingSmile
        ? 'Wajahmu sudah dikenali, tapi posisi menghadap kamera dan senyumnya belum pas. Coba lagi ya, lihat kamera dan tahan senyummu sebentar.'
        : 'Belum ada wajah yang cocok dengan data pekerja dalam 10 detik. Coba scan ulang dengan wajah lebih dekat dan pencahayaan yang cukup.',
    Icons.person_search_outlined,
    faceFailure: true,
  );

  Future<void> _scanFrame(int session) async {
    final camera = _camera;
    if (_phase != _Phase.scanning || camera == null || _takingPhoto) return;
    _takingPhoto = true;
    try {
      final bytes = await camera.capture();
      if (!mounted || session != _cameraSession || _phase != _Phase.scanning) {
        return;
      }
      if (bytes.isEmpty) throw StateError('Foto kosong');
      final match = await _recognizer.scan(
        bytes,
        List.of(previewStudents.value),
      );
      if (!mounted || session != _cameraSession || _phase != _Phase.scanning) {
        return;
      }
      final s = match.student;
      if (match.status == FaceScanStatus.matched &&
          s != null &&
          previewStudents.value.any(
            (current) => current.id == s.id && identical(current, s),
          )) {
        if (_candidateId != s.id) {
          _poseFrames = 0;
          _awaitingSmile = false;
        }
        _candidateFrames = _candidateId == s.id ? _candidateFrames + 1 : 1;
        _candidateId = s.id;
        if (_candidateFrames >= 2 && !_awaitingSmile) {
          setState(() {
            _awaitingSmile = true;
            _scanHint = 'Hai, ${s.name}! Lihat kamera dan senyum dulu ya';
          });
        } else if (_awaitingSmile) {
          _poseFrames = match.pose?.ready == true ? _poseFrames + 1 : 0;
          setState(
            () => _scanHint = match.pose?.facingCamera != true
                ? 'Hadapkan wajah ke kamera dan buka mata ya'
                : match.pose?.smiling != true
                ? 'Sudah pas! Sekarang senyum dulu ya'
                : 'Senyumnya pas · tahan sebentar ya',
          );
        }
        if (_poseFrames >= 2) {
          _photoBytes = bytes;
          _completeCapture(s);
          return;
        }
        if (!_awaitingSmile) {
          setState(() => _scanHint = 'Wajah cocok · tahan sebentar ya');
        }
      } else {
        _candidateId = null;
        _candidateFrames = 0;
        _poseFrames = 0;
        _awaitingSmile = false;
        setState(
          () => _scanHint = switch (match.status) {
            FaceScanStatus.noFace => 'Posisikan wajah di dalam bingkai',
            FaceScanStatus.multiple => 'Pastikan hanya ada satu wajah',
            FaceScanStatus.unclear => 'Wajah kurang jelas · dekati kamera',
            _ => 'Mencari kecocokan dengan data pekerja…',
          },
        );
      }
    } catch (error) {
      if (mounted && session == _cameraSession) {
        if (error is FaceRecognitionException) {
          _issue(
            'Analisis wajah terganggu',
            error.message,
            Icons.psychology_outlined,
          );
        } else {
          // A video frame may not be ready yet; the next pass can retry.
          _candidateId = null;
          _candidateFrames = 0;
          _poseFrames = 0;
          _awaitingSmile = false;
        }
      }
    } finally {
      if (mounted && session == _cameraSession && _phase == _Phase.scanning) {
        _takingPhoto = false;
        _result = Timer(
          const Duration(milliseconds: 350),
          () => _scanFrame(session),
        );
      }
    }
  }

  void _callAdmin() {
    if (_callingAdmin || _adminCalled) return;
    setState(() => _callingAdmin = true);
    _adminCallTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted || _phase != _Phase.issue) return;
      setState(() {
        _callingAdmin = false;
        _adminCalled = true;
      });
      _notice(
        'Simulasi panggilan admin',
        'Permintaan bantuan ditampilkan. Belum ada pesan yang dikirim ke admin.',
        icon: Icons.support_agent_rounded,
      );
    });
  }

  void _completeCapture(PreviewStudent s) {
    final r = _existing(s);
    final action = nextWorkAction(s, previewAttendanceRecords.value, _now);
    if ((_leaveMode && r != null) ||
        (!_leaveMode &&
            (action == WorkScanAction.finished ||
                action == WorkScanAction.onLeave))) {
      _duplicate(r!);
      return;
    }
    _stop();
    setState(() {
      _phase = _Phase.captured;
      _takingPhoto = false;
      _failedScans = 0;
      _capturedStudent = s;
      _capturedAt = _now;
      _capturedAction = action;
      _leaveError = null;
    });
    _revealPanel(_confirmationKey);
  }

  void _duplicate(PreviewAttendanceRecord r) {
    _issue(
      r.type == 'permission'
          ? 'Izin sudah tercatat'
          : 'Masuk dan pulang sudah lengkap',
      r.type == 'permission'
          ? '${r.name} sudah memiliki catatan ${r.description.toLowerCase()} hari ini. Hubungi admin untuk koreksi.'
          : '${r.name} · masuk ${workTimestamp(attendanceTime(r))} · pulang ${workTimestamp(r.checkedOutAt)}. Tidak ada catatan ganda.',
      Icons.fact_check_outlined,
    );
  }

  void _reset({bool revealScanner = false, bool releasePreview = false}) {
    _stop();
    _adminCallTimer?.cancel();
    _cameraSession++;
    if (releasePreview) _suspendPreview();
    setState(() {
      _phase = _Phase.ready;
      _seconds = _scanSeconds;
      _capturedStudent = null;
      _capturedAt = null;
      _photoBytes = null;
      _takingPhoto = false;
      _callingAdmin = false;
      _adminCalled = false;
      _faceFailure = false;
    });
    if (revealScanner) _revealPanel(_scannerKey);
  }

  Future<void> _confirm() async {
    if (_savingAttendance || _phase != _Phase.captured) return;
    final worker = _capturedStudent,
        captured = _capturedAt,
        photo = _photoBytes,
        location = _location;
    if (worker == null ||
        captured == null ||
        photo == null ||
        location == null) {
      return;
    }
    if (!sameAttendanceDay(captured, _now) ||
        _now.difference(captured) > const Duration(minutes: 5)) {
      _issue(
        'Silakan scan ulang',
        'Tanggal berubah atau sesi lebih dari 5 menit. Mulai scan baru.',
        Icons.refresh_rounded,
      );
      return;
    }
    if (_leaveMode &&
        (_leaveReason.text.trim().length < 3 ||
            _leaveReason.text.trim().length > 500)) {
      setState(() => _leaveError = 'Isi alasan 3–500 karakter.');
      return;
    }
    final isLeave = _leaveMode, action = _capturedAction!;
    setState(() => _savingAttendance = true);
    try {
      if (isLeave) {
        final proof = await verifyWorkerPhoto(
          worker.handle,
          photo,
          _recognizer,
          now: _now,
        );
        await submitWorkerLeave(
          proof,
          _leaveReason.text,
          _leaveKind,
          now: _now,
        );
      } else {
        await saveWorkScan(
          worker: worker,
          capturedAt: captured,
          now: _now,
          expectedAction: action,
          address: location,
          photo: photo,
        );
      }
    } catch (error) {
      if (mounted) {
        _issue(
          'Catatan belum disimpan',
          error is StateError
              ? error.message.toString()
              : 'Penyimpanan atau verifikasi gagal. Coba lagi.',
          Icons.info_outline_rounded,
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _savingAttendance = false);
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.saved);
    _notice(
      isLeave
          ? 'Izin berhasil dicatat'
          : action == WorkScanAction.checkOut
          ? 'Pulang berhasil dicatat'
          : 'Masuk berhasil dicatat',
      '${worker.name} · ${workTimestamp(captured)} · tersimpan di rekap.',
    );
    _result = Timer(const Duration(seconds: 3), () {
      if (mounted) _reset(revealScanner: true);
    });
  }

  Future<void> _assistant() async {
    if (_savingAttendance) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _homeVisible = false;
    _reset(releasePreview: true);
    await showWorkAssistant(
      context,
      recognizer: _recognizer,
      cameraFactory: widget.cameraFactory,
    );
    _homeVisible = true;
    if (_canPreview) unawaited(_ensurePreview());
  }

  Future<void> _history() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _homeVisible = false;
    _reset(releasePreview: true);
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondary) =>
            const WorkHistoryScreen(),
        transitionsBuilder: (context, animation, secondary, child) {
          final a = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(.025, 0),
                end: Offset.zero,
              ).animate(a),
              child: child,
            ),
          );
        },
      ),
    );
    _homeVisible = true;
    if (_canPreview) unawaited(_ensurePreview());
  }

  Future<void> _admin() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _homeVisible = false;
    _reset(releasePreview: true);
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondary) => const AdminScreen(),
        transitionsBuilder: (context, animation, secondary, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            ),
      ),
    );
    _homeVisible = true;
    if (_canPreview) unawaited(_ensurePreview());
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    final students = previewStudents.value;
    final attended = students
        .where(
          (s) => previewAttendanceRecords.value.any(
            (r) =>
                attendanceBelongsTo(r, s) &&
                _today(r) &&
                r.type == 'attendance',
          ),
        )
        .length;
    final permission = students
        .where(
          (s) =>
              previewAttendanceRecords.value.any(
                (r) =>
                    attendanceBelongsTo(r, s) &&
                    _today(r) &&
                    r.type == 'permission',
              ) &&
              !previewAttendanceRecords.value.any(
                (r) =>
                    attendanceBelongsTo(r, s) &&
                    _today(r) &&
                    r.type == 'attendance',
              ),
        )
        .length;
    final pending = students.length - attended - permission;
    final finished = students
        .where(
          (w) =>
              dayRecord(
                w,
                previewAttendanceRecords.value,
                _now,
              )?.checkedOutAt !=
              null,
        )
        .length;
    final working = attended - finished;
    final alpha = previewAttendanceRecords.value
        .where(
          (r) =>
              r.type == 'absence' &&
              r.absenceEndedAt == null &&
              students.any((w) => w.id == r.studentId),
        )
        .length;
    return Scaffold(
      backgroundColor: const Color(0xFFEEF3FA),
      floatingActionButton: AssistantLauncher(onPressed: _assistant),
      body: SafeArea(
        child: Column(
          children: [
            _header(compact),
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 14 : 40,
                        compact ? 22 : 36,
                        compact ? 14 : 40,
                        96,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Reveal(child: _intro(compact)),
                          if (students.isEmpty) ...[
                            const SizedBox(height: 16),
                            RevealIn(
                              child: Container(
                                padding: EdgeInsets.all(compact ? 13 : 18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD9E1EC),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFC6D2E2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.group_add_outlined,
                                      color: _teal,
                                      size: 23,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Belum ada pekerja terdaftar',
                                            style: TextStyle(
                                              color: _ink,
                                              fontWeight: FontWeight.w700,
                                              fontSize: compact ? 12 : 15,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            compact
                                                ? 'Mulai dengan profil pertama.'
                                                : 'Daftarkan profil dan foto wajah melalui admin.',
                                            style: const TextStyle(
                                              color: _muted,
                                              fontSize: 11,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (compact)
                                      TouchFeedback(
                                        child: IconButton.filledTonal(
                                          onPressed: _admin,
                                          tooltip: 'Daftarkan pekerja',
                                          icon: const Icon(
                                            Icons.add_rounded,
                                            size: 21,
                                          ),
                                        ),
                                      )
                                    else
                                      TextButton.icon(
                                        onPressed: _admin,
                                        icon: const Icon(Icons.add_rounded),
                                        label: const Text('Daftarkan pekerja'),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 26),
                          _Reveal(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _Stat(
                                    label: 'Pekerja terdaftar',
                                    value: students.length,
                                    caption: 'Pekerja aktif',
                                    icon: Icons.groups_2_outlined,
                                    compact: compact,
                                  ),
                                ),
                                SizedBox(width: compact ? 8 : 16),
                                Expanded(
                                  child: _Stat(
                                    label: 'Sedang bekerja',
                                    value: working,
                                    caption: '$finished sudah pulang',
                                    icon: Icons.how_to_reg_outlined,
                                    compact: compact,
                                    accent: true,
                                  ),
                                ),
                                SizedBox(width: compact ? 8 : 16),
                                Expanded(
                                  child: _Stat(
                                    label: 'Belum absen',
                                    value: pending,
                                    caption: 'Belum ada catatan',
                                    icon: Icons.schedule_rounded,
                                    compact: compact,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 10, left: 2),
                            child: Text(
                              '$permission pekerja izin/sakit · $alpha periode Alpha aktif · ${workDate(_now)}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _Reveal(
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final scanner = _scanner(compact),
                                    details = _details();
                                if (c.maxWidth < 840) {
                                  return Column(
                                    children: [
                                      scanner,
                                      const SizedBox(height: 18),
                                      details,
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 6, child: scanner),
                                    const SizedBox(width: 22),
                                    Expanded(flex: 4, child: details),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 26),
                          WorkforceBoard(day: _now),
                          const SizedBox(height: 26),
                          const Wrap(
                            spacing: 20,
                            runSpacing: 8,
                            children: [
                              Text(
                                'SHIFTLY · Team attendance',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Masuk dan pulang tercatat. Data demo tersimpan lokal.',
                                style: TextStyle(color: _muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(bool compact) => Container(
    decoration: const BoxDecoration(
      color: _paper,
      border: Border(bottom: BorderSide(color: _line)),
    ),
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 16 : 40,
      vertical: compact ? 12 : 16,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: Row(
          children: [
            const ShiftlyMark(size: 42),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHIFTLY',
                  style: TextStyle(
                    fontSize: compact ? 14 : 17,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: compact ? 1 : 1.6,
                  ),
                ),
                if (!compact)
                  const Text(
                    'WORKFORCE ATTENDANCE',
                    style: TextStyle(
                      fontSize: 8,
                      letterSpacing: 1.4,
                      color: _muted,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            if (!compact) ...[
              const _Action(
                label: 'Beranda',
                icon: Icons.grid_view_rounded,
                onPressed: null,
                selected: true,
                compact: true,
              ),
              const SizedBox(width: 8),
            ],
            if (MediaQuery.sizeOf(context).width < 360)
              IconButton(
                onPressed: _history,
                icon: const Icon(Icons.history_rounded),
                tooltip: 'Riwayat',
              )
            else
              _Action(
                label: 'Riwayat',
                icon: Icons.history_rounded,
                onPressed: _history,
                secondary: true,
                compact: true,
              ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _admin,
              icon: const Icon(Icons.lock_outline_rounded),
              tooltip: 'Akses admin',
            ),
          ],
        ),
      ),
    ),
  );
  Widget _intro(bool compact) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'KEHADIRAN HARI INI',
        style: TextStyle(
          color: _teal,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.1,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              'Your daily check-in.',
              style: TextStyle(
                fontSize: compact ? 30 : 36,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.3,
                color: _ink,
                height: 1.15,
              ),
            ),
          ),
          if (!compact) _dateBadge(),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Satu scan untuk masuk. Scan berikutnya untuk pulang.',
        style: TextStyle(color: _muted, fontSize: 13),
      ),
      if (compact) ...[const SizedBox(height: 16), _dateBadge()],
    ],
  );
  Widget _dateBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFC0CCDE)),
      color: const Color(0xFFEEF2F6),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.calendar_today_outlined, size: 15, color: _teal),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            _date(_now),
            style: const TextStyle(
              color: _ink,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
  Widget _scanner(bool compact) {
    final opening = _phase == _Phase.opening;
    final scanning = _phase == _Phase.scanning,
        captured = _phase == _Phase.captured,
        saved = _phase == _Phase.saved,
        issue = _phase == _Phase.issue;
    final status = opening
        ? _openingLabel
        : scanning
        ? 'Memindai'
        : captured
        ? 'Wajah dikenali'
        : saved
        ? 'Tercatat'
        : issue
        ? 'Perlu dicoba ulang'
        : _previewOpening
        ? 'Membuka kamera'
        : _cameraReady
        ? 'Siap memindai'
        : 'Kamera belum aktif';
    return _Surface(
      key: _scannerKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.face_retouching_natural_rounded,
                size: 20,
                color: _teal,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Pemindai wajah',
                  style: TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              _Pill(text: status, color: issue ? _amber : _teal, dot: true),
            ],
          ),
          const SizedBox(height: 18),
          MotionTabs(
            labels: const ['Masuk / pulang', 'Izin / sakit'],
            icons: const [
              Icons.work_outline_rounded,
              Icons.medical_services_outlined,
            ],
            selected: _leaveMode ? 1 : 0,
            onChanged: opening || scanning || captured || _savingAttendance
                ? null
                : (index) {
                    _reset();
                    setState(() => _leaveMode = index == 1);
                  },
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: compact ? 1.12 : 1.45,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF304B70), Color(0xFF1D3354)],
                      ),
                    ),
                  ),
                  if (_camera != null && _cameraReady)
                    Positioned.fill(
                      key: ObjectKey(_camera),
                      child: IgnorePointer(child: _camera!.buildPreview()),
                    ),
                  if (!_cameraReady)
                    Positioned.fill(
                      child: CustomPaint(painter: _DotsPainter()),
                    ),
                  if (!opening && !_previewOpening && !_cameraReady)
                    Positioned(
                      bottom: 16,
                      left: 12,
                      right: 12,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              saved
                                  ? 'Terima kasih sudah hadir'
                                  : captured
                                  ? 'Foto pekerja berhasil ditangkap'
                                  : scanning
                                  ? 'Tetap di dalam bingkai'
                                  : 'Posisikan wajah di dalam bingkai',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFAEBED5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (opening || _previewOpening)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFB5C4D9),
                      ),
                    ),
                  if (!opening && !_previewOpening)
                    Positioned.fill(
                      child: Align(
                        alignment: captured || saved
                            ? Alignment.bottomRight
                            : const Alignment(0, -.18),
                        child: FractionallySizedBox(
                          widthFactor: captured || saved ? .25 : .88,
                          heightFactor: captured || saved ? .32 : .88,
                          child: FaceScanAnimation(
                            active: scanning,
                            recognized: captured || saved,
                          ),
                        ),
                      ),
                    ),
                  if (scanning)
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xEE1D3354),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _awaitingSmile
                                  ? Icons.sentiment_satisfied_alt_rounded
                                  : Icons.face_retouching_natural_rounded,
                              color: Colors.white,
                              size: 23,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _scanHint,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _ink,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        'KAMERA ASLI',
                        style: const TextStyle(
                          fontSize: 8,
                          letterSpacing: 1.7,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _ink,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            scanning ? '${_seconds}s' : '${_scanSeconds}s',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (scanning) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _seconds / _scanSeconds,
                color: _teal,
                backgroundColor: const Color(0xFFDAE2EC),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: _muted),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _leaveMode
                      ? 'Izin / sakit tidak memerlukan lokasi'
                      : _location ?? 'Lokasi diambil saat scan dimulai',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!captured)
            _Action(
              key: const ValueKey('start-scan'),
              label: opening
                  ? 'Batalkan buka kamera'
                  : scanning
                  ? 'Batalkan scan'
                  : captured
                  ? 'Scan ulang'
                  : saved
                  ? 'Siap untuk pekerja berikutnya'
                  : issue
                  ? 'Coba lagi'
                  : 'Mulai scan',
              icon: opening
                  ? Icons.close_rounded
                  : scanning
                  ? Icons.close_rounded
                  : saved
                  ? Icons.arrow_forward_rounded
                  : Icons.center_focus_strong_rounded,
              onPressed: opening
                  ? () => _reset(releasePreview: _previewOpening)
                  : scanning
                  ? _reset
                  : captured
                  ? _start
                  : saved
                  ? _reset
                  : !_cameraReady && !_previewOpening
                  ? _retryPreview
                  : _start,
            ),
          if (scanning) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                _scanHint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _teal,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Tekan Mulai scan, lihat kamera, lalu senyum saat diminta. Batas scan 10 detik.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 10, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _details() => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280),
    transitionBuilder: (child, a) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .04),
          end: Offset.zero,
        ).animate(a),
        child: child,
      ),
    ),
    child: switch (_phase) {
      _Phase.captured => _confirmation(),
      _Phase.saved => _message(
        'Presensi berhasil',
        'Kehadiranmu tersimpan di riwayat. Scanner akan siap kembali untuk pekerja berikutnya.',
        Icons.check_circle_outline_rounded,
        _teal,
        const ValueKey('saved'),
      ),
      _Phase.issue => _message(
        _issueTitle,
        _issueBody,
        _issueIcon,
        _amber,
        const ValueKey('issue'),
      ),
      _ =>
        MediaQuery.sizeOf(context).width < 700
            ? _mobileInstructions()
            : _instructions(),
    },
  );
  Widget _mobileInstructions() => Material(
    key: const ValueKey('instructions'),
    color: _paper,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(19),
      side: const BorderSide(color: _line),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFDCE3ED),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.lightbulb_outline_rounded,
            color: _teal,
            size: 18,
          ),
        ),
        title: const Text(
          'Panduan scan',
          style: TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: const Text(
          'Tiga langkah, kurang dari satu menit.',
          style: TextStyle(color: _muted, fontSize: 10, height: 1.6),
        ),
        children: const [
          _Guide(
            number: '01',
            title: 'Posisikan wajah',
            description: 'Satu wajah dengan pencahayaan yang cukup.',
          ),
          _Guide(
            number: '02',
            title: 'Periksa identitasmu',
            description: 'Cek nama dan jenis catatan masuk / pulang.',
          ),
          _Guide(
            number: '03',
            title: 'Konfirmasi',
            description: 'Untuk izin atau sakit, tambahkan alasannya.',
          ),
        ],
      ),
    ),
  );

  Widget _instructions() => _Surface(
    key: const ValueKey('instructions'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Pill(text: 'PANDUAN SINGKAT', color: _teal),
        const SizedBox(height: 20),
        const Text(
          'Hadir dengan\ntiga langkah.',
          style: TextStyle(
            fontSize: 28,
            height: 1.18,
            letterSpacing: -.8,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        const SizedBox(height: 26),
        const _Guide(
          number: '01',
          title: 'Posisikan wajah',
          description:
              'Satu wajah, menghadap kamera dengan pencahayaan yang cukup.',
        ),
        const _Guide(
          number: '02',
          title: 'Periksa identitasmu',
          description:
              'Pastikan nama, username, foto, dan keterangannya sesuai.',
        ),
        const _Guide(
          number: '03',
          title: 'Konfirmasi catatan kerja',
          description: 'Data tersimpan setelah kamu menekan Konfirmasi.',
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE4E9F1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: _teal, size: 17),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Setelah dikenali, lihat kamera dan tersenyum. Foto diambil saat posenya pas. Scan berhenti setelah 10 detik jika belum dikenali.',
                  style: TextStyle(color: _muted, fontSize: 11, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _confirmation() {
    final s = _capturedStudent!, t = _capturedAt!;
    return _Surface(
      key: _confirmationKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_outlined, color: _teal, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Periksa presensimu',
                  style: TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360, maxHeight: 224),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE4EE),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _line),
                ),
                child: _photoBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_photoBytes!, fit: BoxFit.contain),
                      )
                    : const SizedBox(
                        width: 116,
                        height: 116,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 58,
                              color: _teal,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Foto pekerja',
                              style: TextStyle(fontSize: 10, color: _muted),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            s.name,
            style: const TextStyle(
              color: _ink,
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '@${s.handle}',
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            'Wajah cocok dengan foto pekerja terdaftar',
            style: TextStyle(color: _teal, fontSize: 11, height: 1.5),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(color: _line, height: 1),
          ),
          _Detail(
            icon: Icons.calendar_today_outlined,
            label: 'Tanggal',
            value: _date(t),
          ),
          _Detail(
            icon: Icons.schedule_rounded,
            label: 'Jam',
            value: DateFormat('HH:mm').format(t),
          ),
          _Detail(
            icon: Icons.location_on_outlined,
            label: 'Lokasi',
            value: _leaveMode
                ? 'Tidak diperlukan untuk izin / sakit'
                : _location ?? 'Lokasi belum tersedia',
          ),
          _Detail(
            icon: Icons.check_circle_outline_rounded,
            label: 'Keterangan',
            value: _leaveMode
                ? _leaveKind
                : _capturedAction == WorkScanAction.checkOut
                ? 'Pulang / istirahat'
                : 'Masuk kerja',
          ),
          if (_capturedAction == WorkScanAction.checkOut && !_leaveMode)
            _Detail(
              icon: Icons.login_rounded,
              label: 'Masuk',
              value: workTimestamp(attendanceTime(_existing(s)!)),
            ),
          if (_leaveMode) ...[
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Izin', label: Text('Izin')),
                ButtonSegment(value: 'Sakit', label: Text('Sakit')),
              ],
              selected: {_leaveKind},
              onSelectionChanged: _savingAttendance
                  ? null
                  : (v) => setState(() => _leaveKind = v.first),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('scan-leave-reason'),
              controller: _leaveReason,
              maxLength: 500,
              maxLines: 3,
              enabled: !_savingAttendance,
              decoration: InputDecoration(
                labelText: 'Alasan izin / sakit',
                errorText: _leaveError,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _Action(
            key: const ValueKey('confirm-attendance'),
            label: _savingAttendance
                ? 'Menyimpan…'
                : _leaveMode
                ? 'Kirim izin'
                : _capturedAction == WorkScanAction.checkOut
                ? 'Konfirmasi pulang'
                : 'Konfirmasi masuk',
            icon: Icons.check_rounded,
            onPressed: _savingAttendance ? null : _confirm,
          ),
          const SizedBox(height: 8),
          _Action(
            label: 'Scan ulang',
            icon: Icons.refresh_rounded,
            onPressed: _start,
            secondary: true,
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum disimpan. Konfirmasi jika semua data benar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _message(
    String title,
    String body,
    IconData icon,
    Color color,
    Key key,
  ) => _Surface(
    key: key,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 25,
            fontWeight: FontWeight.w600,
            height: 1.2,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: const TextStyle(color: _muted, fontSize: 13, height: 1.7),
        ),
        if (_phase == _Phase.issue && _faceFailure && _failedScans >= 2) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE1E7F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Butuh bantuan?',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sudah mencoba beberapa kali? Minta admin memeriksa data wajahmu.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 12),
                _Action(
                  key: const ValueKey('call-admin'),
                  label: _callingAdmin
                      ? 'Menghubungi admin…'
                      : _adminCalled
                      ? 'Permintaan bantuan dibuat'
                      : 'Panggil admin',
                  icon: _adminCalled
                      ? Icons.check_circle_outline_rounded
                      : Icons.support_agent_rounded,
                  onPressed: _callingAdmin || _adminCalled ? null : _callAdmin,
                ),
                if (_callingAdmin)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _adminCalled
                        ? 'Simulasi selesai · Belum ada pesan yang dikirim. Minta bantuan admin di lokasi.'
                        : 'Simulasi panggilan admin',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        _Action(
          label: _phase == _Phase.saved
              ? 'Lihat riwayat'
              : 'Kembali ke scanner',
          icon: _phase == _Phase.saved
              ? Icons.history_rounded
              : Icons.arrow_back_rounded,
          secondary: true,
          onPressed: _phase == _Phase.saved
              ? _history
              : () => _reset(revealScanner: true),
        ),
      ],
    ),
  );
}

class _Surface extends StatelessWidget {
  final Widget child;
  const _Surface({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 700 ? 14 : 24),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFCED8E6)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x050F1824),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class _Stat extends StatefulWidget {
  final String label, caption;
  final int value;
  final IconData icon;
  final bool compact, accent;
  const _Stat({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.compact,
    this.accent = false,
  });
  @override
  State<_Stat> createState() => _StatState();
}

class _StatState extends State<_Stat> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context),
        compact = widget.compact;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: reduced ? Duration.zero : const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hover && !reduced ? -3 : 0, 0),
        padding: EdgeInsets.all(compact ? 11 : 20),
        decoration: BoxDecoration(
          color: widget.accent ? const Color(0xFFD6DEEA) : _paper,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: _hover ? const Color(0xFF7B98C0) : _line),
          boxShadow: [
            BoxShadow(
              color: Color(_hover ? 0x122E4360 : 0x032E4360),
              blurRadius: _hover ? 20 : 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 6 : 8),
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: _teal, size: compact ? 16 : 19),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: compact
                    ? MediaQuery.textScalerOf(context).scale(27)
                    : 18,
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  height: 1.25,
                  color: _muted,
                ),
              ),
            ),
            const SizedBox(height: 5),
            TweenAnimationBuilder<double>(
              tween: Tween(end: widget.value.toDouble()),
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Text(
                '${value.round()}',
                style: TextStyle(
                  fontSize: compact ? 29 : 36,
                  height: 1.1,
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.caption,
              style: TextStyle(
                color: _muted,
                fontSize: compact ? 9 : 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final bool dot;
  const _Pill({required this.text, required this.color, this.dot = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot) ...[
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: dot ? 0 : 1.1,
          ),
        ),
      ],
    ),
  );
}

class _Guide extends StatelessWidget {
  final String number, title, description;
  const _Guide({
    required this.number,
    required this.title,
    required this.description,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: _teal,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: _ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11,
                  color: _muted,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Detail({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _muted, size: 16),
        const SizedBox(width: 9),
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Action extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool secondary, compact, selected;
  const _Action({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.secondary = false,
    this.compact = false,
    this.selected = false,
  });
  @override
  State<_Action> createState() => _ActionState();
}

class _ActionState extends State<_Action> {
  bool _hover = false, _pressed = false;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      cursor: widget.onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: reduced || widget.onPressed == null
              ? 1
              : _pressed
              ? 0.98
              : _hover
              ? 1.012
              : 1,
          duration: reduced ? Duration.zero : const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: TextButton.icon(
            onPressed: widget.onPressed,
            style: TextButton.styleFrom(
              minimumSize: Size(
                widget.compact ? 0 : double.infinity,
                widget.compact ? 40 : 48,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 15 : 20,
                vertical: widget.compact ? 10 : 15,
              ),
              backgroundColor: widget.selected
                  ? const Color(0xFFDDE4EE)
                  : widget.secondary
                  ? (_hover ? const Color(0xFFDFE6EF) : Colors.transparent)
                  : (_hover ? const Color(0xFF2D5CBC) : _teal),
              foregroundColor: widget.secondary || widget.selected
                  ? _teal
                  : Colors.white,
              disabledForegroundColor: widget.secondary || widget.selected
                  ? _teal
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: widget.secondary
                    ? const BorderSide(color: _line)
                    : BorderSide.none,
              ),
              textStyle: TextStyle(
                fontSize: widget.compact ? 11 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: Icon(widget.icon, size: widget.compact ? 16 : 18),
            label: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  final Widget child;
  const _Reveal({required this.child});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 430),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - v)),
          child: child,
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB5C4D9).withValues(alpha: .07);
    for (double x = 20; x < size.width; x += 24) {
      for (double y = 20; y < size.height; y += 24) {
        canvas.drawCircle(Offset(x, y), .7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) => false;
}
