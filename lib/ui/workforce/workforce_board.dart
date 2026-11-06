import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../attendance_history/attendance_history_screen.dart';
import '../../utils/attendance_data.dart';
import '../../utils/workforce_data.dart';
import 'ui_motion.dart';

const _ink = Color(0xFF243653),
    _muted = Color(0xFF71809A),
    _teal = Color(0xFF356CD4);
const _line = Color(0xFFDCE5F2), _paper = Color(0xFFF9FBFF);

class WorkforceBoard extends StatefulWidget {
  final DateTime? day;
  final bool history;
  const WorkforceBoard({super.key, this.day, this.history = false});
  @override
  State<WorkforceBoard> createState() => _WorkforceBoardState();
}

class _WorkforceBoardState extends State<WorkforceBoard> {
  final _search = TextEditingController();
  int _tab = 0;
  DateTime? _chosen;
  DateTime get _day => workDay(_chosen ?? widget.day ?? DateTime.now());
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PreviewAttendanceRecord> _filter(
    List<PreviewAttendanceRecord> records,
    int tab,
  ) {
    final type = ['attendance', 'permission', 'absence'][tab];
    final q = _search.text.trim().toLowerCase();
    final filtered = records.where((r) {
      if (r.type != type) return false;
      final time = attendanceTime(r);
      if (time == null) return false;
      // A deleted worker's open interval is historical, not an indefinitely
      // active absence. Keep its recorded missing days without inventing a
      // return timestamp or showing it as an active worker today.
      if (type == 'absence' &&
          r.absenceEndedAt == null &&
          !previewStudents.value.any((w) => w.id == r.studentId) &&
          (r.absenceThrough == null ||
              _day.isAfter(workDay(r.absenceThrough!)))) {
        return false;
      }
      final inDay = type == 'absence'
          ? !workDay(time).isAfter(_day) &&
                (r.absenceEndedAt == null ||
                    !workDay(r.absenceEndedAt!).isBefore(_day))
          : sameAttendanceDay(time, _day);
      return inDay &&
          '${r.name} ${r.username} ${r.note}'.toLowerCase().contains(q);
    }).toList();
    filtered.sort((a, b) => attendanceTime(b)!.compareTo(attendanceTime(a)!));
    return filtered;
  }

  Future<void> _chooseDay() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _day.isAfter(now) ? now : _day,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Pilih tanggal rekap',
    );
    if (mounted && day != null) setState(() => _chosen = day);
  }

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<List<PreviewAttendanceRecord>>(
    valueListenable: previewAttendanceRecords,
    builder: (context, records, _) {
      final filtered = _filter(records, _tab);
      return Container(
        key: const ValueKey('workforce-board'),
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 700 ? 14 : 20,
        ),
        decoration: BoxDecoration(
          color: _paper,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(24),
        ),
        child: LayoutBuilder(
          builder: (context, c) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBE3ED),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.view_timeline_outlined,
                      color: _teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REKAP KEHADIRAN',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.7,
                            color: _muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Team activity.',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                            letterSpacing: -.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Flex(
                direction: c.maxWidth < 650 ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: c.maxWidth < 650
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: c.maxWidth < 650
                    ? [
                        _searchField(),
                        const SizedBox(height: 10),
                        _dateButton(),
                      ]
                    : [
                        Expanded(child: _searchField()),
                        const SizedBox(width: 12),
                        _dateButton(),
                      ],
              ),
              const SizedBox(height: 16),
              MotionTabs(
                labels: [
                  for (var i = 0; i < 3; i++)
                    '${['Masuk', 'Izin', 'Alpha'][i]}  ${_filter(records, i).length}',
                ],
                selected: _tab,
                keyPrefix: 'work-tab-',
                onChanged: (index) => setState(() => _tab = index),
              ),
              const SizedBox(height: 17),
              if (c.maxWidth >= 760)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5EAF1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Expanded(flex: 4, child: _ColumnTitle('PEKERJA')),
                      Expanded(
                        flex: 3,
                        child: _ColumnTitle(
                          _tab == 2
                              ? 'MULAI ALPHA'
                              : _tab == 1
                              ? 'DIAJUKAN'
                              : 'JAM MASUK',
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _ColumnTitle(
                          _tab == 2
                              ? 'SELESAI ALPHA'
                              : _tab == 1
                              ? 'ALASAN'
                              : 'JAM PULANG',
                        ),
                      ),
                      const SizedBox(
                        width: 142,
                        child: _ColumnTitle('KONDISI'),
                      ),
                    ],
                  ),
                ),
              MotionResize(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 36,
                          horizontal: 12,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _tab == 2
                                  ? Icons.event_available_outlined
                                  : Icons.receipt_long_outlined,
                              color: _muted,
                              size: 35,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada catatan ${['masuk', 'izin', 'Alpha'][_tab]}',
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              _tab == 2
                                  ? 'Alpha dibuat setelah satu hari penuh tanpa keterangan.\nHari ini belum selesai, jadi belum otomatis Alpha.'
                                  : 'Catatan tanggal ${workDate(_day)} akan tampil di sini.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                                height: 1.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (final record in filtered)
                      _WorkerRecordRow(
                        record: record,
                        wide: c.maxWidth >= 760,
                        onTap: () => _showRecord(context, record),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _tab == 2
                    ? 'Periode Alpha tetap tersimpan setelah pekerja kembali. Akhir periode adalah waktu scan masuk/izin berikutnya.'
                    : _tab == 1
                    ? 'Ketuk kartu untuk melihat foto verifikasi dan detail pengajuan izin.'
                    : 'Ketuk kartu untuk melihat foto dan lokasi. Jam pulang terisi setelah scan pulang dikonfirmasi.',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _searchField() => TextField(
    controller: _search,
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      hintText: 'Cari nama atau username…',
      prefixIcon: const Icon(Icons.search_rounded, size: 20),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFE9EDF3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _line),
      ),
    ),
  );
  Widget _dateButton() => OutlinedButton.icon(
    onPressed: _chooseDay,
    icon: const Icon(Icons.calendar_today_outlined, size: 17),
    label: Text(workDate(_day)),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
  );
}

