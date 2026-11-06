import 'package:attendance_app/ui/face_scan_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LottieComposition composition;
  setUpAll(() async {
    final bytes = await rootBundle.load('assets/raw/face_id_ring.json');
    composition = LottieComposition.parseJsonBytes(bytes.buffer.asUint8List());
  });

  Widget app({
    bool active = true,
    bool recognized = false,
    bool reduced = false,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: FaceScanAnimation(active: active, recognized: recognized),
    ),
  );

  LottieBuilder animation(WidgetTester tester) => tester.widget<LottieBuilder>(
    find.byKey(const ValueKey('face-scan-lottie')),
  );

  testWidgets(
    'New scan asset loops at its own duration and shows success only after matching',
    (tester) async {
      await tester.pumpWidget(app());
      animation(tester).onLoaded!(composition);
      await tester.pump();
      final controller = animation(tester).controller! as AnimationController;
      await tester.pump(const Duration(seconds: 9));
      expect(controller.duration, composition.duration);
      expect(controller.value, inInclusiveRange(0.0, 1.0));
      expect(controller.isAnimating, isTrue);
      expect(find.byKey(const ValueKey('face-scan-recognized')), findsNothing);
      await tester.pumpWidget(app(active: false, recognized: true));
      expect(
        find.byKey(const ValueKey('face-scan-recognized')),
        findsOneWidget,
      );
      expect(controller.isAnimating, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Reduced motion keeps a static scan illustration without false success',
    (tester) async {
      await tester.pumpWidget(app(reduced: true));
      animation(tester).onLoaded!(composition);
      await tester.pump();
      final controller = animation(tester).controller! as AnimationController;
      expect(controller.isAnimating, isFalse);
      expect(find.byKey(const ValueKey('face-scan-recognized')), findsNothing);
      await tester.pumpWidget(
        app(active: false, recognized: true, reduced: true),
      );
      expect(
        find.byKey(const ValueKey('face-scan-recognized')),
        findsOneWidget,
      );
      expect(controller.isAnimating, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
