import '../ui/attendance_history/attendance_history_screen.dart';

// Match only untouched records seeded by the old preview. An enrolled or edited
// student is genuine data, even when its ID originally came from a sample.
bool isLegacySampleStudent(PreviewStudent student) {
  const samples = {
    'azam': 'Azam Zaim Ramadhan',
    'contoh': 'Siswa Contoh',
    'budi': 'Budi Pratama',
  };
  return samples[student.id] == student.name &&
      student.className == 'XI RPL' &&
      student.photoBytes == null &&
      student.faceDescriptor == null;
}

Future<List<PreviewStudent>?> loadCleanStudents(
  Future<List<PreviewStudent>?> Function() load,
  Future<void> Function(List<PreviewStudent>) save,
) async {
  final saved = await load();
  if (saved == null) return null;
  final clean = saved.where((s) => !isLegacySampleStudent(s)).toList();
  if (clean.length != saved.length) await save(clean);
  return clean;
}
