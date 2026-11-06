import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../../utils/attendance_data.dart';

// Data siswa disimpan lokal; tidak dikirim ke Firebase.
class PreviewStudent {
  final String id;
  final String name;
  final String className;
  final Uint8List? photoBytes;
  final List<double>? faceDescriptor;
  final String username, email, phone;
  final DateTime? registeredAt;
  String get handle => username.isEmpty ? id : username;

  const PreviewStudent(
    this.id,
    this.name,
    this.className, {
    this.photoBytes,
    this.faceDescriptor,
    this.username = '',
    this.email = '',
    this.phone = '',
    this.registeredAt,
  });
}

final previewStudents = ValueNotifier<List<PreviewStudent>>([]);

class PreviewAttendanceRecord {
  final String id;
  final String name;
  final String address;
  final String description;
  final String datetime;
  final String type;
  final String studentId;
  final String className;
  final DateTime? recordedAt;
  final Uint8List? photoBytes;
  final String note;
  final String username;
  final DateTime? checkedOutAt, absenceThrough, absenceEndedAt;
  final String checkoutAddress;
  final Uint8List? checkoutPhotoBytes;

  const PreviewAttendanceRecord({
    required this.id,
    required this.name,
    required this.address,
    required this.description,
    required this.datetime,
    required this.type,
    this.studentId = '',
    this.className = 'XI RPL',
    this.recordedAt,
    this.photoBytes,
    this.note = '',
    this.username = '',
    this.checkedOutAt,
    this.checkoutAddress = '',
    this.checkoutPhotoBytes,
    this.absenceThrough,
    this.absenceEndedAt,
  });
}

final previewAttendanceRecords = ValueNotifier<List<PreviewAttendanceRecord>>(
  [],
);

class AttendanceHistoryScreen extends StatelessWidget {
  final bool readOnly;
  const AttendanceHistoryScreen({super.key, this.readOnly = false});

