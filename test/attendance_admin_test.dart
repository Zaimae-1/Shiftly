import 'dart:typed_data';
import 'package:attendance_app/main.dart';
import 'package:attendance_app/ui/admin/admin_screen.dart';
import 'package:attendance_app/ui/attendance_history/attendance_history_screen.dart';
import 'package:attendance_app/utils/attendance_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'admin_test.dart' show unlock, tapVisible;

PreviewAttendanceRecord record(
  String id,
  DateTime day, {
  String type = 'attendance',
}) => PreviewAttendanceRecord(
  id: id,
  studentId: 'one',
  name: 'Siswa Uji',
  className: 'XI RPL',
  address: '-',
  description: type == 'attendance' ? 'Hadir' : 'Izin',
  datetime: '01/01/2026 07:00',
  recordedAt: day,
  type: type,
);

class TestStore implements AttendanceStore {
  bool fail = false;
  List<PreviewAttendanceRecord>? saved;
  @override
  Future<List<PreviewAttendanceRecord>?> load() async => saved;
  @override
  Future<void> save(List<PreviewAttendanceRecord> records) async {
    if (fail) throw StateError('Disk unavailable');
    saved = List.of(records);
  }
}

Future<void> chooseStudent(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('permission-student')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Siswa Uji · @one').last);
  await tester.pumpAndSettle();
}

void main() {
  late AttendanceStore originalStore;
  late TestStore store;
  setUp(() {
    originalStore = attendanceStore;
    attendanceStore = store = TestStore();
    attendanceStorageProblem = null;
    previewStudents.value = const [
      PreviewStudent('one', 'Siswa Uji', 'XI RPL'),
    ];
    previewAttendanceRecords.value = [];
  });
  tearDown(() {
    attendanceStore = originalStore;
    attendanceStorageProblem = null;
  });

  test(
    'Dates roll over across months/years; history codec keeps note and photo',
    () async {
      final r = record('old', DateTime(2026, 12, 31, 23, 59));
      expect(attendanceOnDay(r, DateTime(2026, 12, 31)), isTrue);
      expect(attendanceOnDay(r, DateTime(2027, 1, 1)), isFalse);
      final withPhoto = PreviewAttendanceRecord(
        id: 'photo',
        studentId: 'one',
        name: 'Siswa Uji',
        className: 'XI RPL',
        address: '1, 2',
        description: 'Hadir',
        datetime: '16/10/2026 07:00',
        recordedAt: DateTime(2026, 10, 16, 7),
        type: 'attendance',
        photoBytes: Uint8List.fromList([1, 2, 3]),
        note: 'Catatan asli',
      );
      final decoded = decodeAttendance(encodeAttendance([withPhoto]))!.single;
      expect(decoded.photoBytes, [1, 2, 3]);
      expect(decoded.note, 'Catatan asli');
      expect(decoded.recordedAt, withPhoto.recordedAt);
      expect(decoded.studentId, 'one');
    },
  );

  test(
    'Failed persistence does not publish a reset, next write can succeed',
    () async {
      final old = record('old', DateTime.now());
      previewAttendanceRecords.value = [old];
      store.fail = true;
      await expectLater(updateAttendance((_) => []), throwsStateError);
      expect(previewAttendanceRecords.value, [old]);
      store.fail = false;
      await updateAttendance((_) => []);
      expect(previewAttendanceRecords.value, isEmpty);
      expect(await store.load(), isEmpty);
    },
  );

  for (final status in ['Izin', 'Sakit']) {
    testWidgets(
      '$status saves student/date/note; history and home totals update; duplicate rejected',
      (tester) async {
        await tester.pumpWidget(const AttendanceApp());
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Akses admin'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('record-permission')), findsNothing);
        expect(find.byKey(const ValueKey('reset-day')), findsNothing);
        await unlock(tester);
        await tapVisible(tester, 'record-permission');
        await tapVisible(tester, 'save-permission');
        expect(find.text('Pilih pekerja terlebih dahulu.'), findsOneWidget);
        await chooseStudent(tester);
        await tester.tap(find.widgetWithText(ChoiceChip, status));
        await tester.enterText(
          find.byKey(const ValueKey('permission-note')),
          'Kontrol dokter',
        );
        await tapVisible(tester, 'save-permission');
        final saved = previewAttendanceRecords.value.single;
        expect(saved.studentId, 'one');
        expect(saved.description, status);
        expect(saved.type, 'permission');
        expect(saved.note, 'Kontrol dokter');
        expect(attendanceOnDay(saved, DateTime.now()), isTrue);
        expect(store.saved!.single, saved);
        await tapVisible(tester, 'record-permission');
        await chooseStudent(tester);
        await tapVisible(tester, 'save-permission');
        expect(find.textContaining('Tidak ada catatan ganda'), findsOneWidget);
        expect(previewAttendanceRecords.value, hasLength(1));
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Kembali ke beranda'));
        await tester.pumpAndSettle();
        expect(find.textContaining('1 pekerja izin/sakit'), findsOneWidget);
        expect(find.text('0'), findsNWidgets(2)); // hadir and pending
        await tester.tap(find.text('Riwayat'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('work-tab-1')));
        await tester.pumpAndSettle();
        expect(find.text(status), findsOneWidget);
        expect(find.text('Kontrol dokter'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Admin cannot overwrite attendance with permission; cancel creates no record',
    (tester) async {
      final attended = record('attended', DateTime.now());
      previewAttendanceRecords.value = [attended];
      await tester.pumpWidget(const MaterialApp(home: AdminScreen()));
      await tester.pumpAndSettle();
      await unlock(tester);
      await tapVisible(tester, 'record-permission');
      await chooseStudent(tester);
      await tapVisible(tester, 'save-permission');
      expect(find.textContaining('sudah tercatat hadir'), findsOneWidget);
      expect(previewAttendanceRecords.value, [attended]);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(previewAttendanceRecords.value, [attended]);
    },
  );

  testWidgets(
    '320px: reset needs confirmation, deletes only today including permissions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final now = DateTime.now();
      final yesterday = record(
        'old',
        DateTime(now.year, now.month, now.day - 1),
      );
      previewAttendanceRecords.value = [
        record('present', now),
        record('permission', now, type: 'permission'),
        yesterday,
      ];
      await tester.pumpWidget(const MaterialApp(home: AdminScreen()));
      await tester.pumpAndSettle();
      await unlock(tester);
      await tapVisible(tester, 'reset-day');
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(previewAttendanceRecords.value, hasLength(3));
      await tapVisible(tester, 'reset-day');
      await tapVisible(tester, 'confirm-reset-day');
      expect(previewAttendanceRecords.value, [yesterday]);
      expect(previewStudents.value.single.id, 'one');
      expect(store.saved, [yesterday]);
      expect(tester.takeException(), isNull);
    },
  );
}
