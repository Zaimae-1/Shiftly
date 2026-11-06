import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../attendance_history/attendance_history_screen.dart';
import '../../utils/face_recognizer.dart';
import '../../utils/face_services.dart';
import '../../utils/scanner_camera.dart';
import 'student_camera_dialog.dart';
import 'attendance_admin.dart';
import '../../utils/workforce_data.dart';
import '../workforce/assistant_panel.dart';
import '../workforce/ui_motion.dart';
import '../workforce/app_notice.dart';
import '../workforce/shiftly_brand.dart';

const _ink = Color(0xFF243653);
const _muted = Color(0xFF71809A);
const _teal = Color(0xFF356CD4);
const _paper = Color(0xFFF9FBFF);
const _line = Color(0xFFDCE5F2);
const _danger = Color(0xFF98584D);

class AdminScreen extends StatefulWidget {
  final Future<Uint8List?> Function()? choosePhoto;
  final FaceRecognizer? recognizer;
  final ScannerCamera Function()? cameraFactory;
  const AdminScreen({
    super.key,
    this.choosePhoto,
    this.recognizer,
    this.cameraFactory,
  });

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _password = TextEditingController();
  final _search = TextEditingController();
  bool _unlocked = false, _showPassword = false;
  String? _passwordError;
  AdminSession? _session;

  @override
  void dispose() {
    _session?.revoke();
    _password.dispose();
    _search.dispose();
    super.dispose();
  }

  void _unlock() {
    final session = AdminSession.unlock(_password.text);
    if (session == null) {
      setState(() => _passwordError = 'Password salah. Silakan coba lagi.');
      return;
    }
    _password.clear();
    _session = session;
    setState(() {
      _unlocked = true;
      _passwordError = null;
      _showPassword = false;
    });
  }

  void _lock() {
    _session?.revoke();
    _session = null;
    FocusManager.instance.primaryFocus?.unfocus();
    _password.clear();
    _search.clear();
    setState(() {
      _unlocked = false;
      _passwordError = null;
      _showPassword = false;
    });
  }

  void _notice(String message) => showAppNotice(
    context,
    title: 'Shiftly Admin',
    message: message,
    icon: Icons.info_outline_rounded,
  );

  Future<void> _edit([PreviewStudent? student]) async {
    final result = await showDialog<PreviewStudent>(
      context: context,
      builder: (_) => _StudentEditor(
        student: student,
        choosePhoto: widget.choosePhoto,
        recognizer: widget.recognizer ?? faceRecognizer,
        cameraFactory: widget.cameraFactory,
      ),
    );
    if (!mounted || result == null) return;
    try {
      await updateWorkers(_session!, (current) {
        if (student != null && !current.any((w) => identical(w, student))) {
          throw StateError('Data pekerja berubah. Buka formulir lagi.');
        }
        return student == null
            ? [...current, result]
            : [
                for (final w in current)
                  if (w.id == result.id) result else w,
              ];
      });
    } catch (error) {
      if (mounted) {
        _notice(
          error is StateError
              ? error.message.toString()
              : 'Data belum disimpan. Coba lagi.',
        );
      }
      return;
    }
    if (!mounted) return;
    _notice(
      student == null
          ? 'Pekerja berhasil ditambahkan.'
          : 'Perubahan pekerja disimpan.',
    );
  }