class _ColumnTitle extends StatelessWidget {
  final String text;
  const _ColumnTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _muted,
      fontWeight: FontWeight.w700,
      fontSize: 10,
      letterSpacing: .7,
    ),
  );
}

class _WorkerRecordRow extends StatelessWidget {
  final PreviewAttendanceRecord record;
  final bool wide;
  final VoidCallback onTap;
  const _WorkerRecordRow({
    required this.record,
    required this.wide,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final leave = record.type == 'permission', alpha = record.type == 'absence';
    final color = alpha
        ? const Color(0xFF98584D)
        : leave
        ? const Color(0xFF916A35)
        : _teal;
    final status = alpha
        ? record.absenceEndedAt == null
              ? previewStudents.value.any((w) => w.id == record.studentId)
                    ? 'Alpha aktif'
                    : 'Profil dihapus'
              : 'Selesai'
        : leave
        ? record.description
        : record.checkedOutAt == null
        ? 'Sedang bekerja'
        : 'Istirahat';
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            alpha
                ? Icons.event_busy_outlined
                : leave
                ? Icons.medical_information_outlined
                : record.checkedOutAt == null
                ? Icons.work_outline_rounded
                : Icons.coffee_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    final person = Row(
      children: [
        _WorkerPhoto(bytes: record.photoBytes, name: record.name, size: 42),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.name,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                record.username.isEmpty
                    ? 'Catatan sebelumnya'
                    : '@${record.username}',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
    final first = _TimeCell(
      label: alpha
          ? 'Mulai Alpha'
          : leave
          ? 'Diajukan'
          : 'Masuk',
      time: attendanceTime(record),
      dateOnly: alpha,
      large: !wide,
    );
    final last = leave
        ? _ReasonCell(record.note)
        : _TimeCell(
            label: alpha ? 'Selesai Alpha' : 'Pulang',
            time: alpha ? record.absenceEndedAt : record.checkedOutAt,
            dateOnly: alpha,
            large: !wide,
          );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TouchFeedback(
        hoverScale: 1.004,
        hoverLift: 3,
        child: Material(
          color: wide ? const Color(0xFFE9EDF3) : const Color(0xFFF8FAFC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE1E8F2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: const Color(0xFFD9E1EC),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: wide
                  ? Row(
                      children: [
                        Expanded(flex: 4, child: person),
                        Expanded(
                          flex: 3,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: first,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: last,
                          ),
                        ),
                        SizedBox(width: 142, child: badge),
                      ],
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final small = constraints.maxWidth < 380;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: person),
                                const SizedBox(width: 8),
                                if (!small) badge,
                                const Padding(
                                  padding: EdgeInsets.only(top: 10, left: 6),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: Color(0xFF8EA2BC),
                                  ),
                                ),
                              ],
                            ),
                            if (small) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: badge,
                              ),
                            ],
                            const SizedBox(height: 14),
                            if (leave && small) ...[
                              _TimeCell(
                                label: 'Diajukan',
                                time: attendanceTime(record),
                                horizontal: true,
                              ),
                              const SizedBox(height: 8),
                              last,
                            ] else
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (leave)
                                      SizedBox(width: 140, child: first)
                                    else
                                      Expanded(child: first),
                                    const SizedBox(width: 10),
                                    Expanded(child: last),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  final String label;
  final DateTime? time;
  final bool dateOnly, large, horizontal;
  const _TimeCell({
    required this.label,
    this.time,
    this.dateOnly = false,
    this.large = false,
    this.horizontal = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFDDE4EE),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFFCED8E5)),
    ),
    child: horizontal
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 17, color: _teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ),
                  Text(
                    time == null
                        ? '—'
                        : DateFormat('HH:mm').format(time!.toLocal()),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (time != null) ...[
                const SizedBox(height: 5),
                Text(
                  workDate(time!),
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
              const SizedBox(height: 4),
              Text(
                time == null
                    ? '—'
                    : dateOnly
                    ? workDate(time!)
                    : DateFormat('HH:mm').format(time!.toLocal()),
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: large && !dateOnly ? 21 : 14,
                  letterSpacing: large ? -.4 : 0,
                ),
              ),
              if (time != null && !dateOnly)
                Text(
                  workDate(time!),
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
            ],
          ),
  );
}

