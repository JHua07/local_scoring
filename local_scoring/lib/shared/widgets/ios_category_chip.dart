import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_design_tokens.dart';

/// iOS 风格分类 Chip
class IosCategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? emoji;
  final bool selected;
  final VoidCallback? onTap;

  const IosCategoryChip({
    super.key,
    required this.label,
    this.icon,
    this.emoji,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);

    final bgColor = selected
        ? AppTokens.primary
        : AppTokens.elevated(brightness);

    final fgColor = selected
        ? AppTokens.textOnPrimary
        : AppTokens.txt(brightness);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMD,
          vertical: AppTokens.spaceSM,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTokens.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
            ] else if (icon != null) ...[
              Icon(icon, size: 16, color: fgColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: AppTokens.fontSizeCaption,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
