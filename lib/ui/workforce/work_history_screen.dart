import 'package:flutter/material.dart';
import 'workforce_board.dart';

class WorkHistoryScreen extends StatelessWidget {
  const WorkHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFEEF3FA),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF9FBFF),
      foregroundColor: const Color(0xFF243653),
      title: const Text(
        'Riwayat kerja',
        style: TextStyle(
          color: Color(0xFF243653),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    body: SingleChildScrollView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 700 ? 16 : 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'CATATAN PERJALANAN KERJA',
                style: TextStyle(
                  color: Color(0xFF356CD4),
                  fontSize: 10,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Masuk, pulang, dan semua\nketerangan di antaranya.',
                style: TextStyle(
                  color: Color(0xFF243653),
                  fontWeight: FontWeight.w700,
                  fontSize: 29,
                  letterSpacing: -.8,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Pilih tanggal untuk melihat catatan. Periode Alpha tetap ada setelah pekerja kembali.',
                style: TextStyle(
                  color: Color(0xFF71809A),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              SizedBox(height: 24),
              WorkforceBoard(history: true),
            ],
          ),
        ),
      ),
    ),
  );
}