  Future<void> _delete(PreviewStudent student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteStudent(student: student),
    );
    if (!mounted || confirmed != true) return;
    try {
      await deleteWorker(_session!, student, student.handle);
    } catch (error) {
      if (mounted) {
        _notice(
          error is StateError
              ? error.message.toString()
              : 'Data belum dihapus. Coba lagi.',
        );
      }
      return;
    }
    if (!mounted) return;
    _notice('Data pekerja ${student.name} dihapus.');
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      floatingActionButton: _unlocked
          ? AssistantLauncher(
              onPressed: () => showWorkAssistant(
                context,
                session: _session,
                recognizer: widget.recognizer ?? faceRecognizer,
                cameraFactory: widget.cameraFactory,
                editWorker: _edit,
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: _paper,
                border: Border(bottom: BorderSide(color: _line)),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 32,
                vertical: 12,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Kembali ke beranda',
                  ),
                  const SizedBox(width: 8),
                  const ShiftlyMark(),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'SHIFTLY / ADMIN',
                      style: TextStyle(
                        fontSize: 13,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ),
                  if (_unlocked)
                    IconButton(
                      onPressed: _lock,
                      icon: const Icon(Icons.lock_outline_rounded),
                      tooltip: 'Kunci admin',
                      key: const ValueKey('lock-admin'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  fit: StackFit.expand,
                  children: [...previous, ?current],
                ),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                child: _unlocked ? _directory(compact) : _login(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _login() => Center(
    key: const ValueKey('admin-login'),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE3ED),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.lock_person_outlined,
                  color: _teal,
                  size: 30,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Ruang admin',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kelola data pekerja dengan akses khusus admin.',
                style: TextStyle(color: _muted, height: 1.6),
              ),
              const SizedBox(height: 28),
              TextField(
                key: const ValueKey('admin-password'),
                controller: _password,
                obscureText: !_showPassword,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _unlock(),
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                },
                decoration: _input('Password admin').copyWith(
                  errorText: _passwordError,
                  errorMaxLines: 2,
                  prefixIcon: const Icon(Icons.key_outlined, size: 20),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    tooltip: _showPassword
                        ? 'Sembunyikan password'
                        : 'Tampilkan password',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('unlock-admin'),
                  onPressed: _unlock,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Masuk admin'),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Akses akan terkunci lagi saat meninggalkan halaman ini.',
                style: TextStyle(fontSize: 12, color: _muted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _directory(
    bool compact,
  ) => ValueListenableBuilder<List<PreviewStudent>>(
    key: const ValueKey('student-directory'),
    valueListenable: previewStudents,
    builder: (context, students, _) {
      final query = _search.text.trim().toLowerCase();
      final filtered = students
          .where(
            (s) => '${s.name} ${s.handle} ${s.email} ${s.phone}'
                .toLowerCase()
                .contains(query),
          )
          .toList();
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          compact ? 14 : 36,
          compact ? 24 : 36,
          compact ? 14 : 36,
          96,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DIREKTORI PEKERJA',
                  style: TextStyle(
                    color: _teal,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Kenali setiap pekerja.',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Profil, kontak, dan identitas wajah tim dalam satu tempat.',
                  style: TextStyle(color: _muted, height: 1.6),
                ),
                const SizedBox(height: 26),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Count(
                      icon: Icons.people_outline_rounded,
                      value: '${students.length}',
                      label: 'Pekerja terdaftar',
                    ),
                    _Count(
                      icon: Icons.badge_outlined,
                      value:
                          '${students.where((w) => w.email.isNotEmpty && w.phone.isNotEmpty).length}',
                      label: 'Profil lengkap',
                    ),
                    _Count(
                      icon: Icons.portrait_outlined,
                      value:
                          '${students.where((s) => s.faceDescriptor != null).length}',
                      label: 'Wajah siap scan',
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const AdminAttendancePanel(),
                const SizedBox(height: 26),
                _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: compact ? double.infinity : 360,
                            child: TextField(
                              controller: _search,
                              key: const ValueKey('search-students'),
                              onChanged: (_) => setState(() {}),
                              decoration:
                                  _input(
                                    'Cari nama, username, atau kontak',
                                  ).copyWith(
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                    ),
                                    suffixIcon: _search.text.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: 'Hapus pencarian',
                                            onPressed: () {
                                              _search.clear();
                                              setState(() {});
                                            },
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 18,
                                            ),
                                          ),
                                  ),
                            ),
                          ),
                          FilledButton.icon(
                            key: const ValueKey('add-student'),
                            onPressed: () => _edit(),
                            icon: const Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 19,
                            ),
                            label: const Text('Tambah pekerja'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${filtered.length} pekerja ditampilkan',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.person_search_outlined,
                                  color: _muted,
                                  size: 40,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  query.isEmpty
                                      ? 'Belum ada pekerja'
                                      : 'Pekerja tidak ditemukan',
                                  style: const TextStyle(
                                    color: _ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  query.isEmpty
                                      ? 'Tambahkan pekerja pertama untuk memulai.'
                                      : 'Coba nama atau username lainnya.',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      for (final s in filtered)
                        _StudentRow(
                          student: s,
                          onEdit: () => _edit(s),
                          onDelete: () => _delete(s),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Data wajah tersimpan lokal di perangkat ini. Tambahkan satu foto wajah yang jelas agar pekerja bisa dikenali otomatis.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

InputDecoration _input(String label) => InputDecoration(
  labelText: label,
  filled: true,
  fillColor: const Color(0xFFE6EBF2),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: _line),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: _line),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
);

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 400 ? 18 : 26),
    decoration: BoxDecoration(
      color: _paper,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

class _Count extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _Count({required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _teal, size: compact ? 18 : 22),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: compact ? 25 : 29,
            fontWeight: FontWeight.w700,
            color: _ink,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: compact ? 10 : 11,
            color: _muted,
            height: 1.4,
          ),
        ),
      ],
    );
    return RevealIn(
      child: Container(
        width: compact ? (MediaQuery.sizeOf(context).width - 60) / 3 : 185,
        constraints: const BoxConstraints(minHeight: 128),
        padding: EdgeInsets.all(compact ? 12 : 18),
        decoration: BoxDecoration(
          color: const Color(0xFFD9E1EC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFCDD7E5)),
        ),
        child: content,
      ),
    );
  }
}

