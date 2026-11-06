import 'dart:typed_data';
import '../ui/attendance_history/attendance_history_screen.dart';
import 'attendance_data.dart';
import 'workforce_data.dart';

enum AssistantAction { none, leaveForm, newWorker, editWorker }

class WorkAssistantSummary {
  final int total, working, finished, leave, unrecorded, alpha;
  const WorkAssistantSummary({
    required this.total,
    required this.working,
    required this.finished,
    required this.leave,
    required this.unrecorded,
    required this.alpha,
  });
}

class WorkAssistantReply {
  final String text;
  final AssistantAction action;
  final PreviewStudent? worker;
  final WorkAssistantSummary? summary;
  final List<WorkAssistantPerson> people;
  const WorkAssistantReply(
    this.text, {
    this.action = AssistantAction.none,
    this.worker,
    this.summary,
    this.people = const [],
  });
}

class WorkAssistantPerson {
  final String name, username, status;
  final Uint8List? photo;
  final Map<String, String> details;
  const WorkAssistantPerson({
    required this.name,
    required this.username,
    required this.status,
    this.photo,
    required this.details,
  });
}

/// Deliberately local, finite application intents. This is not a generative
/// model, does not send messages externally, and never derives admin authority
/// from the user's text. Every admin mutation goes through the session service.
class WorkAssistant {
  final AdminSession? session;
  String? _lastDataQuery;
  WorkAssistant({this.session});
  bool get isAdmin => session?.active == true;

