import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../ui/attendance_history/attendance_history_screen.dart';
import 'attendance_data.dart';
import 'face_recognizer.dart';
import 'face_services.dart';

/// Local demo capability, scoped to one unlocked admin page. Chat messages
/// cannot change this capability and leaving/locking the page revokes it.
class AdminSession {
  bool _active = true;
  AdminSession._();
  static AdminSession? unlock(String password) =>
      password == '123456' ? AdminSession._() : null;
  bool get active => _active;
  void revoke() => _active = false;
  void require() {
    if (!_active) throw StateError('Akses admin sudah terkunci.');
  }
}

DateTime workDay(DateTime date) => DateTime(date.year, date.month, date.day);
String workDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);
String workTimestamp(DateTime? date) => date == null
    ? '—'
    : DateFormat('dd/MM/yyyy · HH:mm').format(date.toLocal());
String normalizeUsername(String value) =>
    value.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
String? validateWorkerUsername(String value) =>
    RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_.-]{2,29}$').hasMatch(value.trim())
    ? null
    : 'Username 3–30 karakter: huruf, angka, titik, _ atau -.';
String? validateWorkerEmail(String value) =>
    RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@gmail\.com$',
      caseSensitive: false,
    ).hasMatch(value.trim())
    ? null
    : 'Gunakan alamat yang berakhiran @gmail.com.';
String? validateWorkerPhone(String value) =>
    RegExp(r'^\+?[0-9]{8,15}$').hasMatch(value.trim())
    ? null
    : 'Isi 8–15 digit angka (boleh diawali +).';

PreviewAttendanceRecord? dayRecord(
  PreviewStudent worker,
  List<PreviewAttendanceRecord> records,
  DateTime day,
) {
  for (final r in records) {
    if (r.type != 'absence' &&
        attendanceBelongsTo(r, worker) &&
        attendanceOnDay(r, day)) {
      return r;
    }
  }
  return null;
}

enum WorkScanAction { checkIn, checkOut, finished, onLeave }

WorkScanAction nextWorkAction(
  PreviewStudent worker,
  List<PreviewAttendanceRecord> records,
  DateTime now,
) {
  final record = dayRecord(worker, records, now);
  if (record == null) return WorkScanAction.checkIn;
  if (record.type == 'permission') return WorkScanAction.onLeave;
  return record.checkedOutAt == null
      ? WorkScanAction.checkOut
      : WorkScanAction.finished;
}

/// Missing complete calendar days form intervals, not overwritten daily flags.
/// A return/permission closes the interval at its actual timestamp. Today is
/// never made Alpha just because it has not finished yet. Old closed intervals
/// remain after returning, and deleted workers' historical intervals are kept.
List<PreviewAttendanceRecord> reconcileAbsences(
  List<PreviewStudent> workers,
  List<PreviewAttendanceRecord> records,
  DateTime now,
) {
  final today = workDay(now), ids = workers.map((w) => w.id).toSet();
  final result = records
      .where((r) => r.type != 'absence' || !ids.contains(r.studentId))
      .toList();
  final old = {
    for (final r in records.where((r) => r.type == 'absence')) r.id: r,
  };
  for (final worker in workers) {
    if (worker.registeredAt == null) continue;
    DateTime? start, through;
    final events = <DateTime, PreviewAttendanceRecord>{};
    for (final r in result.where(
      (r) => r.type != 'absence' && attendanceBelongsTo(r, worker),
    )) {
      final time = attendanceTime(r);
      if (time != null && !time.isAfter(now)) {
        final key = workDay(time), previous = events[workDay(time)];
        if (previous == null || time.isBefore(attendanceTime(previous)!)) {
          events[key] = r;
        }
      }
    }
    void finish(DateTime? end) {
      if (start == null) return;
      final id = 'absence:${worker.id}:${start!.toIso8601String()}';
      final previous = old[id];
      if (previous != null &&
          previous.absenceThrough == through &&
          previous.absenceEndedAt == end) {
        result.add(previous);
      } else {
        result.add(
          PreviewAttendanceRecord(
            id: id,
            studentId: worker.id,
            name: worker.name,
            className: worker.className,
            username: worker.handle,
            address: 'Tidak ada catatan lokasi',
            description: 'Alpha',
            datetime: DateFormat('dd/MM/yyyy HH:mm').format(start!),
            recordedAt: start,
            type: 'absence',
            absenceThrough: through,
            absenceEndedAt: end,
          ),
        );
      }
      start = null;
      through = null;
    }

    for (
      var date = workDay(worker.registeredAt!);
      !date.isAfter(today);
      date = DateTime(date.year, date.month, date.day + 1)
    ) {
      final event = events[date];
      if (event != null) {
        finish(attendanceTime(event));
      } else if (date.isBefore(today)) {
        start ??= date;
        through = date;
      }
    }
    finish(null);
  }
  result.sort(
    (a, b) =>
        (attendanceTime(b) ?? today).compareTo(attendanceTime(a) ?? today),
  );
  return result;
}

