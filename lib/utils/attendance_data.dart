import 'dart:convert';
import 'package:intl/intl.dart';
import '../ui/attendance_history/attendance_history_screen.dart';
import 'attendance_storage_stub.dart'
    if (dart.library.io) 'attendance_storage_native.dart'
    if (dart.library.js_interop) 'attendance_storage_web.dart'
    as platform;

abstract class AttendanceStore {
  Future<List<PreviewAttendanceRecord>?> load();
  Future<void> save(List<PreviewAttendanceRecord> records);
}

AttendanceStore attendanceStore = platform.createAttendanceStore();
String? attendanceStorageProblem;
Future<void>? _pendingWrite;

DateTime? attendanceTime(PreviewAttendanceRecord record) {
  if (record.recordedAt != null) return record.recordedAt!.toLocal();
  try {
    return DateFormat('dd/MM/yyyy HH:mm').parseStrict(record.datetime);
  } on FormatException {
    return null;
  }
}

bool sameAttendanceDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool attendanceOnDay(PreviewAttendanceRecord record, DateTime day) {
  final time = attendanceTime(record);
  return time != null && sameAttendanceDay(time, day);
}

bool attendanceBelongsTo(
  PreviewAttendanceRecord record,
  PreviewStudent student,
) => record.studentId.isNotEmpty
    ? record.studentId == student.id
    : record.name == student.name && record.className == student.className;

// Publish only after the IndexedDB transaction commits. Serialized mutations
// revalidate the latest data; failed writes leave the current records intact.
Future<void> updateAttendance(
  List<PreviewAttendanceRecord> Function(List<PreviewAttendanceRecord>) change,
) {
  Future<void> perform() async {
    if (attendanceStorageProblem != null) {
      throw StateError(attendanceStorageProblem!);
    }
    final updated = change(List.of(previewAttendanceRecords.value));
    await attendanceStore.save(updated);
    previewAttendanceRecords.value = updated;
  }

  final operation = _pendingWrite?.then((_) => perform()) ?? perform();
  final tail = operation.then<void>(
    (_) {},
    onError: (Object error, StackTrace stack) {},
  );
  _pendingWrite = tail;
  tail.then((_) {
    if (identical(_pendingWrite, tail)) _pendingWrite = null;
  });
  return operation;
}

String encodeAttendance(List<PreviewAttendanceRecord> records) => jsonEncode([
  for (final r in records)
    {
      'id': r.id,
      'studentId': r.studentId,
      'name': r.name,
      'className': r.className,
      'address': r.address,
      'description': r.description,
      'datetime': r.datetime,
      'type': r.type,
      'recordedAt': r.recordedAt?.toIso8601String(),
      'note': r.note,
      'username': r.username,
      'checkedOutAt': r.checkedOutAt?.toIso8601String(),
      'checkoutAddress': r.checkoutAddress,
      'checkoutPhoto': r.checkoutPhotoBytes == null
          ? null
          : base64Encode(r.checkoutPhotoBytes!),
      'absenceThrough': r.absenceThrough?.toIso8601String(),
      'absenceEndedAt': r.absenceEndedAt?.toIso8601String(),
      'photo': r.photoBytes == null ? null : base64Encode(r.photoBytes!),
    },
]);

List<PreviewAttendanceRecord>? decodeAttendance(String json) {
  final data = jsonDecode(json);
  if (data == null) return null;
  return (data as List).map((value) {
    final r = value as Map<String, dynamic>;
    return PreviewAttendanceRecord(
      id: r['id'] as String,
      studentId: r['studentId'] as String? ?? '',
      name: r['name'] as String,
      className: r['className'] as String,
      address: r['address'] as String,
      description: r['description'] as String,
      datetime: r['datetime'] as String,
      type: r['type'] as String,
      recordedAt: r['recordedAt'] == null
          ? null
          : DateTime.parse(r['recordedAt'] as String),
      note: r['note'] as String? ?? '',
      username: r['username'] as String? ?? '',
      checkedOutAt: DateTime.tryParse(r['checkedOutAt'] as String? ?? ''),
      checkoutAddress: r['checkoutAddress'] as String? ?? '',
      checkoutPhotoBytes: r['checkoutPhoto'] == null
          ? null
          : base64Decode(r['checkoutPhoto'] as String),
      absenceThrough: DateTime.tryParse(r['absenceThrough'] as String? ?? ''),
      absenceEndedAt: DateTime.tryParse(r['absenceEndedAt'] as String? ?? ''),
      photoBytes: r['photo'] == null
          ? null
          : base64Decode(r['photo'] as String),
    );
  }).toList();
}
