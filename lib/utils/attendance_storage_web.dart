import 'dart:js_interop';
import '../ui/attendance_history/attendance_history_screen.dart';
import 'attendance_data.dart';

@JS('HadirFaces.loadAttendance')
external JSPromise<JSString> _load();
@JS('HadirFaces.saveAttendance')
external JSPromise<JSAny?> _save(JSString data);

AttendanceStore createAttendanceStore() => _BrowserAttendanceStore();

class _BrowserAttendanceStore implements AttendanceStore {
  @override
  Future<List<PreviewAttendanceRecord>?> load() async =>
      decodeAttendance((await _load().toDart).toDart);
  @override
  Future<void> save(List<PreviewAttendanceRecord> records) async {
    await _save(encodeAttendance(records).toJS).toDart;
  }
}
