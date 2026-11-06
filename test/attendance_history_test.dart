import 'dart:io';
import 'dart:ui' as ui;
import 'package:attendance_app/ui/attendance_history/attendance_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Uint8List photo;
  setUpAll(() async {
    const output = String.fromEnvironment('HISTORY_PREVIEW_DIR');
    if (output.isNotEmpty) {
      final font = FontLoader('Roboto')
        ..addFont(
          File(
            'C:/Windows/Fonts/segoeui.ttf',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
    final bytes = await rootBundle.load('assets/images/ic_absen.png');
    photo = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  });
  tearDown(() {
    previewAttendanceRecords.value = [];
  });

  for (final width in [320.0, 1000.0]) {
    testWidgets(
      '$width px: history uses the saved scan photo and explicit Indonesian details',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        previewAttendanceRecords.value = [
          PreviewAttendanceRecord(
            id: 'history-test',
            studentId: 'student-test',
            name: 'Siswa Uji',
            className: 'XI RPL',
            recordedAt: DateTime(2026, 10, 16, 9, 40),
            datetime:
                '01/01/2025 01:00', // canonical recordedAt takes precedence
            address: 'Lokasi sekolah',
            description: 'Hadir',
            type: 'attendance',
            photoBytes: photo,
          ),
        ];
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: boundaryKey,
              child: const AttendanceHistoryScreen(readOnly: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => precacheImage(
            MemoryImage(photo),
            tester.element(find.byType(AttendanceHistoryScreen)),
          ),
        );
        await tester.pumpAndSettle();
        for (final label in [
          'Nama:',
          'Kelas:',
          'Hari/Tanggal:',
          'Jam:',
          'Lokasi:',
          'Keterangan:',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text('Hadir'), findsOneWidget);
        expect(find.text('Siswa Uji'), findsOneWidget);
        expect(find.text('XI RPL'), findsOneWidget);
        expect(find.text('Jumat, 16 Oktober 2026'), findsOneWidget);
        expect(find.text('09:40'), findsOneWidget);
        expect(find.text('Lokasi sekolah'), findsOneWidget);
        final image = tester.widget<Image>(
          find.byKey(const ValueKey('history-photo-history-test')),
        );
        expect((image.image as MemoryImage).bytes, orderedEquals(photo));
        expect(find.byType(PopupMenuButton<String>), findsNothing);
        expect(tester.takeException(), isNull);

        // Optional local design proof, isolated from browser storage and app data.
        const output = String.fromEnvironment('HISTORY_PREVIEW_DIR');
        if (output.isNotEmpty) {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final rendered = await boundary.toImage(pixelRatio: 1);
            final png = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$output/history-${width.toInt()}.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            rendered.dispose();
          });
        }
      },
    );
  }

  testWidgets(
    'Permissions and older records remain readable without a photo; bad bytes do not crash',
    (tester) async {
      previewAttendanceRecords.value = [
        const PreviewAttendanceRecord(
          id: 'permission-test',
          name: 'Siswa Uji',
          className: 'XI RPL',
          datetime: '16/10/2026 08:10',
          type: 'permission',
          description: 'Sakit',
          note: 'Kontrol dokter',
          address: 'Dicatat oleh admin',
        ),
      ];
      await tester.pumpWidget(
        const MaterialApp(home: AttendanceHistoryScreen(readOnly: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Keterangan:'), findsOneWidget);
      expect(find.text('Sakit'), findsOneWidget);
      expect(find.text('Kontrol dokter'), findsOneWidget);
      expect(find.text('Tidak ada foto scan'), findsOneWidget);
      expect(find.text('Dicatat oleh admin'), findsOneWidget);
      expect(find.text('Tidak diperlukan (izin/sakit)'), findsOneWidget);
      expect(find.text('08:10'), findsOneWidget);
      previewAttendanceRecords.value = [
        PreviewAttendanceRecord(
          id: 'bad-photo',
          name: '',
          className: '',
          datetime: 'invalid',
          type: 'attendance',
          description: 'Hadir',
          address: '',
          photoBytes: Uint8List.fromList([1, 2, 3]),
        ),
      ];
      await tester.pumpAndSettle();
      expect(find.text('Foto tidak dapat ditampilkan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
