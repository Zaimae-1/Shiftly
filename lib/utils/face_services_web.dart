import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import '../ui/attendance_history/attendance_history_screen.dart';
import 'face_recognizer.dart';

@JS('HadirFaces.prepare')
external JSPromise<JSAny?> _prepare();
@JS('HadirFaces.extract')
external JSPromise<JSString> _extract(JSString photo);
@JS('HadirFaces.loadStudents')
external JSPromise<JSString> _loadStudents();
@JS('HadirFaces.saveStudents')
external JSPromise<JSAny?> _saveStudents(JSString data);

FaceRecognizer createFaceRecognizer() => _WebRecognizer();
StudentStore createStudentStore() => _BrowserStudentStore();

class _WebRecognizer implements FaceRecognizer {
  @override
  Future<void> prepare() async {
    try {
      await _prepare().toDart;
    } catch (_) {
      throw const FaceRecognitionException(
        'Model wajah belum berhasil dimuat. Periksa koneksi ke server aplikasi, lalu coba lagi.',
      );
    }
  }

  Future<Map<String, dynamic>> _read(Uint8List photo) async {
    await prepare();
    try {
      return jsonDecode(
            (await _extract(base64Encode(photo).toJS).toDart).toDart,
          )
          as Map<String, dynamic>;
    } catch (_) {
      throw const FaceRecognitionException(
        'Gambar belum dapat dianalisis. Coba foto yang lebih jelas.',
      );
    }
  }

  List<double> _descriptor(Map<String, dynamic> result) =>
      (result['descriptor'] as List).map((v) => (v as num).toDouble()).toList();

  @override
  Future<List<double>> enroll(Uint8List photo) async {
    final result = await _read(photo);
    switch (result['status']) {
      case 'multiple':
        throw const FaceRecognitionException(
          'Foto berisi lebih dari satu wajah. Gunakan foto satu siswa saja.',
        );
      case 'noFace':
        throw const FaceRecognitionException(
          'Wajah tidak ditemukan dalam foto. Pilih foto wajah yang jelas.',
        );
      case 'unclear':
        throw const FaceRecognitionException(
          'Wajah terlalu kecil atau kurang jelas. Gunakan foto lebih dekat dan terang.',
        );
      case 'face':
        return _descriptor(result);
      default:
        throw const FaceRecognitionException(
          'Foto belum dapat digunakan untuk pengenalan wajah.',
        );
    }
  }

  @override
  Future<FaceScanResult> scan(
    Uint8List photo,
    List<PreviewStudent> students,
  ) async {
    final result = await _read(photo);
    switch (result['status']) {
      case 'multiple':
        return const FaceScanResult(FaceScanStatus.multiple);
      case 'noFace':
        return const FaceScanResult(FaceScanStatus.noFace);
      case 'unclear':
        return const FaceScanResult(FaceScanStatus.unclear);
      case 'face':
        final student = matchFace(_descriptor(result), students);
        return FaceScanResult(
          student == null ? FaceScanStatus.unknown : FaceScanStatus.matched,
          student,
          FaceCapturePose(
            smiling: result['smiling'] == true,
            facingCamera: result['facingCamera'] == true,
          ),
        );
      default:
        return const FaceScanResult(FaceScanStatus.unknown);
    }
  }
}

class _BrowserStudentStore implements StudentStore {
  @override
  Future<List<PreviewStudent>?> load() async {
    final data = jsonDecode((await _loadStudents().toDart).toDart);
    if (data == null) return null;
    return (data as List).map((value) {
      final s = value as Map<String, dynamic>;
      return PreviewStudent(
        s['id'] as String,
        s['name'] as String,
        s['className'] as String,
        username: s['username'] as String? ?? '',
        email: s['email'] as String? ?? '',
        phone: s['phone'] as String? ?? '',
        registeredAt: DateTime.tryParse(s['registeredAt'] as String? ?? ''),
        photoBytes: s['photo'] == null
            ? null
            : base64Decode(s['photo'] as String),
        faceDescriptor: s['descriptor'] == null
            ? null
            : (s['descriptor'] as List)
                  .map((v) => (v as num).toDouble())
                  .toList(),
      );
    }).toList();
  }

  @override
  Future<void> save(List<PreviewStudent> students) async {
    await _saveStudents(
      jsonEncode([
        for (final s in students)
          {
            'id': s.id,
            'name': s.name,
            'className': s.className,
            'username': s.username,
            'email': s.email,
            'phone': s.phone,
            'registeredAt': s.registeredAt?.toIso8601String(),
            'photo': s.photoBytes == null ? null : base64Encode(s.photoBytes!),
            'descriptor': s.faceDescriptor,
          },
      ]).toJS,
    ).toDart;
  }
}