  Future<void> _editRecord(
    BuildContext context,
    PreviewAttendanceRecord record,
  ) async {
    var name = record.name;
    var address = record.address;
    var description = record.description;
    var datetime = record.datetime;
    final formKey = GlobalKey<FormState>();
    final updated = await showDialog<PreviewAttendanceRecord>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit catatan presensi'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    onChanged: (value) => name = value,
                    decoration: const InputDecoration(labelText: 'Nama'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nama wajib diisi'
                        : null,
                  ),
                  TextFormField(
                    initialValue: address,
                    onChanged: (value) => address = value,
                    decoration: const InputDecoration(labelText: 'Alamat'),
                  ),
                  TextFormField(
                    initialValue: description,
                    onChanged: (value) => description = value,
                    decoration: const InputDecoration(labelText: 'Keterangan'),
                  ),
                  TextFormField(
                    initialValue: datetime,
                    onChanged: (value) => datetime = value,
                    decoration: const InputDecoration(labelText: 'Waktu'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                dialogContext,
                PreviewAttendanceRecord(
                  id: record.id,
                  name: name.trim(),
                  address: address.trim(),
                  description: description.trim(),
                  datetime: datetime.trim(),
                  type: record.type,
                  studentId: record.studentId,
                  className: record.className,
                  recordedAt: record.recordedAt,
                  photoBytes: record.photoBytes,
                  note: record.note,
                ),
              );
            },
            child: const Text('Simpan perubahan'),
          ),
        ],
      ),
    );
    if (updated != null) {
      try {
        await updateAttendance(
          (records) => [
            for (final item in records)
              if (item.id == record.id) updated else item,
          ],
        );
      } catch (_) {
        if (context.mounted) _storageError(context);
      }
    }
  }

  Future<void> _deleteRecord(
    BuildContext context,
    PreviewAttendanceRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus catatan presensi?'),
        content: Text('Hapus catatan presensi milik ${record.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await updateAttendance(
          (records) => records.where((item) => item.id != record.id).toList(),
        );
      } catch (_) {
        if (context.mounted) _storageError(context);
      }
    }
  }

  void _storageError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Perubahan belum disimpan. Periksa penyimpanan lokal lalu coba lagi.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFEEF3FA),
    appBar: AppBar(
      backgroundColor: _paper,
      foregroundColor: _ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      title: const Row(
        children: [
          Icon(Icons.history_rounded, color: _teal, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Riwayat presensi',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _line),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1060),
          child: ValueListenableBuilder<List<PreviewAttendanceRecord>>(
            valueListenable: previewAttendanceRecords,
            builder: (context, records, _) => CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CATATAN KEHADIRAN',
                          style: TextStyle(
                            color: _teal,
                            letterSpacing: 2,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Setiap hadir, tercatat.',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 28,
                            letterSpacing: -.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD6DEEA),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${records.length} catatan',
                                style: const TextStyle(
                                  color: _teal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Text(
                              'Tersimpan di perangkat ini',
                              style: TextStyle(color: _muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (records.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_toggle_off_rounded,
                              size: 54,
                              color: _teal,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Belum ada riwayat presensi',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Presensi yang dikonfirmasi dan izin/sakit dari admin akan muncul di sini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _muted, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverList.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return _HistoryCard(
                        record: record,
                        menu: readOnly
                            ? null
                            : PopupMenuButton<String>(
                                tooltip: 'Opsi catatan ${record.name}',
                                onSelected: (action) => action == 'edit'
                                    ? _editRecord(context, record)
                                    : _deleteRecord(context, record),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Hapus'),
                                  ),
                                ],
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

const _ink = Color(0xFF243653);
const _muted = Color(0xFF71809A);
const _teal = Color(0xFF356CD4);
const _paper = Color(0xFFF9FBFF);
const _line = Color(0xFFDCE5F2);

String _historyDate(DateTime date) {
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
  return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
}

class _HistoryCard extends StatelessWidget {
  final PreviewAttendanceRecord record;
  final Widget? menu;
  const _HistoryCard({required this.record, this.menu});

  @override
  Widget build(BuildContext context) {
    final time = attendanceTime(record);
    final permission = record.type == 'permission';
    final statusColor = permission ? const Color(0xFF916A35) : _teal;
    return Container(
      key: ValueKey('history-card-${record.id}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -46,
            right: -24,
            child: IgnorePointer(
              child: Container(
                width: 156,
                height: 156,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: statusColor.withValues(alpha: .07),
                    width: 14,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor.withValues(alpha: .06),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor,
                    statusColor.withValues(alpha: .12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.assignment_outlined,
                        color: statusColor,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'CATATAN PRESENSI',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.6,
                          color: _muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ?menu,
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 600;
                    final details = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HistoryDetail(
                          icon: Icons.person_outline_rounded,
                          label: 'Nama:',
                          value: record.name.isEmpty
                              ? 'Belum tersedia'
                              : record.name,
                          emphasized: true,
                        ),
                        _HistoryDetail(
                          icon: Icons.school_outlined,
                          label: 'Kelas:',
                          value: record.className,
                        ),
                        _HistoryDetail(
                          icon: Icons.calendar_today_outlined,
                          label: 'Hari/Tanggal:',
                          value: time == null
                              ? 'Belum tersedia'
                              : _historyDate(time),
                        ),
                        _HistoryDetail(
                          icon: Icons.schedule_rounded,
                          label: 'Jam:',
                          value: time == null
                              ? 'Belum tersedia'
                              : DateFormat('HH:mm').format(time),
                        ),
                        _HistoryDetail(
                          icon: Icons.location_on_outlined,
                          label: 'Lokasi:',
                          value: permission
                              ? 'Tidak diperlukan (izin/sakit)'
                              : record.address.trim().isEmpty
                              ? 'Belum tersedia'
                              : record.address,
                        ),
                        _HistoryDetail(
                          icon: permission
                              ? Icons.event_note_outlined
                              : Icons.check_circle_outline_rounded,
                          label: 'Keterangan:',
                          value: record.description,
                          accent: statusColor,
                        ),
                        if (record.note.isNotEmpty)
                          _HistoryDetail(
                            icon: Icons.notes_rounded,
                            label: 'Catatan:',
                            value: record.note,
                          ),
                      ],
                    );
                    final photo = Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1E7EF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _line),
                      ),
                      child: _HistoryPhoto(record: record),
                    );
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 190, height: 304, child: photo),
                          const SizedBox(width: 20),
                          Expanded(child: details),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 220, child: photo),
                        const SizedBox(height: 16),
                        details,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryPhoto extends StatelessWidget {
  final PreviewAttendanceRecord record;
  const _HistoryPhoto({required this.record});

  Widget _fallback({bool broken = false}) => ColoredBox(
    color: const Color(0xFFDBE3ED),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              broken
                  ? Icons.broken_image_outlined
                  : Icons.person_outline_rounded,
              size: 44,
              color: _teal,
            ),
            const SizedBox(height: 10),
            Text(
              broken ? 'Foto tidak dapat ditampilkan' : 'Tidak ada foto scan',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            if (record.type == 'permission') ...[
              const SizedBox(height: 6),
              const Text(
                'Dicatat oleh admin',
                style: TextStyle(color: _teal, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: record.photoBytes == null || record.photoBytes!.isEmpty
        ? _fallback()
        : Image.memory(
            record.photoBytes!,
            key: ValueKey('history-photo-${record.id}'),
            semanticLabel: 'Foto presensi ${record.name}',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -.25),
            errorBuilder: (_, error, stack) => _fallback(broken: true),
          ),
  );
}

class _HistoryDetail extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool emphasized;
  final Color? accent;
  const _HistoryDetail({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasized = false,
    this.accent,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 7),
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
    decoration: BoxDecoration(
      color: accent?.withValues(alpha: .08) ?? const Color(0xFFE9EDF3),
      borderRadius: BorderRadius.circular(11),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 300;
        final labelText = Text(
          label,
          style: const TextStyle(color: _muted, fontSize: 11, height: 1.5),
        );
        final valueText = Text(
          value.trim().isEmpty ? 'Belum tersedia' : value,
          style: TextStyle(
            color: accent ?? _ink,
            fontSize: emphasized ? 15 : 12,
            height: 1.5,
            fontWeight: emphasized || accent != null
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: accent ?? _teal, size: 17),
            ),
            const SizedBox(width: 10),
            if (compact)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [labelText, const SizedBox(height: 2), valueText],
                ),
              )
            else ...[
              SizedBox(width: 94, child: labelText),
              const SizedBox(width: 10),
              Expanded(child: valueText),
            ],
          ],
        );
      },
    ),
  );
}

/* REFERENSI ASLI COURSE (Step 13-14), belum terhubung ke backend.
StreamBuilder<QuerySnapshot>(
  stream: dataCollection.snapshots(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return const Center(child: Text("Belum ada riwayat presensi"));
    }

    // Urutkan data berdasarkan created_at secara aman di memori
    final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
    docs.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>? ?? {};
      final dataB = b.data() as Map<String, dynamic>? ?? {};
      final timeA = dataA['created_at'] as Timestamp?;
      final timeB = dataB['created_at'] as Timestamp?;
      if (timeA != null && timeB != null) {
        return timeB.compareTo(timeA);
      }
      return 0;
    });

    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>? ?? {};
        final docId = docs[index].id;
        final name = data['name']?.toString() ?? 'Unknown';
        final address = data['address']?.toString() ?? '-';
        final description = data['description']?.toString() ?? '-';
        final datetime = data['datetime']?.toString() ?? '-';

        return _buildAttendanceCard(docId, name, address, description, datetime);
      },
    );
  },
)


Color _getAvatarColor(String name) {
  if (name.trim().isEmpty) return Colors.blueGrey;
  final int hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
  return Colors.primaries[hash % Colors.primaries.length];
}

// 1. Memperbarui dokumen:
await dataCollection.doc(docId).update({
  'name': nameController.text.trim(),
  'address': addressController.text.trim(),
  'description': descriptionController.text.trim(),
  'datetime': datetimeController.text.trim(),
});

// 2. Menghapus dokumen:
await dataCollection.doc(docId).delete();

*/
