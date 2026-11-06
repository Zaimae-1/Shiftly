import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Plays the current scan-only JSON at its exported duration. Recognition is
/// shown separately, without depending on frame numbers from an older asset.
class FaceScanAnimation extends StatefulWidget {
  final bool active;
  final bool recognized;
  const FaceScanAnimation({
    super.key,
    required this.active,
    this.recognized = false,
  });

  @override
  State<FaceScanAnimation> createState() => _FaceScanAnimationState();
}

class _FaceScanAnimationState extends State<FaceScanAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _loaded = false;

  void _sync() {
    if (!_loaded) return;
    _controller.stop();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (!widget.recognized && widget.active && !reduced) {
      _controller.repeat();
    } else {
      _controller.value = .5;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant FaceScanAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active ||
        oldWidget.recognized != widget.recognized) {
      _sync();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: widget.recognized
          ? const Center(
              child: Icon(
                Icons.check_circle_rounded,
                key: ValueKey('face-scan-recognized'),
                size: 42,
                color: Color(0xFFBAC8DC),
              ),
            )
          : Lottie.asset(
              'assets/raw/face_id_ring.json',
              key: const ValueKey('face-scan-lottie'),
              controller: _controller,
              fit: BoxFit.contain,
              onLoaded: (composition) {
                _controller.duration = composition.duration;
                _loaded = true;
                _sync();
              },
              errorBuilder: (_, error, stack) => const Center(
                child: Icon(
                  Icons.face_retouching_natural_rounded,
                  size: 72,
                  color: Color(0xFFBAC8DC),
                ),
              ),
            ),
    ),
  );
}
