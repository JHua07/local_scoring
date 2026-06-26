import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_design_tokens.dart';

/// iOS 风格评分徽章
class IosScoreBadge extends StatelessWidget {
  final double score;
  final double size;
  final bool showLabel;

  const IosScoreBadge({
    super.key,
    required this.score,
    this.size = 48,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);
    final color = AppTokens.scoreColor(score);
    final isDark = brightness == Brightness.dark;
    final radius = size / 4.2;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            score > 0 ? score.toStringAsFixed(score == score.roundToDouble() ? 0 : 1) : '-',
            style: TextStyle(color: color,
              fontSize: size / 2.8,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 1),
            Text(
              '/ 10',
              style: TextStyle(color: color.withValues(alpha: 0.6),
                fontSize: size / 6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