class _ReasonCell extends StatelessWidget {
  final String note;
  const _ReasonCell(this.note);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    constraints: const BoxConstraints(minHeight: 77),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F6FB),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE0E7F1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          children: [
            Icon(Icons.notes_rounded, color: _muted, size: 14),
            SizedBox(width: 6),
            Text('Alasan izin', style: TextStyle(color: _muted, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          note.isEmpty ? 'Tanpa catatan' : note,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class _WorkerPhoto extends StatelessWidget {
  final Uint8List? bytes;
  final String name;
  final double size;
  const _WorkerPhoto({this.bytes, required this.name, this.size = 42});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: size,
      height: size,
      color: const Color(0xFFD4DDE9),
      child: bytes == null
          ? Center(
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: _teal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Image.memory(
              bytes!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.person_outline_rounded, color: _teal),
            ),
    ),
  );
}

Future<void> _showRecord(
  BuildContext context,
  PreviewAttendanceRecord record,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    backgroundColor: _paper,
    title: Text(record.name),
    content: SizedBox(
      width: 550,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (record.photoBytes != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _recordPhoto(record.photoBytes!),
                        const SizedBox(height: 6),
                        Text(
                          record.type == 'permission'
                              ? 'Verifikasi izin'
                              : 'Foto masuk',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (record.checkoutPhotoBytes != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          _recordPhoto(record.checkoutPhotoBytes!),
                          const SizedBox(height: 6),
                          const Text(
                            'Foto pulang',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 18),
            for (final entry in <String, String>{
              'Username': record.username.isEmpty ? '—' : '@${record.username}',
              if (record.type == 'absence') ...{
                'Mulai Alpha': workTimestamp(attendanceTime(record)),
                'Selesai Alpha': workTimestamp(record.absenceEndedAt),
              },
              if (record.type == 'attendance') ...{
                'Masuk': workTimestamp(attendanceTime(record)),
                'Pulang': workTimestamp(record.checkedOutAt),
                'Lokasi masuk': record.address,
                'Lokasi pulang': record.checkoutAddress.isEmpty
                    ? '—'
                    : record.checkoutAddress,
              },
              if (record.type == 'permission') ...{
                'Diajukan': workTimestamp(attendanceTime(record)),
                'Keterangan': record.description,
                'Alasan': record.note,
              },
            }.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    const SizedBox(height: 3),
                    SelectableText(
                      entry.value,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Tutup'),
      ),
    ],
  ),
);
Widget _recordPhoto(Uint8List bytes) => ClipRRect(
  borderRadius: BorderRadius.circular(14),
  child: Image.memory(
    bytes,
    height: 190,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => const SizedBox(
      height: 120,
      child: Center(child: Text('Foto tidak dapat ditampilkan')),
    ),
  ),
);
