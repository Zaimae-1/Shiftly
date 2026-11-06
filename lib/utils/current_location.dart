import 'dart:async';
import 'package:geolocator/geolocator.dart';

class AttendanceLocationException implements Exception {
  final String message;
  const AttendanceLocationException(this.message);
}

Future<String> readAttendanceLocation() async {
  try {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
  } on PermissionDeniedException {
    throw const AttendanceLocationException(
      'Izinkan akses lokasi pada browser agar presensi dapat mencatat posisi perangkat.',
    );
  } on LocationServiceDisabledException {
    throw const AttendanceLocationException(
      'Layanan lokasi perangkat belum aktif. Aktifkan lokasi, lalu coba lagi.',
    );
  } on TimeoutException {
    throw const AttendanceLocationException(
      'Lokasi belum merespons. Periksa layanan lokasi dan koneksi, lalu coba lagi.',
    );
  } catch (_) {
    throw const AttendanceLocationException(
      'Lokasi belum dapat diambil. Gunakan HTTPS atau localhost dan periksa izin lokasi.',
    );
  }
}
