import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../attendance_history/attendance_history_screen.dart';
import '../../utils/attendance_data.dart';
import '../../utils/workforce_data.dart';

const _teal = Color(0xFF356CD4);
const _muted = Color(0xFF71809A);
const _danger = Color(0xFF98584D);

class AdminAttendancePanel extends StatefulWidget {
  const AdminAttendancePanel({super.key});
  @override
  State<AdminAttendancePanel> createState() => _AdminAttendancePanelState();
}

class _AdminAttendancePanelState extends State<AdminAttendancePanel> {
  bool _resetting = false;

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _permission() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _PermissionEditor(),
    );
    if (mounted && saved == true) {
      _notice('Keterangan pekerja disimpan ke riwayat.');
    }
  }

  Future<void> _resetToday() async {
    final day = DateTime.now();
    final count = previewAttendanceRecords.value
        .where((r) => attendanceOnDay(r, day))
        .length;
    if (count == 0) {
      _notice('Belum ada catatan hari ini untuk direset.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.restart_alt_rounded, color: _danger),
        title: const Text('Reset hari ini?'),
        content: Text(
          'Hapus $count catatan hadir, izin, dan sakit pada ${DateFormat('dd/MM/yyyy').format(day)}? '
          'Pekerja bisa absen ulang untuk pengujian.\n\n'
          'Data pekerja, foto pendaftaran, dan riwayat tanggal lain tetap tersimpan. Penghapusan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const ValueKey('confirm-reset-day'),
            style: FilledButton.styleFrom(backgroundColor: _danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ya, reset hari ini'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _resetting = true);
    try {
      await updateAttendance((records) {
        if (!sameAttendanceDay(day, DateTime.now())) {
          throw StateError(
            'Tanggal sudah berganti. Periksa rekap lalu ulangi reset.',
          );
        }
        return reconcileAbsences(
          previewStudents.value,
          records.where((r) => !attendanceOnDay(r, day)).toList(),
          DateTime.now(),
        );
      });
      if (mounted) {
        _notice('Catatan hari ini direset. Pekerja dapat absen ulang.');
      }
    } catch (_) {
      if (mounted) {
        _notice(
          'Reset gagal. Catatan tetap tersimpan; muat ulang lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xFFF9FBFF),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFDCE5F2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.event_note_outlined, color: _teal, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Kelola presensi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Catat izin atau sakit tanpa scan wajah. Keterangan masuk ke riwayat dan rekap sesuai tanggal yang dipilih.',
          style: TextStyle(color: _muted, height: 1.6),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              key: const ValueKey('record-permission'),
              onPressed: _resetting ? null : _permission,
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              label: const Text('Catat izin / sakit'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('reset-day'),
              onPressed: _resetting ? null : _resetToday,
              style: OutlinedButton.styleFrom(foregroundColor: _danger),
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: Text(_resetting ? 'Mereset…' : 'Reset hari ini'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Hari baru dimulai otomatis pukul 00.00 menurut tanggal perangkat. Riwayat lama tetap ada. Reset manual hanya untuk mengulang tes hari ini.',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.6),
        ),
      ],
    ),
  );
}

class _PermissionEditor extends StatefulWidget {
  const _PermissionEditor();
  @override
  State<_PermissionEditor> createState() => _PermissionEditorState();
}

class _PermissionEditorState extends State<_PermissionEditor> {
  final _note = TextEditingController();
  String? _studentId, _error;
  String _status = 'Izin';
  DateTime _day = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(today.year - 1),
      lastDate: today,
      helpText: 'Tanggal izin / sakit',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (mounted && picked != null) {
      setState(() {
        _day = picked;
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final students = previewStudents.value.where((s) => s.id == _studentId);
    if (students.isEmpty) {
      setState(() => _error = 'Pilih pekerja terlebih dahulu.');
      return;
    }
    final student = students.first;
    final now = DateTime.now();
    final date = DateTime(
      _day.year,
      _day.month,
      _day.day,
      now.hour,
      now.minute,
    );
    final note = _note.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await updateAttendance((records) {
        if (!previewStudents.value.any((s) => identical(s, student))) {
          throw StateError(
            'Data pekerja berubah. Tutup formulir dan pilih ulang pekerja.',
          );
        }
        final existing = records.where(
          (r) =>
              r.type != 'absence' &&
              attendanceBelongsTo(r, student) &&
              attendanceOnDay(r, date),
        );
        if (existing.isNotEmpty) {
          throw StateError(
            '${student.name} sudah tercatat ${existing.first.description.toLowerCase()} pada tanggal ini. Tidak ada catatan ganda yang disimpan.',
          );
        }
        return reconcileAbsences(previewStudents.value, [
          PreviewAttendanceRecord(
            id: 'permission-${now.microsecondsSinceEpoch}',
            studentId: student.id,
            name: student.name,
            username: student.handle,
            className: student.className,
            address: 'Dicatat oleh admin',
            description: _status,
            note: note,
            datetime: DateFormat('dd/MM/yyyy HH:mm').format(date),
            recordedAt: date,
            type: 'permission',
          ),
          ...records,
        ], now);
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : 'Keterangan belum disimpan. Periksa penyimpanan lokal lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Catat izin / sakit'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (previewStudents.value.isEmpty)
                const Text(
                  'Belum ada pekerja terdaftar. Tambahkan pekerja terlebih dahulu.',
                ),
              DropdownButtonFormField<String>(
                key: const ValueKey('permission-student'),
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Pekerja'),
                items: [
                  for (final s in previewStudents.value)
                    DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        '${s.name} · @${s.handle}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        _studentId = value;
                        _error = null;
                      }),
              ),
              const SizedBox(height: 18),
              const Text('Keterangan', style: TextStyle(color: _muted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: [
                  for (final status in ['Izin', 'Sakit'])
                    ChoiceChip(
                      label: Text(status),
                      selected: _status == status,
                      onSelected: _saving
                          ? null
                          : (_) => setState(() => _status = status),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('permission-date'),
                onPressed: _saving ? null : _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(DateFormat('dd/MM/yyyy').format(_day)),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('permission-note'),
                controller: _note,
                enabled: !_saving,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  hintText: 'Contoh: kontrol dokter',
                ),
              ),
              const Text(
                'Tidak membutuhkan foto atau lokasi pekerja. Satu pekerja hanya boleh memiliki satu catatan per tanggal.',
                style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: _danger)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const ValueKey('save-permission'),
          onPressed: _saving || previewStudents.value.isEmpty ? null : _save,
          child: Text(_saving ? 'Menyimpan…' : 'Simpan keterangan'),
        ),
      ],
    ),
  );
}
