# Shiftly — Team Attendance

Aplikasi Flutter untuk presensi masuk/pulang, izin/sakit dengan verifikasi wajah,
rekap pekerja dan periode Alpha. Beranda terbuka untuk pengunjung; halaman admin
terkunci dengan sandi demo **123456**.

## Menjalankan

Dari folder `attendance_app`:

```powershell
flutter run -d chrome --web-port 58124
```

Gunakan origin dan profil browser yang sama agar data lokal tetap terbaca.
`localhost` dan `127.0.0.1`, port berbeda, profil berbeda, serta APK adalah tempat
penyimpanan yang terpisah. Demo ini tidak memakai Firebase atau layanan AI.
Izin yang dibuat pada HP lain **belum tersinkron ke komputer kantor**.
Untuk kamera browser HP gunakan HTTPS; HTTP alamat LAN biasa tidak cukup.

```powershell
flutter build web
flutter build apk --debug
```

APK uji: `build/app/outputs/flutter-apk/app-debug.apk`, Android 8 / API 26+.
Build iOS memerlukan Mac/Xcode dan iOS 15.5+; belum diverifikasi dari Windows.

## Alur pekerja

- Kamera preview hidup selama beranda aktif. Pengenalan baru berjalan setelah
  **Mulai scan**, maksimal 10 detik. Setelah dua kecocokan identitas berurutan,
  aplikasi meminta senyum dan wajah menghadap kamera. Foto untuk konfirmasi
  diambil hanya setelah pose tersebut cocok pada dua frame berikutnya. Jika
  senyum/pose belum pas sampai batas waktu, tidak ada foto presensi yang disimpan.
- Menu **Masuk / pulang**: scan pertama pada tanggal lokal tersebut menyiapkan
  masuk, scan kedua menyiapkan pulang. Card konfirmasi menyebut tindakannya;
  belum ada penyimpanan sebelum tombol konfirmasi ditekan.
- Masuk dan pulang memperbarui **satu catatan**, masing-masing dengan timestamp
  lengkap, foto dan lokasi sendiri. Sebelum pulang, kolom jam pulang kosong.
  Kondisi berubah dari **Sedang bekerja** menjadi **Istirahat**.
- Scan ketiga pada hari yang sama ditolak setelah masuk/pulang lengkap. Hari
  kalender berikutnya dapat mencatat masuk baru. Ini model harian 00.00–23.59
  menurut perangkat, belum mencakup penjadwalan shift lintas tengah malam.
- Rekap **Masuk / Izin / Alpha** tersedia pada dashboard dan Riwayat kerja.
  Ada pencarian nama/username, pilihan tanggal, serta detail foto dan lokasi
  saat catatan diketuk. Pengunjung hanya membaca rekap.
- Preview dilepas ketika berpindah halaman, membuka chat, atau aplikasi tidak
  aktif; dibuka lagi ketika kembali ke beranda.

## Izin dan sakit

Ada dua jalur dengan pencocokan wajah sungguhan yang sama:

1. Pilih **Izin / sakit** pada scanner, scan wajah, lalu isi jenis dan alasan.
2. Buka tombol chat mengambang, pilih **Saya mau izin**, isi username, jenis
   dan alasan, kemudian buka kamera untuk verifikasi wajah.

Username harus terdaftar dan hasil pengenalan terhadap seluruh direktori harus
cocok dengan identitas itu. Hasil ambigu/tidak dikenali/beberapa wajah ditolak.
Pengajuan memerlukan alasan 3–500 karakter, bukti wajah berumur maksimal lima
menit, dan belum ada catatan lain pada hari tersebut. Izin tidak meminta GPS.
Foto verifikasi dan alasan disimpan bersama catatan; pendaftaran wajah tidak
pernah dilakukan lewat formulir izin. Pengajuan tidak mengirim email/pesan.
Admin tetap dapat mencatat izin/sakit manual dari panel khusus admin.

## Periode Alpha

Alpha dibuat hanya untuk hari kalender yang sudah berakhir tanpa masuk atau
izin, sejak tanggal pekerja mulai tercatat. Hari ini yang belum selesai tidak
langsung dianggap Alpha. Hari-hari kosong berurutan digabung menjadi satu
periode dan diperbarui pada startup, pergantian hari, dan saat aplikasi aktif.

Contoh: tidak ada keterangan tanggal 20–24, lalu scan masuk/izin tanggal 25:

- Mulai Alpha: tanggal 20.
- Selesai Alpha: waktu kembali pada tanggal 25.
- Periode lama tetap tersimpan; tanggal 25 mendapat catatan masuk/izin sendiri.
- Jika tidak hadir lagi sesudah itu, dibuat periode Alpha baru.

Hari libur belum dibedakan: aturan demo memakai setiap hari kalender.
Admin **Reset hari ini** menghapus catatan masuk/pulang/izin hari ini setelah
konfirmasi agar dapat diuji ulang. Data pekerja dan riwayat tanggal lain dijaga;
periode Alpha yang berkaitan direkonsiliasi kembali.

## Admin dan asisten lokal