  Future<WorkAssistantReply> respond(String message, {DateTime? now}) async {
    final time = now ?? DateTime.now();
    var query = message.trim().toLowerCase();
    final words = query
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final followUp =
        words.isNotEmpty &&
        words.any(
          (w) => const {
            'lihat',
            'liat',
            'tampilkan',
            'tampilin',
            'tunjukkan',
            'tunjukin',
            'detail',
            'datanya',
            'siapa',
            'namanya',
            'nama',
            'nya',
            'detailnya',
          }.contains(w),
        ) &&
        words.every(
          (w) => const {
            'kasih',
            'lihat',
            'liat',
            'tampilkan',
            'tampilin',
            'tunjukkan',
            'tunjukin',
            'detail',
            'data',
            'datanya',
            'siapa',
            'nama',
            'namanya',
            'nya',
            'detailnya',
            'aja',
            'saja',
            'bisa',
            'boleh',
            'tolong',
            'dong',
            'ya',
            'aku',
            'mau',
            'yang',
            'yg',
            'tadi',
            'itu',
            'tersebut',
            'mereka',
            'orangnya',
            'pekerjanya',
            'juga',
            'iya',
            'ok',
            'oke',
            'daftar',
          }.contains(w),
        );
    if (followUp) {
      if (_lastDataQuery == null) {
        return const WorkAssistantReply(
          'Boleh! Data yang mana yang ingin kamu lihat? Misalnya “siapa yang sudah pulang”, “yang sedang bekerja”, atau “daftar pekerja”.',
        );
      }
      query = _lastDataQuery!;
    }
    final readRequest = RegExp(
      r'jumlah|berapa|siapa|data|rekap|daftar|ringkasan|lihat|liat|tampil|tunjuk|\bcek\b|\byang\b|\byg\b',
    ).hasMatch(query);
    final workers = List.of(previewStudents.value);
    if (RegExp(
      r'^(hai|halo|hello|hi|selamat pagi|pagi|siang|sore|malam)(\s+(shiftly|kak|admin))?[\s!.,]*$',
    ).hasMatch(query)) {
      return const WorkAssistantReply(
        'Hai juga! Senang bisa bantu kamu. Mau cek kabar tim, cari pekerja, atau mengajukan izin hari ini?',
      );
    }
    if (RegExp(
      r'^(makasih|terima kasih|thanks|thank you)([\s!.,].*)?$',
    ).hasMatch(query)) {
      return const WorkAssistantReply(
        'Sama-sama! Kalau ada yang perlu dicek lagi, tinggal bilang ya.',
      );
    }
    if (RegExp(r'\bhapus(?:in|kan)?\b|\bdelete\b').hasMatch(query)) {
      _lastDataQuery = null;
      if (!isAdmin) {
        return const WorkAssistantReply(
          'Untuk menjaga data tim, hapus data hanya tersedia di halaman admin ya. Kamu bisa masuk lewat tombol kunci, lalu aku bantu dari sana.',
        );
      }
      if (RegExp(
            r'\bjangan\b|\bjgn\b|\bbatal\b|tidak jadi|\bcara\b|\bbagaimana\b',
          ).hasMatch(query) ||
          !RegExp(
            r'^(?:(?:tolong|mohon|bantu|silakan|coba)\s+)*(?:hapus(?:in|kan)?|delete)\b',
          ).hasMatch(query)) {
        return const WorkAssistantReply(
          'Tidak ada data yang dihapus, tenang ya. Kalau sudah yakin, ketik hapus @username untuk memilih satu pekerja yang tepat ya.',
        );
      }
      final matches = workers
          .where(
            (w) => RegExp(
              '@${RegExp.escape(w.handle.toLowerCase())}(?:[\\s.,!?]|\$)',
            ).hasMatch(query),
          )
          .toList();
      if (matches.length != 1) {
        return const WorkAssistantReply(
          'Boleh sebutkan satu username yang ingin dihapus? Contohnya: hapus @username. Dengan begitu, data yang dipilih bisa dipastikan tepat.',
        );
      }
      final worker = matches.single;
      await deleteWorker(session!, worker, worker.handle);
      return WorkAssistantReply(
        'Sudah beres, data ${worker.name} (@${worker.handle}) sudah dihapus. Riwayat presensinya tetap tersimpan, jadi kamu masih bisa melihat catatan sebelumnya.',
      );
    }
    if (RegExp(
      r'\btambah(?:kan|in)?\b|\bdaftarkan\b|\bedit\b|\bubah\b',
    ).hasMatch(query)) {
      _lastDataQuery = null;
      if (!isAdmin) {
        return const WorkAssistantReply(
          'Aku bantu arahkan ya. Untuk menambah atau mengubah profil pekerja, masuk dulu ke halaman admin lewat tombol kunci. Setelah itu, kita bisa lanjut dari sana.',
        );
      }
      if (query.contains('edit') || query.contains('ubah')) {
        final matches = workers
            .where(
              (w) =>
                  query.contains(w.handle.toLowerCase()) ||
                  query.contains(w.name.toLowerCase()),
            )
            .toList();
        if (matches.length != 1) {
          return const WorkAssistantReply(
            'Profil siapa yang mau diperbarui? Tulis username-nya ya, misalnya: edit @username.',
          );
        }
        return WorkAssistantReply(
          'Siap, aku bukakan profil ${matches.single.name}. Periksa datanya, lalu tekan Simpan kalau sudah sesuai ya.',
          action: AssistantAction.editWorker,
          worker: matches.single,
        );
      }
      return const WorkAssistantReply(
        'Yuk, daftarkan anggota tim baru. Aku bukakan formulirnya. Lengkapi profil dan foto wajah, lalu tekan Simpan pekerja kalau sudah siap.',
        action: AssistantAction.newWorker,
      );
    }
    if (RegExp(r'\bizin\b|\bsakit\b').hasMatch(query) && !readRequest) {
      _lastDataQuery = null;
      return const WorkAssistantReply(
        'Tentu, aku bantu ya. Isi username dan alasanmu di bawah, lalu pilih Izin atau Sakit. Setelah verifikasi wajah cocok, tekan Kirim izin. Kalau sedang kurang sehat, semoga lekas membaik ya.',
        action: AssistantAction.leaveForm,
      );
    }
    if (RegExp(r'\b(scan|absen|masuk|pulang)\b').hasMatch(query) &&
        !readRequest &&
        !query.contains('cari') &&
        !query.contains('status')) {
      _lastDataQuery = null;
      return const WorkAssistantReply(
        'Bisa lewat pemindai di beranda ya. Pilih Masuk / pulang, lalu tekan Mulai scan. Scan pertama untuk masuk, scan berikutnya untuk pulang. Setelah wajah dikenali, cek datanya dan tekan Konfirmasi. Kalau keduanya sudah tercatat, presensimu aman dari catatan ganda.',
      );
    }
    await synchronizeWorkerAbsences(now: time);
    final records = previewAttendanceRecords.value;
    final today = workers
        .map((w) => (worker: w, record: dayRecord(w, records, time)))
        .toList();
    final working = today
        .where(
          (e) =>
              e.record?.type == 'attendance' && e.record?.checkedOutAt == null,
        )
        .toList();
    final finished = today
        .where(
          (e) =>
              e.record?.type == 'attendance' && e.record?.checkedOutAt != null,
        )
        .toList();
    final leave = today.where((e) => e.record?.type == 'permission').toList();
    final alpha = records
        .where(
          (r) =>
              r.type == 'absence' &&
              r.absenceEndedAt == null &&
              workers.any((w) => w.id == r.studentId),
        )
        .toList();
    final matched = workers
        .where(
          (w) =>
              query.contains(w.handle.toLowerCase()) ||
              query.contains(w.name.toLowerCase()),
        )
        .toList();
    WorkAssistantPerson person(
      PreviewStudent w,
      PreviewAttendanceRecord? r, {
      bool contacts = false,
    }) => WorkAssistantPerson(
      name: w.name,
      username: w.handle,
      photo: r?.photoBytes ?? w.photoBytes,
      status: r == null
          ? 'Belum absen'
          : r.type == 'absence'
          ? 'Alpha aktif'
          : r.type == 'permission'
          ? r.description
          : r.checkedOutAt == null
          ? 'Sedang bekerja'
          : 'Sudah pulang',
      details: {
        if (contacts && isAdmin) ...{'Gmail': w.email, 'HP': w.phone},
        if (r == null) 'Tanggal': workDate(time),
        if (r?.type == 'attendance') ...{
          'Masuk': workTimestamp(attendanceTime(r!)),
          'Pulang': workTimestamp(r.checkedOutAt),
        },
        if (r?.type == 'permission') ...{
          'Diajukan': workTimestamp(attendanceTime(r!)),
          'Alasan': r.note.isEmpty ? 'Tanpa catatan' : r.note,
        },
        if (r?.type == 'absence') 'Mulai Alpha': workDate(attendanceTime(r!)!),
      },
    );
    if (RegExp(r'alpha|alpa|alfa').hasMatch(query)) {
      _lastDataQuery = 'siapa yang alpha';
      return WorkAssistantReply(
        alpha.isEmpty
            ? 'Sudah aku cek, belum ada pekerja dengan periode Alpha aktif.'
            : 'Ada ${alpha.length} pekerja dengan periode Alpha aktif. Ini datanya ya:',
        people: [
          for (final r in alpha)
            person(workers.firstWhere((w) => w.id == r.studentId), r),
        ],
      );
    }
    if (matched.isNotEmpty && matched.length <= 8) {
      // Save only this read intent; every follow-up loads current data and role.
      _lastDataQuery = query;
      return WorkAssistantReply(
        'Ini data pekerja yang kamu cari ya:',
        people: [
          for (final w in matched)
            person(w, dayRecord(w, records, time), contacts: true),
        ],
      );
    }
    if (readRequest) {
      if (query.contains('izin') || query.contains('sakit')) {
        _lastDataQuery = 'siapa yang izin';
        return WorkAssistantReply(
          leave.isEmpty
              ? 'Sejauh ini belum ada pengajuan izin atau sakit hari ini.'
              : 'Ada ${leave.length} pekerja izin/sakit hari ini. Berikut data dan alasannya:',
          people: [for (final e in leave) person(e.worker, e.record)],
        );
      }
      if (query.contains('pulang') ||
          query.contains('istirahat') ||
          query.contains('selesai')) {
        _lastDataQuery = 'siapa yang sudah pulang';
        return WorkAssistantReply(
          finished.isEmpty
              ? 'Sejauh ini belum ada pekerja yang mencatat pulang hari ini.'
              : 'Sudah aku cek, ${finished.length} pekerja sudah pulang hari ini. Ini nama dan jam lengkapnya ya:',
          people: [for (final e in finished) person(e.worker, e.record)],
        );
      }
      if (query.contains('belum') || query.contains('tanpa keterangan')) {
        _lastDataQuery = 'siapa yang belum absen';
        final missing = today.where((e) => e.record == null).toList();
        return WorkAssistantReply(
          missing.isEmpty
              ? 'Semua pekerja sudah punya catatan presensi hari ini.'
              : 'Ada ${missing.length} pekerja yang belum punya catatan hari ini. Ini daftarnya ya:',
          people: [for (final e in missing) person(e.worker, null)],
        );
      }
      if (query.contains('sedang') ||
          query.contains('lagi') ||
          query.contains('bekerja')) {
        _lastDataQuery = 'siapa yang sedang bekerja';
        return WorkAssistantReply(
          working.isEmpty
              ? 'Sejauh ini belum ada pekerja yang tercatat sedang bekerja.'
              : 'Siap, ada ${working.length} pekerja sedang bekerja. Ini data masuknya:',
          people: [for (final e in working) person(e.worker, e.record)],
        );
      }
      _lastDataQuery = 'daftar semua pekerja';
      final showPeople = RegExp(
        r'daftar|siapa|lihat|liat|tampil|tunjuk',
      ).hasMatch(query);
      return WorkAssistantReply(
        workers.isEmpty
            ? 'Sudah aku cek, saat ini ada 0 pekerja terdaftar. Kamu bisa menambahkan profil pertama lewat halaman admin.'
            : showPeople
            ? 'Tentu, ini daftar ${workers.length} pekerja beserta statusnya hari ini:'
            : 'Siap, aku bantu cek ya. Ada ${workers.length} pekerja terdaftar. Ini ringkasan tim kamu hari ini.',
        people: showPeople
            ? [for (final e in today) person(e.worker, e.record)]
            : const [],
        summary: showPeople
            ? null
            : WorkAssistantSummary(
                total: workers.length,
                working: working.length,
                finished: finished.length,
                leave: leave.length,
                unrecorded: today.where((e) => e.record == null).length,
                alpha: alpha.length,
              ),
      );
    }
    if (query.contains('cari') || query.contains('siapa')) {
      _lastDataQuery = null;
      return const WorkAssistantReply(
        'Mau cari siapa? Tulis nama lengkap atau @username-nya ya, misalnya: cari @azam. Aku bantu cek profil dan presensinya hari ini.',
      );
    }
    _lastDataQuery = null;
    return WorkAssistantReply(
      'Aku bisa bantu urusan presensi di Shiftly. Kamu bisa tanya “Berapa yang bekerja?”, cari nama pekerja, atau bilang “Saya mau izin”.${isAdmin ? ' Karena kamu sudah masuk sebagai admin, aku juga bisa bantu menambah, mengedit, atau menghapus profil dengan perintah hapus @username.' : ' Untuk mengubah profil tim, kamu bisa masuk lewat tombol kunci admin ya.'} Mau mulai dari yang mana?',
    );
  }
}
