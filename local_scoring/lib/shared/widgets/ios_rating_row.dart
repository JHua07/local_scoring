import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_design_tokens.dart';

/// iOS 风格评分行（带 Slider）
class IosRatingRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;

  const IosRatingRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 10,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);
    final color = AppTokens.scoreColor(value);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppTokens.spaceXS,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppTokens.fontSizeCaption,
                color: AppTokens.txt2(brightness),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: CupertinoSlider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).toInt(),
              activeColor: color,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              value.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTokens.fontSizeBody,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
