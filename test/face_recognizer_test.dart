import 'package:attendance_app/utils/face_recognizer.dart';
import 'package:attendance_app/ui/attendance_history/attendance_history_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<double> descriptor(double first) => [first, ...List.filled(127, 0.0)];
  test(
    'Accepts a close descriptor and rejects unknown or invalid descriptors',
    () {
      final a = PreviewStudent('a', 'A', 'XI', faceDescriptor: descriptor(0));
      expect(matchFace(descriptor(.2), [a]), same(a));
      expect(matchFace(descriptor(.6), [a]), isNull);
      expect(matchFace([double.nan, ...List.filled(127, 0)], [a]), isNull);
      expect(matchFace([0], [a]), isNull);
      expect(
        matchFace(descriptor(0), const [
          PreviewStudent('demo', 'Contoh', 'XI'),
        ]),
        isNull,
      );
    },
  );
  test(
    'Ambiguous lookalikes are rejected instead of selecting an arbitrary name',
    () {
      final a = PreviewStudent('a', 'A', 'XI', faceDescriptor: descriptor(0));
      final b = PreviewStudent('b', 'B', 'XI', faceDescriptor: descriptor(.1));
      expect(matchFace(descriptor(.04), [a, b]), isNull);
      final c = PreviewStudent('c', 'C', 'XI', faceDescriptor: descriptor(1));
      expect(matchFace(descriptor(.02), [a, c]), same(a));
    },
  );
}
