import 'dart:typed_data';
import 'package:attendance_app/ui/attendance_history/attendance_history_screen.dart';
import 'package:attendance_app/utils/student_data_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Hapus hanya seed lama; pertahankan siswa dengan foto, wajah, atau hasil edit',
    () async {
      final saved = [
        const PreviewStudent('azam', 'Azam Zaim Ramadhan', 'XI RPL'),
        const PreviewStudent('contoh', 'Siswa Contoh', 'XI RPL'),
        const PreviewStudent('budi', 'Budi Pratama', 'XI RPL'),
        PreviewStudent(
          'azam',
          'Azam Zaim Ramadhan',
          'XI RPL',
          photoBytes: Uint8List.fromList([1, 2]),
        ),
        PreviewStudent(
          'budi',
          'Budi Pratama',
          'XI RPL',
          faceDescriptor: List.filled(128, .1),
        ),
        const PreviewStudent('contoh', 'Nama Diperbarui', 'XI RPL'),
        const PreviewStudent('student-1', 'Siswa Asli', 'XI TKJ'),
      ];
      List<PreviewStudent>? written;
      final clean = await loadCleanStudents(
        () async => saved,
        (students) async => written = students,
      );
      expect(clean, saved.skip(3));
      expect(written, clean);
    },
  );
  test('Database kosong dan data asli tidak ditulis ulang', () async {
    var writes = 0;
    expect(
      await loadCleanStudents(() async => null, (_) async => writes++),
      isNull,
    );
    final real = [const PreviewStudent('student-1', 'Nama Siswa', 'X RPL')];
    expect(
      await loadCleanStudents(() async => real, (_) async => writes++),
      real,
    );
    expect(writes, 0);
  });
}
