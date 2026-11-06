import '../ui/attendance_history/attendance_history_screen.dart';
import 'attendance_data.dart';

AttendanceStore createAttendanceStore() => _MemoryAttendanceStore();

class _MemoryAttendanceStore implements AttendanceStore {
  List<PreviewAttendanceRecord>? _records;
  @override
  Future<List<PreviewAttendanceRecord>?> load() async => _records;
  @override
  Future<void> save(List<PreviewAttendanceRecord> records) async {
    _records = List.of(records);
  }
}
