import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/ui/attendance_history/attendance_history_screen.dart';

class AbsentScreen extends StatefulWidget {
  const AbsentScreen({super.key});

  @override
  State<AbsentScreen> createState() => _AbsentScreenState();
}

class _AbsentScreenState extends State<AbsentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _fromController = TextEditingController();
  final _untilController = TextEditingController();
  final _noteController = TextEditingController();
  String _category = 'Sakit';
  DateTime? _fromDate;
  DateTime? _untilDate;

  @override
  void dispose() {
    _nameController.dispose();
    _fromController.dispose();
    _untilController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool from}) async {
    final selected = from ? _fromDate : _untilDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selected ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;
    setState(() {
      final controller = from ? _fromController : _untilController;
      controller.text = DateFormat('dd/MM/yyyy').format(pickedDate);
      if (from) {
        _fromDate = pickedDate;
      } else {
        _untilDate = pickedDate;
      }
    });
  }

  void _submitPreview() {
    if (!_formKey.currentState!.validate()) return;
    final note = _noteController.text.trim();
    previewAttendanceRecords.value = [
      PreviewAttendanceRecord(
        id: 'permission-${DateTime.now().microsecondsSinceEpoch}',
        name: _nameController.text.trim(),
        address: '-',
        description: note.isEmpty ? _category : '$_category · $note',
        datetime: '${_fromController.text} - ${_untilController.text}',
        type: 'permission',
      ),
      ...previewAttendanceRecords.value,
    ];
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Izin contoh tersimpan di riwayat lokal')),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permission / Leave')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(
                  Icons.event_note_outlined,
                  size: 64,
                  color: Color(0xFF1A008F),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Form izin dan sakit',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Preview UI · Pengajuan hanya disimpan sementara di perangkat ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama siswa',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Sakit', child: Text('Sakit')),
                    DropdownMenuItem(value: 'Izin', child: Text('Izin')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fromController,
                  readOnly: true,
                  onTap: () => _pickDate(from: true),
                  decoration: const InputDecoration(
                    labelText: 'Dari tanggal',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _untilController,
                  readOnly: true,
                  onTap: () => _pickDate(from: false),
                  decoration: const InputDecoration(
                    labelText: 'Sampai tanggal',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  validator: (value) {
                    final requiredError = _required(value);
                    if (requiredError != null) return requiredError;
                    if (_fromDate != null &&
                        _untilDate != null &&
                        _untilDate!.isBefore(_fromDate!)) {
                      return 'Tanggal akhir tidak boleh sebelum tanggal mulai';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan (opsional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _submitPreview,
                  icon: const Icon(Icons.check),
                  label: const Text('Simpan izin contoh'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* REFERENSI ASLI COURSE (Step 12), belum terhubung ke backend.
Future<void> _pickDate(TextEditingController controller) async {
  final DateTime? pickedDate = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );

  if (pickedDate != null) {
    setState(() {
      controller.text = DateFormat('dd/MM/yyyy').format(pickedDate);
    });
  }
}

Future<void> submitPermission(String nama, String keterangan, String from, String until) async {
  await dataCollection.add({
    'name': nama.trim(),
    'address': '-',
    'description': keterangan,
    'datetime': '$from - $until',
    'type': 'permission',
    'created_at': FieldValue.serverTimestamp(),
  });
}

*/
