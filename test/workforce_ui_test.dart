import 'package:attendance_app/ui/home_screen.dart';
import 'package:attendance_app/ui/admin/admin_screen.dart';
import 'package:attendance_app/ui/attendance_history/attendance_history_screen.dart';
import 'package:attendance_app/ui/workforce/workforce_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'admin_test.dart' show unlock;
import 'face_test_helpers.dart';

class _Camera implements ScannerCamera {
  final Uint8List photo;
  bool disposed = false;
  _Camera(this.photo);
  @override
  Future<void> initialize() async {}
  @override
  Widget buildPreview() => const ColoredBox(color: Color(0xFF294D48));
  @override
  Future<Uint8List> capture() async => photo;
  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  late Uint8List photo;
  setUpAll(() async {
    final data = await rootBundle.load('assets/images/ic_absen.png');
    photo = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  });
  setUp(() {
    previewStudents.value = [
      PreviewStudent(
        'azam',
        'Azam Zaim',
        '',
        username: 'azam',
        email: 'azam@gmail.com',
        phone: '08123456789',
        photoBytes: photo,
      ),
    ];
    previewAttendanceRecords.value = [];
  });

  for (final width in [320.0, 1150.0]) {
    testWidgets(
      '$width px: arrival/departure, permission and Alpha interval render without overflow',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final now = DateTime(2026, 10, 25, 16);
        previewAttendanceRecords.value = [
          PreviewAttendanceRecord(
            id: 'arrival',
            studentId: 'azam',
            name: 'Azam Zaim',
            username: 'azam',
            address: 'Kantor',
            description: 'Masuk',
            datetime: '25/10/2026 03:00',
            recordedAt: DateTime(2026, 10, 25, 3),
            checkedOutAt: now,
            type: 'attendance',
            photoBytes: photo,
          ),
          PreviewAttendanceRecord(
            id: 'leave',
            name: 'Pekerja Izin',
            username: 'izin',
            address: '',
            description: 'Sakit',
            datetime: '25/10/2026 08:00',
            recordedAt: DateTime(2026, 10, 25, 8),
            note: 'Sakit gigi',
            type: 'permission',
            photoBytes: photo,
          ),
          PreviewAttendanceRecord(
            id: 'absence',
            name: 'Azam Zaim',
            username: 'azam',
            address: '',
            description: 'Alpha',
            datetime: '20/10/2026 00:00',
            recordedAt: DateTime(2026, 10, 20),
            absenceThrough: DateTime(2026, 10, 24),
            absenceEndedAt: DateTime(2026, 10, 25, 3),
            type: 'absence',
          ),
        ];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: WorkforceBoard(day: now),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('03:00'), findsOneWidget);
        expect(find.text('16:00'), findsOneWidget);
        expect(find.text('Istirahat'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'attendance card');
        await tester.tap(find.byKey(const ValueKey('work-tab-1')));
        await tester.pumpAndSettle();
        expect(find.text('Sakit gigi'), findsOneWidget);
        expect(find.text('Sakit'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'permission card');
        await tester.tap(find.byKey(const ValueKey('work-tab-2')));
        await tester.pumpAndSettle();
        expect(find.text('20/10/2026'), findsOneWidget);
        expect(find.text('Selesai'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Public chat opens verified leave form, never requests GPS, and cannot delete',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var locations = 0;
      final cameras = <_Camera>[];
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            recognizer: TestFaceRecognizer(),
            cameraFactory: () {
              final camera = _Camera(photo);
              cameras.add(camera);
              return camera;
            },
            locate: () async {
              locations++;
              return 'Kantor';
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-work-assistant')));
      await tester.pumpAndSettle();
      expect(cameras.first.disposed, isTrue);
      await tester.tap(find.widgetWithText(ActionChip, 'Saya mau izin'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('leave-username')),
        'azam',
      );
      await tester.enterText(
        find.byKey(const ValueKey('leave-reason')),
        'Sakit gigi',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('leave-verify-face')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('leave-verify-face')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Wajah cocok\nAzam Zaim'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('leave-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('leave-submit')));
      await tester.pumpAndSettle();
      expect(previewAttendanceRecords.value.single.note, 'Sakit gigi');
      expect(locations, 0);
      expect(find.text('Izin berhasil dicatat'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('assistant-input')),
        'hapus @azam',
      );
      await tester.tap(find.byKey(const ValueKey('assistant-send')));
      await tester.pumpAndSettle();
      expect(previewStudents.value, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Deleted workers keep historical Alpha without appearing as active today',
    (tester) async {
      previewStudents.value = [];
      previewAttendanceRecords.value = [
        PreviewAttendanceRecord(
          id: 'archived',
          studentId: 'deleted',
          name: 'Arsip pekerja',
          address: '',
          description: 'Alpha',
          datetime: '20/10/2026 00:00',
          recordedAt: DateTime(2026, 10, 20),
          absenceThrough: DateTime(2026, 10, 24),
          type: 'absence',
        ),
      ];
      Widget board(DateTime day) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: WorkforceBoard(day: day)),
        ),
      );
      await tester.pumpWidget(board(DateTime(2026, 10, 25)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('work-tab-2')));
      await tester.pumpAndSettle();
      expect(find.text('Arsip pekerja'), findsNothing);
      await tester.pumpWidget(board(DateTime(2026, 10, 20)));
      await tester.pumpAndSettle();
      expect(find.text('Arsip pekerja'), findsOneWidget);
      expect(find.text('Profil dihapus'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Scanner leave mode captures identity then requires a reason without GPS',
    (tester) async {
      var locations = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            recognizer: TestFaceRecognizer(),
            cameraFactory: () => _Camera(photo),
            locate: () async {
              locations++;
              return 'Kantor';
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Izin / sakit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Izin / sakit'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('start-scan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start-scan')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('confirm-attendance')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-attendance')));
      await tester.pumpAndSettle();
      expect(find.text('Isi alasan 3–500 karakter.'), findsOneWidget);
      expect(previewAttendanceRecords.value, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('scan-leave-reason')),
        'Keperluan keluarga',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('confirm-attendance')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-attendance')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(previewAttendanceRecords.value.single.type, 'permission');
      expect(locations, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    '320px: full-width chat keeps leave fields usable above keyboard with reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: HomeScreen(
            recognizer: TestFaceRecognizer(),
            cameraFactory: () => _Camera(photo),
            locate: () async => 'Kantor',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-work-assistant')));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('assistant-panel'))).width,
        320,
      );
      await tester.tap(find.widgetWithText(ActionChip, 'Saya mau izin'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('leave-username')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('leave-username')),
        'azam',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('leave-reason')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('leave-reason')),
        'Sakit gigi',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('leave-reason')))
            .controller!
            .text,
        'Sakit gigi',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    '320px: colloquial departure question and follow-up render worker data cards',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final now = DateTime.now();
      previewAttendanceRecords.value = [
        PreviewAttendanceRecord(
          id: 'finished',
          studentId: 'azam',
          name: 'Azam Zaim',
          username: 'azam',
          address: 'Kantor',
          description: 'Masuk',
          datetime: '',
          type: 'attendance',
          photoBytes: photo,
          recordedAt: DateTime(now.year, now.month, now.day, 8),
          checkedOutAt: DateTime(now.year, now.month, now.day, 17),
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            recognizer: TestFaceRecognizer(),
            cameraFactory: () => _Camera(photo),
            locate: () async => 'Kantor',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-work-assistant')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('assistant-input')),
        'kalo yg udah pulang siapa',
      );
      await tester.tap(find.byKey(const ValueKey('assistant-send')));
      await tester.pumpAndSettle();
      final panel = find.byKey(const ValueKey('assistant-panel'));
      expect(
        find.descendant(of: panel, matching: find.text('Azam Zaim')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text('@azam')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text('Pulang')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('assistant-input')),
        'kasih lihat bisa',
      );
      await tester.tap(find.byKey(const ValueKey('assistant-send')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: panel, matching: find.text('Azam Zaim')),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Admin chat gets capability only after unlock and can delete exact username',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AdminScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('open-work-assistant')), findsNothing);
      await unlock(tester);
      await tester.tap(find.byKey(const ValueKey('open-work-assistant')));
      await tester.pumpAndSettle();
      expect(find.text('Mode admin · siap membantu'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('assistant-input')),
        'hapus @azam',
      );
      await tester.tap(find.byKey(const ValueKey('assistant-send')));
      await tester.pumpAndSettle();
      expect(previewStudents.value, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
