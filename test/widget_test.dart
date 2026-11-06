import 'package:attendance_app/main.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:attendance_app/ui/home_screen.dart';
import 'package:flutter/services.dart';
import 'package:attendance_app/ui/absent/absent_screen.dart';
import 'package:attendance_app/ui/attendance_history/attendance_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/utils/face_recognizer.dart';
import 'face_test_helpers.dart';
import 'admin_test.dart' show unlock, tapVisible;

Future<void> reveal(
  WidgetTester tester,
  Finder target, {
  double delta = 250,
}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> start(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('start-scan'));
  await reveal(tester, button, delta: -250);
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<String> testLocation() async => '-7.550000, 110.800000';

Widget testApp({
  bool recognize = true,
  Future<String> Function()? locate,
  DateTime Function()? now,
}) => MaterialApp(
  home: HomeScreen(
    cameraFactory: () => _TestCamera(),
    recognizer: TestFaceRecognizer(recognize: recognize),
    locate: locate ?? testLocation,
    now: now,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final data = await rootBundle.load('assets/images/ic_absen.png');
    cameraTestPhoto = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
  });
  setUp(() {
    previewAttendanceRecords.value = [];
    previewStudents.value = const [
      PreviewStudent('azam', 'Azam Zaim Ramadhan', 'XI RPL'),
    ];
  });
  cameraTests();
  cameraPreviewTests();
  testWidgets(
    'Midnight refreshes counts and allows a new scan without deleting yesterday',
    (tester) async {
      var now = DateTime(2026, 12, 31, 23, 59, 50);
      final yesterday = PreviewAttendanceRecord(
        id: 'yesterday',
        studentId: 'azam',
        name: 'Azam Zaim Ramadhan',
        address: '-',
        description: 'Hadir',
        datetime: '31/12/2026 07:00',
        recordedAt: now,
        type: 'attendance',
      );
      previewAttendanceRecords.value = [yesterday];
      await tester.pumpWidget(testApp(now: () => now));
      await tester.pumpAndSettle();
      expect(find.text('Kamis, 31 Desember 2026'), findsOneWidget);
      now = DateTime(2027, 1, 1, 0, 0, 1);
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(find.text('Jumat, 1 Januari 2027'), findsOneWidget);
      expect(find.text('0'), findsOneWidget); // attended today
      expect(previewAttendanceRecords.value, [yesterday]);
      await start(tester);
      await reveal(tester, find.byKey(const ValueKey('confirm-attendance')));
      await tester.tap(find.byKey(const ValueKey('confirm-attendance')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(previewAttendanceRecords.value, hasLength(2));
      expect(previewAttendanceRecords.value.first.recordedAt!.year, 2027);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('Akun baru mulai kosong tanpa data atau panel demo', (
    tester,
  ) async {
    previewStudents.value = [];
    await tester.pumpWidget(const AttendanceApp());
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNWidgets(3));
    expect(find.text('Coba skenario demo'), findsNothing);
    expect(find.text('Azam Zaim Ramadhan'), findsNothing);
    expect(previewAttendanceRecords.value, isEmpty);
    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada catatan masuk'), findsOneWidget);
  });

  testWidgets('Beranda responsif dan tidak menyimpan sebelum konfirmasi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    expect(find.text('Pekerja terdaftar'), findsOneWidget);
    expect(find.text('Sedang bekerja'), findsOneWidget);
    expect(find.text('Belum absen'), findsOneWidget);
    await start(tester);
    await reveal(tester, find.byKey(const ValueKey('confirm-attendance')));
    expect(find.text('Azam Zaim Ramadhan'), findsOneWidget);
    expect(find.text('Tanggal'), findsOneWidget);
    expect(find.text('Jam'), findsOneWidget);
    expect(previewAttendanceRecords.value, isEmpty);
    await tester.tap(find.byKey(const ValueKey('confirm-attendance')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(previewAttendanceRecords.value.single.studentId, 'azam');
    expect(previewAttendanceRecords.value.single.description, 'Masuk');
    expect(previewAttendanceRecords.value.single.recordedAt, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Scan ulang dan absen ganda tidak menambah catatan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await start(tester);
    await tester.tap(find.text('Scan ulang'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(previewAttendanceRecords.value, isEmpty);
    await tester.tap(find.byKey(const ValueKey('confirm-attendance')));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    await start(tester);
    expect(find.text('Konfirmasi pulang'), findsOneWidget);
    await reveal(tester, find.byKey(const ValueKey('confirm-attendance')));
    await tester.tap(find.byKey(const ValueKey('confirm-attendance')));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(previewAttendanceRecords.value.single.checkedOutAt, isNotNull);
    await start(tester);
    expect(find.text('Masuk dan pulang sudah lengkap'), findsWidgets);
    expect(find.byKey(const ValueKey('confirm-attendance')), findsNothing);
    expect(previewAttendanceRecords.value, hasLength(1));
    await tester.tap(find.byTooltip('Akses admin'));
    await tester.pumpAndSettle();
    await unlock(tester);
    await tapVisible(tester, 'reset-day');
    await tapVisible(tester, 'confirm-reset-day');
    expect(previewAttendanceRecords.value, isEmpty);
    await tester.tap(find.byTooltip('Kembali ke beranda'));
    await tester.pumpAndSettle();
    await start(tester);
    await reveal(tester, find.byKey(const ValueKey('confirm-attendance')));
    await tester.tap(find.byKey(const ValueKey('confirm-attendance')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(previewAttendanceRecords.value, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Batas 10 detik menghentikan scan tanpa menyimpan', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(recognize: false));
    await tester.pumpAndSettle();
    await start(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Batalkan scan'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Foto tidak dikenali'), findsWidgets);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(previewAttendanceRecords.value, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Lokasi gagal mencegah scan dan konfirmasi', (tester) async {
    await tester.pumpWidget(
      testApp(locate: () async => throw Exception('Izin lokasi ditolak')),
    );
    await tester.pumpAndSettle();
    await start(tester);
    expect(find.text('Lokasi belum tersedia'), findsWidgets);
    expect(find.text('Batalkan scan'), findsNothing);
    expect(find.byKey(const ValueKey('confirm-attendance')), findsNothing);
    expect(previewAttendanceRecords.value, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Riwayat dari beranda hanya bisa dilihat', (tester) async {
    previewAttendanceRecords.value = [
      PreviewAttendanceRecord(
        id: 'sample',
        name: 'Siswa Contoh',
        address: 'Lokasi contoh',
        description: 'Hadir',
        datetime: '15/10/2026 08:00',
        type: 'attendance',
        recordedAt: DateTime.now(),
      ),
    ];
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Siswa Contoh'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Form izin yang sudah ada tetap memvalidasi input kosong', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AbsentScreen()));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Simpan izin contoh'));
    await tester.tap(find.text('Simpan izin contoh'));
    await tester.pumpAndSettle();
    expect(find.text('Wajib diisi'), findsWidgets);
    expect(previewAttendanceRecords.value, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

class _CountingRecognizer extends TestFaceRecognizer {
  int preparations = 0, scans = 0;
  _CountingRecognizer() : super(recognize: false);
  @override
  Future<void> prepare() async {
    preparations++;
  }

  @override
  Future<FaceScanResult> scan(
    Uint8List bytes,
    List<PreviewStudent> students,
  ) async {
    scans++;
    return super.scan(bytes, students);
  }
}

void cameraPreviewTests() {
  testWidgets(
    'A home initially opened in background waits until resumed to open the camera',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      final camera = _TestCamera();
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(cameraFactory: () => camera)),
      );
      await tester.pumpAndSettle();
      expect(camera.initializations, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(camera.initializations, 1);
      expect(find.text('Kamera uji aktif'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(camera.disposed, isTrue);
    },
  );
  testWidgets(
    'A blocked automatic camera can be retried without starting AI or requesting location',
    (tester) async {
      final cameras = <_TestCamera>[];
      final recognizer = _CountingRecognizer();
      var locations = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            cameraFactory: () {
              final c = _TestCamera(denied: cameras.isEmpty);
              cameras.add(c);
              return c;
            },
            recognizer: recognizer,
            locate: () async {
              locations++;
              return testLocation();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kamera belum tersedia'), findsWidgets);
      await reveal(tester, find.byKey(const ValueKey('start-scan')));
      await tester.tap(find.byKey(const ValueKey('start-scan')));
      await tester.pumpAndSettle();
      expect(cameras, hasLength(2));
      expect(cameras.first.disposed, isTrue);
      expect(find.text('Kamera uji aktif'), findsOneWidget);
      expect(find.text('Mulai scan'), findsOneWidget);
      expect(cameras.last.captures, 0);
      expect(recognizer.preparations, 0);
      expect(locations, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'Live preview opens automatically without AI/location; scan timeout keeps it running',
    (tester) async {
      final camera = _TestCamera();
      final recognizer = _CountingRecognizer();
      var locations = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            cameraFactory: () => camera,
            recognizer: recognizer,
            locate: () async {
              locations++;
              return testLocation();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kamera uji aktif'), findsOneWidget);
      expect(camera.initializations, 1);
      await tester.pump(const Duration(seconds: 30));
      expect(camera.captures, 0);
      expect(recognizer.preparations, 0);
      expect(recognizer.scans, 0);
      expect(locations, 0);
      expect(previewAttendanceRecords.value, isEmpty);
      await start(tester);
      expect(recognizer.preparations, 1);
      expect(locations, 1);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Foto tidak dikenali'), findsWidgets);
      expect(find.text('Kamera uji aktif'), findsOneWidget);
      expect(camera.initializations, 1);
      expect(camera.disposed, isFalse);
      final captures = camera.captures, scans = recognizer.scans;
      await tester.pump(const Duration(seconds: 20));
      expect(camera.captures, captures);
      expect(recognizer.scans, scans);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(camera.disposed, isTrue);
    },
  );

  testWidgets(
    'History/admin/background release preview; returning opens one fresh camera',
    (tester) async {
      final cameras = <_TestCamera>[];
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            cameraFactory: () {
              final c = _TestCamera();
              cameras.add(c);
              return c;
            },
            recognizer: _CountingRecognizer(),
            locate: testLocation,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(cameras, hasLength(1));
      await tester.tap(find.text('Riwayat'));
      await tester.pumpAndSettle();
      expect(cameras.first.disposed, isTrue);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(cameras, hasLength(2));
      expect(find.text('Kamera uji aktif'), findsOneWidget);
      await tester.tap(find.byTooltip('Akses admin'));
      await tester.pumpAndSettle();
      expect(cameras[1].disposed, isTrue);
      await tester.tap(find.byTooltip('Kembali ke beranda'));
      await tester.pumpAndSettle();
      expect(cameras, hasLength(3));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pumpAndSettle();
      expect(cameras[2].disposed, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(cameras, hasLength(4));
      expect(cameras.last.disposed, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(cameras.every((c) => c.disposed), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Leaving while preview permission is pending prevents late video; returning can retry',
    (tester) async {
      final pending = Completer<void>();
      final cameras = <_TestCamera>[];
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            cameraFactory: () {
              final camera = _TestCamera(
                opening: cameras.isEmpty ? pending : null,
              );
              cameras.add(camera);
              return camera;
            },
            recognizer: _CountingRecognizer(),
            locate: testLocation,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Riwayat'));
      await tester.pumpAndSettle();
      pending.complete();
      await tester.pumpAndSettle();
      expect(cameras, hasLength(1));
      expect(cameras.first.disposed, isTrue);
      expect(find.text('Kamera uji aktif'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(cameras, hasLength(2));
      expect(find.text('Kamera uji aktif'), findsOneWidget);
      expect(cameras.last.disposed, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

late Uint8List cameraTestPhoto;

class _TestCamera implements ScannerCamera {
  final bool denied;
  final Completer<void>? opening;
  bool initialized = false;
  bool disposed = false;
  int captures = 0, initializations = 0;
  _TestCamera({this.denied = false, this.opening});
  @override
  Future<void> initialize() async {
    initializations++;
    if (denied) throw CameraException('CameraAccessDenied', 'Test permission');
    if (opening != null) await opening!.future;
    initialized = true;
  }

  @override
  Widget buildPreview() => const ColoredBox(
    color: Colors.black,
    child: Center(child: Text('Kamera uji aktif')),
  );
  @override
  Future<Uint8List> capture() async {
    captures++;
    return cameraTestPhoto;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void cameraTests() {
  testWidgets(
    'Two failed scans expose a simulated admin call without saving attendance',
    (tester) async {
      await tester.pumpWidget(testApp(recognize: false));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await start(tester);
        await tester.pump(const Duration(seconds: 6));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Foto tidak dikenali'), findsWidgets);
        if (i == 0) {
          expect(find.byKey(const ValueKey('call-admin')), findsNothing);
        }
      }
      await reveal(tester, find.byKey(const ValueKey('call-admin')));
      await tester.tap(find.byKey(const ValueKey('call-admin')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Menghubungi admin…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Permintaan bantuan dibuat'), findsOneWidget);
      expect(previewAttendanceRecords.value, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Recognition finishing after the deadline cannot reveal an identity',
    (tester) async {
      final result = Completer<FaceScanResult>();
      final camera = _TestCamera();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locate: testLocation,
            cameraFactory: () => camera,
            recognizer: TestFaceRecognizer(pending: result.future),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.byKey(const ValueKey('start-scan')),
        delta: -250,
      );
      await tester.tap(find.byKey(const ValueKey('start-scan')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 10));
      result.complete(
        FaceScanResult(FaceScanStatus.matched, previewStudents.value.first),
      );
      await tester.pumpAndSettle();
      expect(find.text('Foto tidak dikenali'), findsWidgets);
      expect(find.byKey(const ValueKey('confirm-attendance')), findsNothing);
      expect(camera.disposed, isFalse);
      expect(previewAttendanceRecords.value, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Wajah cocok diikuti senyum stabil menangkap otomatis tanpa tombol foto',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final camera = _TestCamera();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locate: testLocation,
            cameraFactory: () => camera,
            recognizer: TestFaceRecognizer(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.byKey(const ValueKey('start-scan')),
        delta: -250,
      );
      await tester.tap(find.byKey(const ValueKey('start-scan')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(camera.initialized, isTrue);
      expect(find.text('Kamera uji aktif'), findsOneWidget);
      expect(camera.captures, 0);
      expect(find.text('Ambil foto'), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(camera.captures, 4);
      expect(camera.disposed, isFalse);
      expect(find.byType(Image), findsWidgets);
      expect(
        find.text('Wajah cocok dengan foto pekerja terdaftar'),
        findsOneWidget,
      );
      expect(previewAttendanceRecords.value, isEmpty);
      await reveal(tester, find.byKey(const ValueKey('confirm-attendance')));
      await tester.tap(find.byKey(const ValueKey('confirm-attendance')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(previewAttendanceRecords.value.single.photoBytes, cameraTestPhoto);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Matched identity waits for a frontal smile; a side pose cannot capture',
    (tester) async {
      final camera = _TestCamera();
      final recognizer = TestFaceRecognizer(
        pose: const FaceCapturePose(smiling: false, facingCamera: true),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locate: testLocation,
            cameraFactory: () => camera,
            recognizer: recognizer,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.byKey(const ValueKey('start-scan')),
        delta: -250,
      );
      await tester.tap(find.byKey(const ValueKey('start-scan')));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.byKey(const ValueKey('confirm-attendance')), findsNothing);
      expect(find.textContaining('senyum dulu ya'), findsWidgets);
      recognizer.pose = const FaceCapturePose(
        smiling: true,
        facingCamera: false,
      );
      for (var i = 0; i < 2; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.byKey(const ValueKey('confirm-attendance')), findsNothing);
      recognizer.pose = const FaceCapturePose(
        smiling: true,
        facingCamera: true,
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('confirm-attendance')), findsOneWidget);
      expect(previewAttendanceRecords.value, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Recognized face without a smile times out without saving or showing confirmation',
    (tester) async {
      final recognizer = TestFaceRecognizer(
        pose: const FaceCapturePose(smiling: false, facingCamera: true),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locate: testLocation,
            cameraFactory: () => _TestCamera(),
            recognizer: recognizer,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.byKey(const ValueKey('start-scan')),
        delta: -250,
      );
      await tester.tap(find.byKey(const ValueKey('start-scan')));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Senyumnya belum tertangkap'), findsWidgets);
      expect(find.byKey(const ValueKey('confirm-attendance')), findsNothing);
      expect(previewAttendanceRecords.value, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Izin kamera ditolak menampilkan petunjuk tanpa absensi', (
    tester,
  ) async {
    final camera = _TestCamera(denied: true);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          locate: testLocation,
          cameraFactory: () => camera,
          recognizer: TestFaceRecognizer(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('start-scan')), delta: -250);
    await tester.tap(find.byKey(const ValueKey('start-scan')));
    await tester.pumpAndSettle();
    expect(find.text('Kamera belum tersedia'), findsWidgets);
    expect(camera.disposed, isTrue);
    expect(find.text('Ambil foto'), findsNothing);
    expect(previewAttendanceRecords.value, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Wajah tidak cocok berhenti tepat 10 detik tanpa konfirmasi', (
    tester,
  ) async {
    final camera = _TestCamera();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          locate: testLocation,
          cameraFactory: () => camera,
          recognizer: TestFaceRecognizer(recognize: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('start-scan')), delta: -250);
    await tester.tap(find.byKey(const ValueKey('start-scan')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 8500));
    expect(find.text('Batalkan scan'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Foto tidak dikenali'), findsWidgets);
    expect(camera.disposed, isFalse);
    final captures = camera.captures;
    await tester.pump(const Duration(seconds: 2));
    expect(camera.captures, captures);
    expect(find.byKey(const ValueKey('confirm-attendance')), findsNothing);
    expect(previewAttendanceRecords.value, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Membatalkan izin yang masih menunggu tidak menghidupkan kamera terlambat',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final opening = Completer<void>();
      final camera = _TestCamera(opening: opening);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            locate: testLocation,
            cameraFactory: () => camera,
            recognizer: TestFaceRecognizer(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await reveal(
        tester,
        find.byKey(const ValueKey('start-scan')),
        delta: -250,
      );
      await tester.tap(find.byKey(const ValueKey('start-scan')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Batalkan buka kamera'));
      await tester.pumpAndSettle();
      opening.complete();
      await tester.pumpAndSettle();
      expect(camera.disposed, isTrue);
      expect(find.text('Mulai scan'), findsOneWidget);
      expect(find.text('Ambil foto'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