Future<void> synchronizeWorkerAbsences({DateTime? now}) async {
  final time = now ?? DateTime.now();
  final current = previewAttendanceRecords.value;
  final next = reconcileAbsences(previewStudents.value, current, time);
  if (encodeAttendance(current) == encodeAttendance(next)) return;
  await updateAttendance(
    (records) => reconcileAbsences(previewStudents.value, records, time),
  );
}

Future<void> migrateWorkerProfiles(DateTime now) async {
  final workers = previewStudents.value;
  if (!workers.any((w) => w.username.isEmpty || w.registeredAt == null)) return;
  final used = workers
      .where((w) => w.username.isNotEmpty)
      .map((w) => normalizeUsername(w.username))
      .toSet();
  final migrated = workers.map((w) {
    var username = w.username;
    if (username.isEmpty) {
      var base = w.name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '.')
          .replaceAll(RegExp(r'^\.+|\.+$'), '');
      if (base.length < 3) base = 'pekerja';
      if (base.length > 24) base = base.substring(0, 24);
      username = base;
      for (var i = 2; used.contains(username); i++) {
        username = '$base$i';
      }
      used.add(username);
    }
    return PreviewStudent(
      w.id,
      w.name,
      w.className,
      photoBytes: w.photoBytes,
      faceDescriptor: w.faceDescriptor,
      username: username,
      email: w.email,
      phone: w.phone,
      registeredAt: w.registeredAt ?? workDay(now),
    );
  }).toList();
  if (studentStorageProblem != null) throw StateError(studentStorageProblem!);
  await studentStore.save(migrated);
  previewStudents.value = migrated;
}

Future<void>? _directoryWrite;
Future<void> updateWorkers(
  AdminSession session,
  List<PreviewStudent> Function(List<PreviewStudent>) change,
) {
  Future<void> perform() async {
    session.require();
    if (studentStorageProblem != null) throw StateError(studentStorageProblem!);
    final updated = change(List.of(previewStudents.value));
    final usernames = updated.map((w) => normalizeUsername(w.handle)).toList();
    if (usernames.toSet().length != usernames.length) {
      throw StateError('Username sudah dipakai pekerja lain.');
    }
    session.require();
    await studentStore.save(updated);
    previewStudents.value = updated;
  }

  final operation = (_directoryWrite ?? Future<void>.value()).then(
    (_) => perform(),
  );
  final tail = operation.then<void>(
    (_) {},
    onError: (Object e, StackTrace s) {},
  );
  _directoryWrite = tail;
  tail.then((_) {
    if (identical(_directoryWrite, tail)) _directoryWrite = null;
  });
  return operation;
}

Future<void> deleteWorker(
  AdminSession session,
  PreviewStudent worker,
  String typedUsername,
) async {
  session.require();
  if (normalizeUsername(typedUsername) != normalizeUsername(worker.handle)) {
    throw StateError('Username konfirmasi belum cocok.');
  }
  await synchronizeWorkerAbsences();
  await updateWorkers(session, (workers) {
    if (!workers.any((w) => identical(w, worker))) {
      throw StateError('Data pekerja berubah. Cari ulang pekerja tersebut.');
    }
    return workers.where((w) => w.id != worker.id).toList();
  });
}

