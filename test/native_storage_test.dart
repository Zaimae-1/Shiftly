import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:attendance_app/ui/attendance_history/attendance_history_screen.dart';
import 'package:attendance_app/utils/attendance_storage_native.dart';
import 'package:attendance_app/utils/native_local_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  NativeJsonFile file(String name) =>
      NativeJsonFile(name, directory: () async => root);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('hadir-storage-test-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
    'Student enrollment survives reopening store and atomic replacement',
    () async {
      final students = [
        PreviewStudent(
          'real',
          'Nama',
          'XI',
          photoBytes: Uint8List.fromList([1, 2, 3]),
          faceDescriptor: [1, ...List.filled(191, 0.0)],
        ),
      ];
      final store = MobileStudentStore(file: file('students.json'));
      expect(await store.load(), isNull);
      await store.save(students);
      final reopened = MobileStudentStore(file: file('students.json'));
      final loaded = (await reopened.load())!.single;
      expect(loaded.id, 'real');
      expect(loaded.name, 'Nama');
      expect(loaded.faceDescriptor, students.single.faceDescriptor);
      expect(loaded.photoBytes, [1, 2, 3]);
      await reopened.save([]);
      expect(await store.load(), isEmpty);
      expect(await File('${root.path}/students.json.tmp').exists(), isFalse);
    },
  );

  test(
    'History/photos/izin survive reopen separately from student records',
    () async {
      final records = [
        PreviewAttendanceRecord(
          id: 'r',
          studentId: 'real',
          name: 'Nama',
          className: 'XI',
          address: '-7, 111',
          description: 'Hadir',
          datetime: '20/10/2026 08:00',
          type: 'attendance',
          recordedAt: DateTime(2026, 10, 20, 8),
          photoBytes: Uint8List.fromList([4, 5]),
        ),
      ];
      final store = MobileAttendanceStore(file: file('history.json'));
      await store.save(records);
      final restored = (await MobileAttendanceStore(
        file: file('history.json'),
      ).load())!.single;
      expect(restored.studentId, 'real');
      expect(restored.photoBytes, [4, 5]);
      expect(restored.recordedAt, records.single.recordedAt);
      expect(
        await MobileStudentStore(file: file('students.json')).load(),
        isNull,
      );
    },
  );

  test(
    'Corrupt or foreign engine data is rejected without clearing existing files',
    () async {
      final original = encodeMobileStudents([
        const PreviewStudent('id', 'Nama', 'XI'),
      ]);
      final foreign = jsonDecode(original) as Map<String, dynamic>;
      foreign['engine'] = 'face-api-128-v1';
      final json = jsonEncode(foreign);
      await file('students.json').write(json);
      await expectLater(
        MobileStudentStore(file: file('students.json')).load(),
        throwsFormatException,
      );
      expect(await file('students.json').read(), json);
      await file('students.json').write('broken json');
      await expectLater(
        MobileStudentStore(file: file('students.json')).load(),
        throwsFormatException,
      );
      expect(await file('students.json').read(), 'broken json');
    },
  );

  test(
    'Saving a web descriptor cannot replace mobile enrollment data',
    () async {
      final store = MobileStudentStore(file: file('students.json'));
      await store.save([const PreviewStudent('kept', 'Nama', 'XI')]);
      await expectLater(
        store.save([
          PreviewStudent(
            'wrong',
            'Web',
            'XI',
            faceDescriptor: List.filled(128, 0.0),
          ),
        ]),
        throwsFormatException,
      );
      expect((await store.load())!.single.id, 'kept');
    },
  );
}
