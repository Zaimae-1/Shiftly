import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../utils/face_recognizer.dart';
import '../../utils/scanner_camera.dart';
import '../../utils/workforce_data.dart';
import '../admin/student_camera_dialog.dart';
import 'ui_motion.dart';

class LeaveRequestForm extends StatefulWidget {
  final FaceRecognizer recognizer;
  final ScannerCamera Function()? cameraFactory;
  final VoidCallback? onSaved;
  const LeaveRequestForm({
    super.key,
    required this.recognizer,
    this.cameraFactory,
    this.onSaved,
  });
  @override
  State<LeaveRequestForm> createState() => _LeaveRequestFormState();
}

class _LeaveRequestFormState extends State<LeaveRequestForm> {
  final _username = TextEditingController(), _reason = TextEditingController();
  String _kind = 'Sakit';
  String? _error;
  WorkerFaceProof? _proof;
  bool _busy = false, _saved = false;
  @override
  void dispose() {
    _username.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_username.text.trim().isEmpty) {
      setState(() => _error = 'Isi username terlebih dahulu.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _proof = null;
    });
    try {
      final photo = await showDialog<Uint8List>(
        context: context,
        builder: (_) => StudentCameraDialog(
          recognizer: widget.recognizer,
          cameraFactory: widget.cameraFactory,
        ),
      );
      if (!mounted || photo == null) return;
      final proof = await verifyWorkerPhoto(
        _username.text,
        photo,
        widget.recognizer,
      );
      if (mounted) setState(() => _proof = proof);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final proof = _proof;
    if (proof == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await submitWorkerLeave(proof, _reason.text, _kind);
      if (!mounted) return;
      setState(() => _saved = true);
      widget.onSaved?.call();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : 'Izin belum tersimpan. Coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MotionResize(
    child: Container(
      key: const ValueKey('leave-request-form'),
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 360 ? 14 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFFE7ECF3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCAD4E3)),
      ),
      child: _saved
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.task_alt_rounded,
                  color: Color(0xFF356CD4),
                  size: 30,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Izin berhasil dicatat',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                Text(
                  '${_proof!.worker.name} · $_kind\n${_reason.text.trim()}',
                  style: const TextStyle(height: 1.6),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tersimpan di rekap Izin pada perangkat ini.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Pengajuan izin / sakit',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tanpa lokasi. Identitas diverifikasi dari wajah dan username.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('leave-username'),
                  controller: _username,
                  enabled: !_busy,
                  onChanged: (_) => setState(() => _proof = null),
                  decoration: _leaveInput(
                    'Username pekerja',
                  ).copyWith(prefixText: '@'),
                ),
                const SizedBox(height: 12),
                MotionTabs(
                  labels: const ['Izin', 'Sakit'],
                  selected: _kind == 'Izin' ? 0 : 1,
                  onChanged: _busy
                      ? null
                      : (index) => setState(
                          () => _kind = index == 0 ? 'Izin' : 'Sakit',
                        ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('leave-reason'),
                  controller: _reason,
                  enabled: !_busy,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: _leaveInput(
                    'Alasan',
                  ).copyWith(hintText: 'Contoh: sakit gigi, perlu istirahat.'),
                ),
                if (_proof != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            _proof!.photo,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.verified_user_outlined),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Wajah cocok\n${_proof!.worker.name}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF356CD4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFF98584D)),
                    ),
                  ),
                TouchFeedback(
                  enabled: !_busy,
                  child: OutlinedButton.icon(
                    key: const ValueKey('leave-verify-face'),
                    onPressed: _busy ? null : _verify,
                    icon: const Icon(Icons.face_retouching_natural),
                    label: Text(
                      _busy
                          ? 'Memproses…'
                          : _proof == null
                          ? 'Verifikasi wajah lewat kamera'
                          : 'Ambil foto ulang',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TouchFeedback(
                  enabled: !_busy && _proof != null,
                  child: FilledButton.icon(
                    key: const ValueKey('leave-submit'),
                    onPressed: _busy || _proof == null ? null : _submit,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Kirim izin'),
                  ),
                ),
              ],
            ),
    ),
  );

  InputDecoration _leaveInput(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFF7F9FC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0xFFCAD5E4)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0xFFCAD5E4)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0xFF356CD4), width: 1.5),
    ),
  );
}
