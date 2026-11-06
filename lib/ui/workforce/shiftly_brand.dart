import 'package:flutter/material.dart';

/// A briefcase and check mark: a small, legible mark for work attendance.
class ShiftlyMark extends StatelessWidget {
  final double size;
  final bool light;
  const ShiftlyMark({super.key, this.size = 42, this.light = false});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: light
            ? [const Color(0xFFFFFFFF), const Color(0xFFE4EEFF)]
            : [const Color(0xFF6B9DF2), const Color(0xFF356CD4)],
      ),
      borderRadius: BorderRadius.circular(size * .31),
      border: Border.all(color: Colors.white.withValues(alpha: .35)),
      boxShadow: light
          ? null
          : const [
              BoxShadow(
                color: Color(0x20356CD4),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.work_outline_rounded,
          size: size * .58,
          color: light ? const Color(0xFF356CD4) : Colors.white,
        ),
        Positioned(
          right: size * .12,
          bottom: size * .12,
          child: Container(
            padding: EdgeInsets.all(size * .025),
            decoration: BoxDecoration(
              color: light ? Colors.white : const Color(0xFF356CD4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: size * .28,
              color: light ? const Color(0xFF356CD4) : Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}
