import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/ui/attendance_history/attendance_history_screen.dart';

class AttendScreen extends StatefulWidget {
  const AttendScreen({super.key});

  @override
  State<AttendScreen> createState() => _AttendScreenState();
}

class _AttendScreenState extends State<AttendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _selfieReady = false;
  String strStatus = '';

  @override
  void initState() {
    super.initState();
    setStatusAbsen();
  }

  // Aturan jam presensi dari Step 11.
  void setStatusAbsen() {
    final now = DateTime.now();
    final dateHours = now.hour;
    final dateMinutes = now.minute;
    if (dateHours < 8 || (dateHours == 8 && dateMinutes <= 30)) {
      strStatus = 'Attend';
    } else if ((dateHours > 8 && dateHours < 18) ||
        (dateHours == 8 && dateMinutes >= 31)) {
      strStatus = 'Late';
    } else {
      strStatus = 'Leave';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submitPreview() {
    if (!_formKey.currentState!.validate()) return;
    if (!_selfieReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tekan simulasi selfie terlebih dahulu')),
      );
      return;
    }
    setStatusAbsen();
    final now = DateTime.now();
    previewAttendanceRecords.value = [
      PreviewAttendanceRecord(
        id: 'attendance-${now.microsecondsSinceEpoch}',
        name: _nameController.text.trim(),
        address: 'IDN Boarding School Solo · lokasi contoh',
        description: strStatus,
        datetime: DateFormat('dd/MM/yyyy HH:mm').format(now),
        type: 'attendance',
      ),
      ...previewAttendanceRecords.value,
    ];
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Presensi contoh tersimpan di riwayat lokal'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Record')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Preview UI · Simulasi kamera dan lokasi',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EFFF),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF1A008F)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _selfieReady
                            ? Icons.check_circle_outline
                            : Icons.face_outlined,
                        size: 80,
                        color: const Color(0xFF1A008F),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selfieReady
                            ? 'Selfie contoh siap'
                            : 'Pratinjau selfie',
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => setState(() => _selfieReady = true),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(
                          _selfieReady ? 'Ulangi simulasi' : 'Simulasi selfie',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama siswa',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nama wajib diisi'
                      : null,
                ),
                const SizedBox(height: 16),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.location_on_outlined),
                    title: Text('IDN Boarding School Solo'),
                    subtitle: Text(
                      'Lokasi contoh · GPS perangkat belum diakses',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Status berdasarkan jam perangkat: $strStatus'),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _submitPreview,
                  icon: const Icon(Icons.check),
                  label: const Text('Simpan presensi contoh'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Kamera, AI deteksi wajah, GPS, dan penyimpanan Firebase '
                  'belum aktif dalam preview ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* REFERENSI ASLI COURSE (Step 6, 8-11), belum terhubung ke hardware/backend.
Future<void> initializeCamera() async {
  final cameras = await availableCameras();
  final frontCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
    orElse: () => cameras.first,
  );

  controller = CameraController(
    frontCamera,
    ResolutionPreset.high,
    enableAudio: false,
    imageFormatGroup: ImageFormatGroup.jpeg,
  );

  try {
    await controller!.initialize();
    if (mounted) setState(() => isCameraReady = true);
  } catch (e) {
    debugPrint("Failed to initialize camera: $e");
  }
}

@override
void dispose() {
  controller?.dispose();
  super.dispose();
}


Future<void> processImage(InputImage inputImage, XFile imageFile) async {
  if (isBusy) return;
  isBusy = true;

  try {
    final faces = await faceDetector.processImage(inputImage);
    isBusy = false;

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Tutup loader dialog

    if (faces.isNotEmpty) {
      // Wajah asli terdeteksi -> Lanjut ke layar form konfirmasi presensi
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AttendScreen(image: imageFile),
        ),
      );
    } else {
      _showSnackBar("Wajah tidak terdeteksi! Pastikan wajah terlihat jelas di bingkai.", Icons.warning_amber_rounded);
    }
  } catch (e) {
    isBusy = false;
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _showSnackBar("Gagal memproses deteksi wajah: $e", Icons.error_outline);
    }
  }
}

DottedBorder(
  borderType: BorderType.RRect,
  radius: const Radius.circular(24),
  dashPattern: const [8, 4],
  color: Colors.blueAccent,
  strokeWidth: 2,
  child: SizedBox(
    width: 260,
    height: 340,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Lottie.asset(
          'assets/raw/face_id_ring.json',
          width: 240,
          height: 240,
          fit: BoxFit.contain,
        ),
      ],
    ),
  ),
)


Future<bool> handleLocationPermission() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    _showSnackBar("Layanan GPS tidak aktif. Silakan aktifkan GPS perangkat Anda.", Icons.location_off);
    return false;
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      _showSnackBar("Izin akses lokasi ditolak.", Icons.warning_amber_rounded);
      return false;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    _showSnackBar("Izin lokasi ditolak permanen. Buka pengaturan aplikasi untuk mengizinkan.", Icons.error_outline);
    return false;
  }

  return true;
}

Future<void> getGeoLocationPosition() async {
  final hasPermission = await handleLocationPermission();
  if (!hasPermission) return;

  setState(() => isLoading = true);
  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    dLat = position.latitude;
    dLong = position.longitude;
    await getAddressFromLongLat(position);
  } catch (e) {
    debugPrint("Error GPS: $e");
    if (mounted) {
      setState(() {
        strAlamat = "Koordinat: Lat $dLat, Long $dLong";
        isLoading = false;
      });
    }
  }
}


Future<void> getAddressFromLongLat(Position position) async {
  try {
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (placemarks.isNotEmpty && mounted) {
      final place = placemarks[0];
      setState(() {
        strAlamat = "${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}"
            .replaceAll(RegExp(r'^[,s]+|[,s]+$'), '')
            .replaceAll(RegExp(r',s*,+'), ',');
        isLoading = false;
      });
    }
  } catch (e) {
    setState(() {
      strAlamat = "Lat: ${position.latitude.toStringAsFixed(5)}, Long: ${position.longitude.toStringAsFixed(5)}";
      isLoading = false;
    });
  }
}


void setStatusAbsen() {
  final now = DateTime.now();
  final dateHours = now.hour;
  final dateMinutes = now.minute;

  if (dateHours < 8 || (dateHours == 8 && dateMinutes <= 30)) {
    strStatus = "Attend";   // Tepat waktu (sebelum / pukul 08:30)
  } else if ((dateHours > 8 && dateHours < 18) ||
      (dateHours == 8 && dateMinutes >= 31)) {
    strStatus = "Late";     // Terlambat (08:31 s/d 18:00)
  } else {
    strStatus = "Leave";    // Di luar jam operasional
  }
}

Future<void> submitAbsen(String alamat, String nama, String status) async {
  _showLoaderDialog();

  try {
    await dataCollection.add({
      'name': nama.trim(),
      'address': alamat.isEmpty ? 'Lokasi tidak terekam' : alamat,
      'description': status,
      'datetime': strDateTime,
      'latitude': dLat,
      'longitude': dLong,
      'type': 'attendance',
      'created_at': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    
    // Kembali ke HomeScreen setelah sukses
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  } catch (e) {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _showSnackBar("Gagal menyimpan presensi: $e", Icons.error_outline);
  }
}

*/
