import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../ui/attendance_history/attendance_history_screen.dart';
import 'face_recognizer.dart';

/// Atomic replacement on Android/iOS: do not delete the previous file before
/// writing. Failed writes leave the committed data intact. No browser DB access.
class NativeJsonFile {
  final String name;
  final Future<Directory> Function() directory;
  Future<void>? _pending;
  NativeJsonFile(this.name, {Future<Directory> Function()? directory})
    : directory = directory ?? getApplicationSupportDirectory;

  Future<File> _file() async {
    final root = await directory();
    await root.create(recursive: true);
    return File('${root.path}/$name');
  }

  Future<String?> read() async {
    await _pending;
    final file = await _file();
    return await file.exists() ? file.readAsString() : null;
  }

  Future<void> write(String json) {
    Future<void> perform() async {
      final target = await _file();
      final staging = File('${target.path}.tmp');
      try {
        await staging.writeAsString(json, flush: true);
        await staging.rename(target.path);
      } finally {
        if (await staging.exists()) await staging.delete();
      }
    }

    final operation = (_pending ?? Future<void>.value()).then((_) => perform());
    final tail = operation.then<void>(
      (_) {},
      onError: (Object e, StackTrace s) {},
    );
    _pending = tail;
    tail.then((_) {
      if (identical(_pending, tail)) _pending = null;
    });
    return operation;
  }
}

String encodeMobileStudents(List<PreviewStudent> students) => jsonEncode({
  'version': 1,
  'engine': mobileFaceProfile.id,
  'students': [
    for (final s in students)
      {
        'id': s.id,
        'name': s.name,
        'className': s.className,
        'username': s.username,
        'email': s.email,
        'phone': s.phone,
        'registeredAt': s.registeredAt?.toIso8601String(),
        'photo': s.photoBytes == null ? null : base64Encode(s.photoBytes!),
        'descriptor': s.faceDescriptor,
      },
  ],
});

List<PreviewStudent> decodeMobileStudents(String json) {
  final data = jsonDecode(json) as Map<String, dynamic>;
  if (data['version'] != 1 || data['engine'] != mobileFaceProfile.id) {
    throw const FormatException(
      'Versi model data siswa berbeda. Data tidak diubah.',
    );
  }
  return (data['students'] as List).map((value) {
    final s = value as Map<String, dynamic>;
    final descriptor = (s['descriptor'] as List?)
        ?.map((v) => (v as num).toDouble())
        .toList();
    if (descriptor != null &&
        (descriptor.length != 192 ||
            descriptor.any((v) => !v.isFinite) ||
            descriptor.every((v) => v == 0))) {
      throw const FormatException('Data ciri wajah siswa tidak valid.');
    }
    return PreviewStudent(
      s['id'] as String,
      s['name'] as String,
      s['className'] as String,
      username: s['username'] as String? ?? '',
      email: s['email'] as String? ?? '',
      phone: s['phone'] as String? ?? '',
      registeredAt: DateTime.tryParse(s['registeredAt'] as String? ?? ''),
      photoBytes: s['photo'] == null
          ? null
          : base64Decode(s['photo'] as String),
      faceDescriptor: descriptor,
    );
  }).toList();
}

class MobileStudentStore implements StudentStore {
  final NativeJsonFile file;
  MobileStudentStore({NativeJsonFile? file})
    : file = file ?? NativeJsonFile('students-mobilefacenet-v1.json');
  @override
  Future<List<PreviewStudent>?> load() async {
    final json = await file.read();
    return json == null ? null : decodeMobileStudents(json);
  }

  @override
  Future<void> save(List<PreviewStudent> students) async {
    final encoded = encodeMobileStudents(students);
    // Validate before replacing the committed file; a web descriptor must not
    // be written into a MobileFaceNet database and break the next app launch.
    decodeMobileStudents(encoded);
    await file.write(encoded);
  }
}
