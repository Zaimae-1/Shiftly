import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:attendance_app/ui/home_screen.dart';
import 'ui/attendance_history/attendance_history_screen.dart';
import 'utils/face_services.dart';
import 'utils/student_data_cleanup.dart';
import 'utils/attendance_data.dart';
import 'utils/workforce_data.dart';

// Preview UI lokal. Aktifkan backend setelah integrasi Firebase dikerjakan.
const bool previewMode = true;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final savedStudents = await loadCleanStudents(
      studentStore.load,
      studentStore.save,
    );
    if (savedStudents != null) previewStudents.value = savedStudents;
  } catch (error) {
    studentStorageProblem =
        'Data pekerja lokal belum dapat dibaca. Muat ulang halaman sebelum mengubah data.';
    debugPrint('Data pekerja lokal belum dapat dibaca: $error');
  }
  try {
    final records = await attendanceStore.load();
    if (records != null) previewAttendanceRecords.value = records;
  } catch (error) {
    attendanceStorageProblem =
        'Riwayat lokal belum dapat dibaca. Muat ulang sebelum mencatat presensi.';
    debugPrint('Riwayat lokal belum dapat dibaca: $error');
  }
  try {
    await migrateWorkerProfiles(DateTime.now());
    await synchronizeWorkerAbsences();
  } catch (error) {
    debugPrint('Profil pekerja / rekap Alpha belum diperbarui: $error');
  }
  if (!previewMode) {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyDauGqKgEV6Q2yJMjFbaCbUNDk5FjGb0hc',
          appId: '1:113228359740:android:c9363c7bec701353b93b39',
          messagingSenderId: '113228359740',
          projectId: 'idn-attendance-app-6ceac',
        ),
      );
      debugPrint("Firebase connected successfully!");
    } catch (e) {
      debugPrint("Firebase connection failed: $e");
    }
  }
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shiftly — Team Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF356CD4),
          primary: const Color(0xFF356CD4),
          surface: const Color(0xFFF9FBFF),
        ),
        scaffoldBackgroundColor: const Color(0xFFEEF3FA),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF2F5F9),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          labelStyle: const TextStyle(color: Color(0xFF71809A), fontSize: 13),
          hintStyle: const TextStyle(color: Color(0xFF6083B3), fontSize: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFCCD6E5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFCCD6E5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF356CD4), width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            side: const BorderSide(color: Color(0xFFC1CDDF)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Color(0xFF356CD4),
          foregroundColor: Colors.white,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