Profil pekerja berisi nama lengkap, username unik (3–30 karakter), alamat
berakhiran `@gmail.com`, nomor HP 8–15 digit (opsional awalan `+`) dan foto.
Email/nomor ini divalidasi formatnya, tidak diverifikasi atau dihubungi.
Foto pendaftaran dapat di-upload (maksimal 5 MB) atau diambil lewat kamera.
Foto wajib satu wajah yang jelas dan tidak boleh menduplikasi pekerja lain.
Profil dapat diedit; ID pekerja tetap stabil agar riwayat tidak terputus.

Hapus lewat direktori harus mengetik username yang sama. Riwayat sebelumnya
bertahan. Data pekerja dipublikasikan setelah penyimpanan berhasil.

Asisten adalah pemroses maksud lokal yang mengambil data aktual, bukan layanan
percakapan generatif. Contoh pertanyaan/perintah:

- `Jumlah pekerja`, `Berapa yang sedang bekerja?`, `Jumlah Alpha`.
- `Jumlah izin`, `Cari @username`, atau nama lengkap pekerja.
- `Saya mau izin`, atau tanya cara scan masuk/pulang.
- Khusus admin: `tambah pekerja` / `edit @username` membuka formulir profil.
- Khusus admin: `hapus @username` langsung menghapus satu pekerja; username
  eksplisit dalam perintah menjadi konfirmasi. Pertanyaan cara menghapus,
  perintah negatif seperti "jangan hapus", serta nama ambigu tidak dijalankan.

Sesi admin hanya berlaku pada halaman admin yang sudah dibuka dengan sandi.
Keluar atau mengunci halaman mencabut sesi. Mengaku admin di dalam pesan tidak
memberi hak tambahan. Chat publik tidak bisa menambah/mengedit/menghapus profil.
Sandi ini gerbang UI untuk demo lokal, bukan autentikasi backend produksi.

## Data dan pengenalan wajah

- Web (termasuk browser HP): **face-api.js 0.22.2**, descriptor 128-D, threshold
  0.48 dan margin 0.08. Runtime/model tetap dibundel lokal di `web/vendor/face-api`.
- Android/iOS native: **MobileFaceNet TFLite**, descriptor 192-D, ML Kit untuk
  deteksi, landmark, serta klasifikasi senyum/mata terbuka. Orientasi EXIF dibetulkan, wajah diselaraskan ke 112px,
  RGB `(channel-128)/128`, inferensi isolate, dan normalisasi L2. Threshold awal
  0.65 dan margin 0.10 harus diuji pada kondisi penggunaan nyata.
- Model web dan mobile dipisahkan; ukuran layar tidak mengubah backend web.
  Model bukan pemeriksaan liveness. Sumber/lisensi/hash ada di
  `assets/models/README.md` dan `web/vendor/face-api/README.md`.
- Browser memakai IndexedDB; APK memakai penggantian file privat aplikasi
  secara atomik. Foto/profil/riwayat bertahan setelah ditutup pada perangkat
  yang sama. Kegagalan tulis tidak dianggap sebagai penyimpanan berhasil.
- Data siswa lama dimigrasikan tanpa menghapus foto/ID/descriptor/riwayat asli.
  Username awal dibuat unik dari nama dan awal pelacakan Alpha dimulai dari
  hari migrasi, sehingga tidak mengarang Alpha untuk masa lalu. Lengkapi Gmail
  dan nomor HP lewat edit admin. Nama kelas lama dipertahankan sebagai field
  kompatibilitas internal, tidak diminta pada UI pekerja.
- Nama tipe/berkas internal `PreviewStudent` dan beberapa key `student-*`
  sengaja tetap untuk kompatibilitas penyimpanan dan pengujian.
- Animasi scanner tetap memakai `assets/raw/face_id_ring.json` custom pengguna.

## Pemeriksaan

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
flutter build apk --debug --no-pub
```

Tes meliputi masuk/pulang tanpa duplikasi, persistensi dan codec, Alpha berurutan
serta penutupan periode, izin dengan identitas salah/kedaluwarsa, batas akses
chat admin/pengunjung, dan rekap pada lebar 320px serta desktop. Fixture tes
terisolasi dan tidak ditambahkan ke data aplikasi.

## Tampilan dan pose foto

Tema Shiftly memakai biru muda, logo tas kerja dengan centang, kartu riwayat
responsif, serta notifikasi yang dapat ditutup. Asisten lokal memakai bahasa
Indonesia yang lebih ramah dan menampilkan ringkasan angka dari data aktual.
Hover, efek tekan, dan transisi mengikuti pengaturan pengurangan animasi sistem.

Scanner beranda memeriksa ekspresi senyum (ambang 0.7), mata terbuka dan arah
kepala sebelum menyajikan foto konfirmasi. Web memakai model ekspresi face-api
beserta perkiraan posisi dari landmark; native memakai klasifikasi ML Kit dan
sudut kepala. Pemeriksaan ini membantu komposisi foto, bukan pelacakan arah
pandangan mata, bukan jaminan anti-spoofing. Pose yang tidak terbaca ditolak.
Pendaftaran/upload foto dan verifikasi izin lewat dialog chat tetap memakai alur
foto yang sudah ada. Proses ekspresi dan pengenalan tetap berjalan lokal.

Deteksi pose perlu dicoba pada pencahayaan dan kamera perangkat pengguna.
