import 'dart:io';
import '../ui/attendance_history/attendance_history_screen.dart';
import 'attendance_data.dart';
import 'attendance_storage_stub.dart' as desktop;
import 'native_local_data.dart';

AttendanceStore createAttendanceStore() => Platform.isAndroid || Platform.isIOS
    ? MobileAttendanceStore()
    : desktop.createAttendanceStore();

class MobileAttendanceStore implements AttendanceStore {
  final NativeJsonFile file;
  MobileAttendanceStore({NativeJsonFile? file})
    : file = file ?? NativeJsonFile('attendance-v1.json');
  @override
  Future<List<PreviewAttendanceRecord>?> load() async {
    final json = await file.read();
    return json == null ? null : decodeAttendance(json);
  }

  @override
  Future<void> save(List<PreviewAttendanceRecord> records) =>
      file.write(encodeAttendance(records));
}
