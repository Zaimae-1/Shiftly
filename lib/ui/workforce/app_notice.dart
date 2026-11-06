import 'package:flutter/material.dart';
import 'ui_motion.dart';

void showAppNotice(
  BuildContext context, {
  required String title,
  required String message,
  Color color = const Color(0xFF356CD4),
  IconData icon = Icons.check_circle_outline_rounded,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final wide = MediaQuery.sizeOf(context).width > 600;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      width: wide ? 480 : null,
      margin: wide ? null : const EdgeInsets.fromLTRB(12, 0, 12, 14),
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      duration: const Duration(seconds: 5),
      content: RevealIn(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: .18)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18315182),
                blurRadius: 28,
                offset: Offset(0, 9),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 23),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFF243653),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: const TextStyle(
                              color: Color(0xFF71809A),
                              fontSize: 11,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TouchFeedback(
                      child: IconButton(
                        tooltip: 'Tutup notifikasi',
                        visualDensity: VisualDensity.compact,
                        onPressed: messenger.hideCurrentSnackBar,
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF8393AC),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!MediaQuery.disableAnimationsOf(context))
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1, end: 0),
                  duration: const Duration(seconds: 5),
                  builder: (_, value, _) => Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        height: 3,
                        color: color.withValues(alpha: .55),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
