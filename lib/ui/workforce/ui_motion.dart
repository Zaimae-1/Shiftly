import 'package:flutter/material.dart';

class MotionResize extends StatelessWidget {
  final Widget child;
  const MotionResize({super.key, required this.child});
  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? child
      : AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: child,
        );
}

/// Feedback remains finite and respects the system's reduced-motion setting.
/// The child owns its tap semantics; this wrapper never intercepts callbacks.
class TouchFeedback extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double hoverScale;
  final double hoverLift;
  const TouchFeedback({
    super.key,
    required this.child,
    this.enabled = true,
    this.hoverScale = 1.012,
    this.hoverLift = 2,
  });
  @override
  State<TouchFeedback> createState() => _TouchFeedbackState();
}

class _TouchFeedbackState extends State<TouchFeedback> {
  bool _hover = false, _pressed = false;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: TweenAnimationBuilder<double>(
          tween: Tween(
            end: reduced || !widget.enabled || !_hover || _pressed
                ? 0
                : -widget.hoverLift,
          ),
          duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
          curve: Curves.easeOutQuart,
          builder: (context, offset, child) =>
              Transform.translate(offset: Offset(0, offset), child: child),
          child: AnimatedScale(
            scale: reduced || !widget.enabled
                ? 1
                : _pressed
                ? .98
                : _hover
                ? widget.hoverScale
                : 1,
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOutQuart,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class RevealIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  const RevealIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: reduced ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 10),
          child: child,
        ),
      ),
    );
  }
}

class MotionTabs extends StatelessWidget {
  final List<String> labels;
  final List<IconData>? icons;
  final int selected;
  final ValueChanged<int>? onChanged;
  final String? keyPrefix;
  const MotionTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.icons,
    this.keyPrefix,
  });
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final duration = reduced
        ? Duration.zero
        : const Duration(milliseconds: 240);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFDFE6EF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD1DAE7)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositionedDirectional(
                duration: duration,
                curve: Curves.easeOutCubic,
                start: selected * width,
                top: 0,
                bottom: 0,
                width: width,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF356CD4), Color(0xFF2E4360)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x192E4360),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: TouchFeedback(
                        enabled: onChanged != null,
                        child: TextButton(
                          key: keyPrefix == null
                              ? null
                              : ValueKey('$keyPrefix$i'),
                          onPressed: onChanged == null
                              ? null
                              : () => onChanged!(i),
                          style: TextButton.styleFrom(
                            foregroundColor: selected == i
                                ? Colors.white
                                : const Color(0xFF466590),
                            disabledForegroundColor: selected == i
                                ? Colors.white70
                                : const Color(0xFF6183B3),
                            minimumSize: const Size(0, 46),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (icons != null &&
                                  constraints.maxWidth > 340) ...[
                                Icon(icons![i], size: 17),
                                const SizedBox(width: 7),
                              ],
                              Flexible(
                                child: Text(
                                  labels[i],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: constraints.maxWidth < 320
                                        ? 11
                                        : 12,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
