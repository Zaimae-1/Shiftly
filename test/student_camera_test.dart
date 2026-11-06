import 'dart:async';
import 'package:attendance_app/ui/admin/admin_screen.dart';
import 'package:attendance_app/ui/admin/student_camera_dialog.dart';
import 'package:attendance_app/ui/attendance_history/attendance_history_screen.dart';
import 'package:attendance_app/utils/scanner_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'face_test_helpers.dart';
import 'admin_test.dart' show fillWorkerContacts;

class _Camera implements ScannerCamera {
  final Uint8List photo;
  final Completer<void>? opening;
  bool disposed = false;
  int captures = 0;
  _Camera(this.photo, {this.opening});
  @override
  Future<void> initialize() async {
    if (opening != null) await opening!.future;
  }

  @override
  Widget buildPreview() => const ColoredBox(
    color: Colors.black,
    child: Center(child: Text('Preview kamera pendaftaran')),
  );
  @override
  Future<Uint8List> capture() async {
    captures++;
    return photo;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List photo;
  setUpAll(() async {
    final data = await rootBundle.load('assets/images/ic_absen.png');
    photo = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  });
  setUp(() {
    previewStudents.value = [];
    previewAttendanceRecords.value = [];
  });

  testWidgets(
    'Admin dapat scan langsung; foto diambil otomatis dan belum tersimpan sebelum Simpan',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final camera = _Camera(photo);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminScreen(
            recognizer: TestFaceRecognizer(),
            cameraFactory: () => camera,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('admin-password')),
        '123456',
      );
      await tester.tap(find.byKey(const ValueKey('unlock-admin')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('add-student')));
      await tester.tap(find.byKey(const ValueKey('add-student')));
      await tester.pumpAndSettle();
      expect(find.text('Upload foto'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('scan-student-photo')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(camera.disposed, isTrue);
      expect(camera.captures, 1);
      expect(find.byType(StudentCameraDialog), findsNothing);
      expect(find.text('Ganti file foto'), findsOneWidget);
      expect(previewStudents.value, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('student-name')),
        'Siswa Kamera',
      );
      await fillWorkerContacts(tester, username: 'kamera');
      await tester.ensureVisible(find.byKey(const ValueKey('save-student')));
      await tester.tap(find.byKey(const ValueKey('save-student')));
      await tester.pumpAndSettle();
      expect(previewStudents.value.single.photoBytes, photo);
      expect(previewStudents.value.single.faceDescriptor, hasLength(128));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pembatalan saat kamera membuka tidak mengembalikan foto terlambat',
    (tester) async {
      final opening = Completer<void>();
      final camera = _Camera(photo, opening: opening);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<Uint8List>(
                  context: context,
                  builder: (_) => StudentCameraDialog(
                    recognizer: TestFaceRecognizer(),
                    cameraFactory: () => camera,
                  ),
                ),
                child: const Text('Buka scan'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Buka scan'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('close-student-camera')));
      await tester.pumpAndSettle();
      opening.complete();
      await tester.pumpAndSettle();
      expect(camera.disposed, isTrue);
      expect(camera.captures, 0);
      expect(find.byType(StudentCameraDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Tanpa wajah jelas, kamera pendaftaran berhenti 10 detik dan bisa diulang',
    (tester) async {
      final camera = _Camera(photo);
      await tester.pumpWidget(
        MaterialApp(
          home: StudentCameraDialog(
            recognizer: TestFaceRecognizer(
              enrollmentError: 'Wajah belum jelas.',
            ),
            cameraFactory: () => camera,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(camera.disposed, isTrue);
      expect(
        find.byKey(const ValueKey('retry-student-camera')),
        findsOneWidget,
      );
      expect(previewStudents.value, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