class _StudentRow extends StatefulWidget {
  final PreviewStudent student;
  final VoidCallback onEdit, onDelete;
  const _StudentRow({
    required this.student,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  State<_StudentRow> createState() => _StudentRowState();
}

class _StudentRowState extends State<_StudentRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: _hover ? const Color(0xFFE0E6EF) : const Color(0xFFE5EAF2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _Portrait(bytes: s.photoBytes, name: s.name, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '@${s.handle} · ${s.email.isEmpty ? 'Lengkapi profil' : s.email}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _teal, fontSize: 12),
                  ),
                  if (s.photoBytes == null)
                    const Text(
                      'Belum ada foto',
                      style: TextStyle(color: _muted, fontSize: 10),
                    ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('edit-${s.id}'),
              tooltip: 'Edit ${s.name}',
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_outlined, color: _teal, size: 20),
            ),
            IconButton(
              key: ValueKey('delete-${s.id}'),
              tooltip: 'Hapus ${s.name}',
              onPressed: widget.onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: _danger,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  final Uint8List? bytes;
  final String name;
  final double size;
  const _Portrait({
    required this.bytes,
    required this.name,
    required this.size,
  });
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .28),
    child: SizedBox(
      width: size,
      height: size,
      child: bytes != null
          ? Image.memory(
              bytes!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined, color: _muted),
            )
          : ColoredBox(
              color: const Color(0xFFD2DBE8),
              child: Center(
                child: Text(
                  name.trim().isEmpty
                      ? '?'
                      : name.trim().characters.first.toUpperCase(),
                  style: TextStyle(
                    fontSize: size * .35,
                    color: _teal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
    ),
  );
}

class _StudentEditor extends StatefulWidget {
  final PreviewStudent? student;
  final Future<Uint8List?> Function()? choosePhoto;
  final FaceRecognizer recognizer;
  final ScannerCamera Function()? cameraFactory;
  const _StudentEditor({
    this.student,
    this.choosePhoto,
    required this.recognizer,
    this.cameraFactory,
  });
  @override
  State<_StudentEditor> createState() => _StudentEditorState();
}

class _StudentEditorState extends State<_StudentEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _className, _username, _email, _phone;
  Uint8List? _photo;
  String? _photoError;
  bool _picking = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.student?.name);
    _className = TextEditingController(text: widget.student?.className);
    _username = TextEditingController(text: widget.student?.handle);
    _email = TextEditingController(text: widget.student?.email);
    _phone = TextEditingController(text: widget.student?.phone);
    _photo = widget.student?.photoBytes;
  }