Future<void> saveWorkScan({
  required PreviewStudent worker,
  required DateTime capturedAt,
  required DateTime now,
  required WorkScanAction expectedAction,
  required String address,
  required Uint8List photo,
}) async {
  if (!sameAttendanceDay(capturedAt, now) ||
      now.difference(capturedAt).isNegative ||
      now.difference(capturedAt) > const Duration(minutes: 5)) {
    throw StateError('Sesi sudah lewat. Scan wajah lagi.');
  }
  await updateAttendance((records) {
    if (!previewStudents.value.any((w) => identical(w, worker))) {
      throw StateError('Data pekerja berubah. Scan ulang.');
    }
    final action = nextWorkAction(worker, records, now);
    if (action != expectedAction ||
        action == WorkScanAction.finished ||
        action == WorkScanAction.onLeave) {
      throw StateError(
        'Catatan pekerja sudah berubah atau sudah lengkap. Scan ulang.',
      );
    }
    if (address.trim().isEmpty || photo.isEmpty) {
      throw StateError('Foto dan lokasi wajib tersedia.');
    }
    if (action == WorkScanAction.checkIn) {
      records.insert(
        0,
        PreviewAttendanceRecord(
          id: 'work-${worker.id}-${capturedAt.microsecondsSinceEpoch}',
          studentId: worker.id,
          name: worker.name,
          username: worker.handle,
          className: worker.className,
          address: address,
          description: 'Masuk',
          datetime: DateFormat('dd/MM/yyyy HH:mm').format(capturedAt),
          recordedAt: capturedAt,
          type: 'attendance',
          photoBytes: photo,
        ),
      );
    } else {
      final original = dayRecord(worker, records, now)!;
      final entry = attendanceTime(original)!;
      if (!capturedAt.isAfter(entry)) {
        throw StateError('Jam pulang harus setelah jam masuk.');
      }
      final replacement = PreviewAttendanceRecord(
        id: original.id,
        studentId: original.studentId,
        name: original.name,
        username: original.username,
        className: original.className,
        address: original.address,
        description: original.description,
        datetime: original.datetime,
        recordedAt: original.recordedAt,
        type: original.type,
        photoBytes: original.photoBytes,
        note: original.note,
        checkedOutAt: capturedAt,
        checkoutAddress: address,
        checkoutPhotoBytes: photo,
      );
      records = [
        for (final r in records)
          if (r.id == original.id) replacement else r,
      ];
    }
    return reconcileAbsences(previewStudents.value, records, now);
  });
}

class WorkerFaceProof {
  final PreviewStudent worker;
  final Uint8List photo;
  final DateTime verifiedAt;
  bool _used = false;
  WorkerFaceProof._(this.worker, this.photo, this.verifiedAt);
}

Future<WorkerFaceProof> verifyWorkerPhoto(
  String username,
  Uint8List photo,
  FaceRecognizer recognizer, {
  DateTime? now,
}) async {
  if (photo.isEmpty) {
    throw StateError('Foto wajah belum tersedia. Ambil foto ulang.');
  }
  final candidates = previewStudents.value
      .where((w) => normalizeUsername(w.handle) == normalizeUsername(username))
      .toList();
  if (candidates.length != 1) {
    throw StateError(
      'Username pekerja tidak ditemukan. Periksa lagi username-mu.',
    );
  }
  final worker = candidates.single;
  final result = await recognizer.scan(photo, List.of(previewStudents.value));
  if (result.status != FaceScanStatus.matched ||
      result.student?.id != worker.id) {
    throw StateError(
      'Wajah tidak cocok dengan username ini. Ambil foto ulang dengan satu wajah yang jelas.',
    );
  }
  if (!previewStudents.value.any((w) => identical(w, worker))) {
    throw StateError('Data pekerja berubah. Verifikasi lagi.');
  }
  return WorkerFaceProof._(
    worker,
    Uint8List.fromList(photo),
    now ?? DateTime.now(),
  );
}

Future<void> submitWorkerLeave(
  WorkerFaceProof proof,
  String reason,
  String kind, {
  DateTime? now,
}) async {
  final time = now ?? DateTime.now();
  if (!['Izin', 'Sakit'].contains(kind) ||
      reason.trim().length < 3 ||
      reason.trim().length > 500) {
    throw StateError('Pilih Izin/Sakit dan isi alasan 3–500 karakter.');
  }
  await updateAttendance((records) {
    if (proof._used ||
        !sameAttendanceDay(proof.verifiedAt, time) ||
        time.difference(proof.verifiedAt).isNegative ||
        time.difference(proof.verifiedAt) > const Duration(minutes: 5) ||
        !previewStudents.value.any((w) => identical(w, proof.worker))) {
      throw StateError(
        'Verifikasi wajah sudah kedaluwarsa. Silakan verifikasi lagi.',
      );
    }
    if (dayRecord(proof.worker, records, time) != null) {
      throw StateError(
        'Pekerja sudah memiliki catatan hari ini. Hubungi admin untuk koreksi.',
      );
    }
    records.insert(
      0,
      PreviewAttendanceRecord(
        id: 'leave-${proof.worker.id}-${time.microsecondsSinceEpoch}',
        studentId: proof.worker.id,
        name: proof.worker.name,
        username: proof.worker.handle,
        className: proof.worker.className,
        address: 'Izin jarak jauh · lokasi tidak diperlukan',
        description: kind,
        datetime: DateFormat('dd/MM/yyyy HH:mm').format(time),
        recordedAt: time,
        type: 'permission',
        photoBytes: proof.photo,
        note: reason.trim(),
      ),
    );
    return reconcileAbsences(previewStudents.value, records, time);
  });
  proof._used = true;
}
