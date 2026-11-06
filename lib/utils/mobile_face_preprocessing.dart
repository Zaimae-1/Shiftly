import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

// This export expects float32 RGB (channel - 128) / 128, not [0, 1].
const mobileFaceInputSize = 112;
const mobileFaceTemplate = <math.Point<double>>[
  math.Point(38.2946, 51.6963),
  math.Point(73.5318, 51.5014),
  math.Point(56.0252, 71.7366),
  math.Point(41.5493, 92.3655),
  math.Point(70.7299, 92.2041),
];

img.Image _decode(Uint8List bytes) {
  try {
    final image = img.decodeImage(bytes);
    if (image != null) return image;
  } catch (_) {
    // Some image decoders throw RangeError for truncated input.
  }
  throw const FormatException('Foto tidak dapat dibaca.');
}

/// Decode camera/upload EXIF orientation once, then detect and sample the same
/// upright pixels. Bounds CPU/memory work during each scan.
Uint8List prepareMobilePhoto(Uint8List bytes) {
  final decoded = _decode(bytes);
  var upright = img.bakeOrientation(decoded);
  final longest = math.max(upright.width, upright.height);
  if (longest > 960) {
    upright = img.copyResize(
      upright,
      width: (upright.width * 960 / longest).round(),
      height: (upright.height * 960 / longest).round(),
      interpolation: img.Interpolation.linear,
    );
  }
  return Uint8List.fromList(img.encodeJpg(upright, quality: 95));
}

/// Least-squares similarity alignment (rotation, scale, translation) to the
/// five-point 112px face template. Points are image-left eye, image-right eye,
/// nose, image-left mouth and image-right mouth, regardless of mirror preview.
Float32List mobileFaceInput((Uint8List, List<math.Point<double>>) request) {
  final (bytes, points) = request;
  if (points.length != 5 || points.any((p) => !p.x.isFinite || !p.y.isFinite)) {
    throw const FormatException('Titik wajah tidak lengkap.');
  }
  final image = _decode(bytes);
  var sx = 0.0, sy = 0.0, dx = 0.0, dy = 0.0;
  for (var i = 0; i < 5; i++) {
    sx += points[i].x / 5;
    sy += points[i].y / 5;
    dx += mobileFaceTemplate[i].x / 5;
    dy += mobileFaceTemplate[i].y / 5;
  }
  var denominator = 0.0, real = 0.0, imaginary = 0.0;
  for (var i = 0; i < 5; i++) {
    final x = points[i].x - sx, y = points[i].y - sy;
    final u = mobileFaceTemplate[i].x - dx, v = mobileFaceTemplate[i].y - dy;
    denominator += x * x + y * y;
    real += x * u + y * v;
    imaginary += x * v - y * u;
  }
  if (denominator < 1e-6) {
    throw const FormatException('Posisi wajah tidak valid.');
  }
  final a = real / denominator, b = imaginary / denominator;
  final scale = a * a + b * b;
  if (scale < 1e-10) throw const FormatException('Posisi wajah tidak valid.');
  final tx = dx - a * sx + b * sy, ty = dy - b * sx - a * sy;
  final input = Float32List(112 * 112 * 3);
  var index = 0;
  for (var y = 0; y < 112; y++) {
    for (var x = 0; x < 112; x++) {
      final u = x - tx, v = y - ty;
      final px = (a * u + b * v) / scale, py = (-b * u + a * v) / scale;
      // Neutral padding outside the image; do not stretch edge pixels.
      if (px < 0 || py < 0 || px > image.width - 1 || py > image.height - 1) {
        index += 3;
        continue;
      }
      final pixel = image.getPixelInterpolate(
        px,
        py,
        interpolation: img.Interpolation.linear,
      );
      input[index++] = (pixel.r - 128) / 128;
      input[index++] = (pixel.g - 128) / 128;
      input[index++] = (pixel.b - 128) / 128;
    }
  }
  return input;
}

List<double> normalizeMobileEmbedding(List<double> output) {
  if (output.length != 192 || output.any((v) => !v.isFinite)) {
    throw const FormatException('Output model wajah tidak valid.');
  }
  final norm = math.sqrt(output.fold<double>(0, (sum, v) => sum + v * v));
  if (norm < 1e-10) throw const FormatException('Ciri wajah kosong.');
  return output.map((v) => v / norm).toList(growable: false);
}
