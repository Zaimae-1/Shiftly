import 'package:attendance_app/main.dart';
import 'package:attendance_app/ui/admin/admin_screen.dart';
import 'package:attendance_app/ui/attendance_history/attendance_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'face_test_helpers.dart';

Future<void> unlock(WidgetTester tester, [String password = '123456']) async {
  await tester.enterText(
    find.byKey(const ValueKey('admin-password')),
    password,
  );
  await tester.tap(find.byKey(const ValueKey('unlock-admin')));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> fillWorkerContacts(
  WidgetTester tester, {
  String username = 'budiman',
}) async {
  await tester.enterText(
    find.byKey(const ValueKey('worker-username')),
    username,
  );
  await tester.enterText(
    find.byKey(const ValueKey('worker-email')),
    '$username@gmail.com',
  );
  await tester.enterText(
    find.byKey(const ValueKey('worker-phone')),
    '08123456789',
  );
}

void main() {
  testWidgets('Enrollment rejects an image that has no usable face', (
    tester,
  ) async {
    previewStudents.value = const [];
    final asset = await rootBundle.load('assets/images/ic_absen.png');
    final photo = asset.buffer.asUint8List(
      asset.offsetInBytes,
      asset.lengthInBytes,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AdminScreen(
          choosePhoto: () async => photo,
          recognizer: TestFaceRecognizer(
            enrollmentError: 'Wajah tidak ditemukan dalam foto.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await unlock(tester);
    await tapVisible(tester, 'add-student');
    await tester.enterText(
      find.byKey(const ValueKey('student-name')),
      'Uji Foto',
    );
    await fillWorkerContacts(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('choose-student-photo')),
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('choose-student-photo')));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    await tapVisible(tester, 'save-student');
    expect(find.text('Wajah tidak ditemukan dalam foto.'), findsOneWidget);
    expect(previewStudents.value, isEmpty);
    expect(find.byKey(const ValueKey('student-name')), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
  });
  setUp(() {
    previewStudents.value = const [
      PreviewStudent('azam', 'Azam Zaim Ramadhan', 'XI RPL'),
    ];
    previewAttendanceRecords.value = [];
  });

  testWidgets('Password gates directory and locks again after leaving admin', (
    tester,
  ) async {
    await tester.pumpWidget(const AttendanceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Akses admin'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-student')), findsNothing);
    await unlock(tester, 'wrong');
    expect(find.text('Password salah. Silakan coba lagi.'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-student')), findsNothing);
    await unlock(tester);
    expect(find.text('Azam Zaim Ramadhan'), findsOneWidget);
    await tester.tap(find.byTooltip('Kunci admin'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-student')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('admin-password')))
          .controller!
          .text,
      isEmpty,
    );
    await unlock(tester);
    await tester.tap(find.byTooltip('Kembali ke beranda'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Akses admin'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('admin-password')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-student')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Add requires photo, edit keeps ID and photo, search filters students',
    (tester) async {
      final asset = await rootBundle.load('assets/images/ic_absen.png');
      final photo = asset.buffer.asUint8List(
        asset.offsetInBytes,
        asset.lengthInBytes,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AdminScreen(
            choosePhoto: () async => photo,
            recognizer: TestFaceRecognizer(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await unlock(tester);
      await tapVisible(tester, 'add-student');
      await tapVisible(tester, 'save-student');
      expect(find.text('Nama lengkap wajib diisi.'), findsOneWidget);
      expect(
        find.text('Username 3–30 karakter: huruf, angka, titik, _ atau -.'),
        findsOneWidget,
      );
      expect(find.text('Pilih foto pekerja terlebih dahulu.'), findsOneWidget);
      expect(previewStudents.value, hasLength(1));
      await tester.enterText(
        find.byKey(const ValueKey('student-name')),
        'Budiman',
      );
      await fillWorkerContacts(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('choose-student-photo')),
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('choose-student-photo')));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      await tapVisible(tester, 'save-student');
      expect(previewStudents.value, hasLength(2));
      final added = previewStudents.value.last;
      expect(added.name, 'Budiman');
      expect(added.photoBytes, orderedEquals(photo));
      await tapVisible(tester, 'edit-${added.id}');
      await tester.enterText(
        find.byKey(const ValueKey('student-name')),
        'Budiman Putra',
      );
      await fillWorkerContacts(tester);
      await tapVisible(tester, 'save-student');
      expect(previewStudents.value.last.id, added.id);
      expect(previewStudents.value.last.name, 'Budiman Putra');
      expect(previewStudents.value.last.username, 'budiman');
      expect(previewStudents.value.last.photoBytes, orderedEquals(photo));
      await tester.enterText(
        find.byKey(const ValueKey('search-students')),
        'budiman@gmail.com',
      );
      await tester.pumpAndSettle();
      expect(find.text('Budiman Putra'), findsOneWidget);
      expect(find.text('Azam Zaim Ramadhan'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('search-students')),
        'tidak ada',
      );
      await tester.pumpAndSettle();
      expect(find.text('Pekerja tidak ditemukan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320px: delete requires exact name, cancel preserves data and history survives deletion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      const record = PreviewAttendanceRecord(
        id: 'record',
        studentId: 'azam',
        name: 'Azam Zaim Ramadhan',
        address: '-',
        description: 'Hadir',
        datetime: '15/10/2026 07:00',
        type: 'attendance',
      );
      previewAttendanceRecords.value = [record];
      await tester.pumpWidget(const MaterialApp(home: AdminScreen()));
      await tester.pumpAndSettle();
      await unlock(tester);
      await tapVisible(tester, 'delete-azam');
      var button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('confirm-delete-student')),
      );
      expect(button.onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('delete-student-name')),
        'azamwrong',
      );
      await tester.pumpAndSettle();
      button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('confirm-delete-student')),
      );
      expect(button.onPressed, isNull);
      expect(
        find.text('Username belum cocok. Periksa username di atas.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(previewStudents.value, hasLength(1));
      await tapVisible(tester, 'delete-azam');
      await tester.enterText(
        find.byKey(const ValueKey('delete-student-name')),
        '  AZAM  ',
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, 'confirm-delete-student');
      expect(previewStudents.value, isEmpty);
      expect(previewAttendanceRecords.value, [record]);
      await tapVisible(tester, 'add-student');
      await tester.enterText(
        find.byKey(const ValueKey('student-name')),
        'Siswa',
      );
      await fillWorkerContacts(tester);
      await tapVisible(tester, 'save-student');
      expect(find.text('Pilih foto pekerja terlebih dahulu.'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