  @override
  void dispose() {
    _name.dispose();
    _className.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    setState(() {
      _picking = true;
      _photoError = null;
    });
    try {
      final Uint8List? bytes;
      if (widget.choosePhoto != null) {
        bytes = await widget.choosePhoto!();
      } else {
        final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
          requestFullMetadata: false,
        );
        bytes = await file?.readAsBytes();
      }
      if (!mounted || bytes == null) return;
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        throw const FormatException('Foto maksimal 5 MB.');
      }
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      if (mounted) setState(() => _photo = bytes);
    } catch (e) {
      if (mounted) {
        setState(
          () => _photoError = e is FormatException
              ? e.message
              : 'Foto belum dapat dibuka. Pilih gambar lain.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _scanPhoto() async {
    setState(() {
      _picking = true;
      _photoError = null;
    });
    final photo = await showDialog<Uint8List>(
      context: context,
      builder: (_) => StudentCameraDialog(
        recognizer: widget.recognizer,
        cameraFactory: widget.cameraFactory,
      ),
    );
    if (!mounted) return;
    setState(() {
      _picking = false;
      if (photo != null) _photo = photo;
    });
  }

  Future<void> _save() async {
    final valid = _form.currentState!.validate();
    if (widget.student == null && _photo == null) {
      setState(() => _photoError = 'Pilih foto pekerja terlebih dahulu.');
    }
    if (!valid ||
        (widget.student == null && _photo == null) ||
        _picking ||
        _saving) {
      return;
    }
    setState(() {
      _saving = true;
      _photoError = null;
    });
    List<double>? descriptor = widget.student?.faceDescriptor;
    try {
      if (_photo != null &&
          (descriptor == null ||
              !identical(_photo, widget.student?.photoBytes))) {
        descriptor = await widget.recognizer
            .enroll(_photo!)
            .timeout(const Duration(seconds: 60));
        if (!mounted) return;
        final duplicate = previewStudents.value
            .where(
              (s) => s.id != widget.student?.id && s.faceDescriptor != null,
            )
            .where(
              (s) =>
                  widget.recognizer.embeddingProfile.distance(
                    descriptor!,
                    s.faceDescriptor!,
                  ) <=
                  widget.recognizer.embeddingProfile.threshold,
            )
            .firstOrNull;
        if (duplicate != null) {
          throw FaceRecognitionException(
            'Wajah ini sudah terdaftar sebagai ${duplicate.name}. Edit data pekerja tersebut.',
          );
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _photoError = error is FaceRecognitionException
              ? error.message
              : 'Pemeriksaan wajah belum selesai. Coba lagi.';
        });
      }
      return;
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      PreviewStudent(
        widget.student?.id ??
            'student-${DateTime.now().microsecondsSinceEpoch}',
        _name.text.trim(),
        _className.text.trim(),
        photoBytes: _photo,
        faceDescriptor: descriptor,
        username: normalizeUsername(_username.text),
        email: _email.text.trim().toLowerCase(),
        phone: _phone.text.trim(),
        registeredAt: widget.student?.registeredAt ?? DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: _paper,
    insetPadding: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.student == null ? 'Tambah pekerja' : 'Edit pekerja',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nama lengkap, username, Gmail, nomor HP, dan foto wajah.',
                style: TextStyle(color: _muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              Center(
                child: _Portrait(bytes: _photo, name: _name.text, size: 104),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('choose-student-photo'),
                    onPressed: _picking || _saving ? null : _pickPhoto,
                    icon: Icon(
                      _picking
                          ? Icons.hourglass_top_rounded
                          : Icons.add_photo_alternate_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _picking
                          ? 'Membuka foto…'
                          : _photo == null
                          ? 'Upload foto'
                          : 'Ganti file foto',
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('scan-student-photo'),
                    onPressed: _picking || _saving ? null : _scanPhoto,
                    icon: const Icon(
                      Icons.face_retouching_natural_rounded,
                      size: 18,
                    ),
                    label: const Text('Scan langsung'),
                  ),
                ],
              ),
              if (_photoError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _photoError!,
                    style: const TextStyle(color: _danger, fontSize: 12),
                  ),
                ),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      LinearProgressIndicator(),
                      SizedBox(height: 8),
                      Text(
                        'Memeriksa satu wajah dan menyiapkan data pengenalan…',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 22),
              TextFormField(
                key: const ValueKey('student-name'),
                controller: _name,
                readOnly: _saving,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: _input('Nama lengkap'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Nama lengkap wajib diisi.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('worker-username'),
                controller: _username,
                readOnly: _saving,
                decoration: _input('Username unik'),
                autocorrect: false,
                validator: (v) {
                  final error = validateWorkerUsername(v ?? '');
                  if (error != null) return error;
                  return previewStudents.value.any(
                        (w) =>
                            w.id != widget.student?.id &&
                            normalizeUsername(w.handle) ==
                                normalizeUsername(v!),
                      )
                      ? 'Username sudah dipakai.'
                      : null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('worker-email'),
                controller: _email,
                readOnly: _saving,
                decoration: _input('Gmail'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => validateWorkerEmail(v ?? ''),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('worker-phone'),
                controller: _phone,
                readOnly: _saving,
                decoration: _input('Nomor HP'),
                keyboardType: TextInputType.phone,
                validator: (v) => validateWorkerPhone(v ?? ''),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('save-student'),
                    onPressed: _picking || _saving ? null : _save,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      _saving ? 'Memeriksa wajah…' : 'Simpan pekerja',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DeleteStudent extends StatefulWidget {
  final PreviewStudent student;
  const _DeleteStudent({required this.student});
  @override
  State<_DeleteStudent> createState() => _DeleteStudentState();
}

class _DeleteStudentState extends State<_DeleteStudent> {
  final _name = TextEditingController();
  String _normalize(String name) => normalizeUsername(name);
  bool get _nameMatches =>
      _normalize(_name.text) == _normalize(widget.student.handle);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _paper,
    insetPadding: const EdgeInsets.all(16),
    icon: const Icon(Icons.delete_outline_rounded, color: _danger, size: 32),
    title: const Text('Hapus data pekerja?'),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apakah Anda yakin ingin menghapus data pekerja ini?',
              style: TextStyle(color: _muted, height: 1.6),
            ),
            const SizedBox(height: 14),
            Text(
              widget.student.name,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
            ),
            Text(
              '@${widget.student.handle}',
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ketik username pekerja yang sama untuk mengonfirmasi. Catatan kehadiran sebelumnya tetap tersimpan.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('delete-student-name'),
              controller: _name,
              onChanged: (_) => setState(() {}),
              decoration: _input('Ketik username pekerja').copyWith(
                errorText: _name.text.trim().isNotEmpty && !_nameMatches
                    ? 'Username belum cocok. Periksa username di atas.'
                    : null,
                errorMaxLines: 2,
                helperText: _nameMatches
                    ? 'Username cocok. Data siap dihapus.'
                    : 'Huruf besar/kecil dan spasi tambahan diabaikan.',
                helperMaxLines: 2,
                suffixIcon: _nameMatches
                    ? const Icon(
                        Icons.check_circle_outline_rounded,
                        color: _teal,
                      )
                    : null,
              ),
              autocorrect: false,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Batal'),
      ),
      FilledButton(
        key: const ValueKey('confirm-delete-student'),
        style: FilledButton.styleFrom(backgroundColor: _danger),
        onPressed: _nameMatches ? () => Navigator.pop(context, true) : null,
        child: const Text('Ya, hapus pekerja'),
      ),
    ],
  );
}
