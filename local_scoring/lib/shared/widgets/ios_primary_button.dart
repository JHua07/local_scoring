import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, VoidCallback;
import 'package:flutter/services.dart';

import '../../core/theme/app_design_tokens.dart';

/// iOS 风格主按钮
class IosPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isDanger;
  final bool isOutlined;
  final double? width;

  const IosPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isDanger = false,
    this.isOutlined = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isOutlined
        ? Colors.transparent
        : isDanger
            ? AppTokens.danger
            : AppTokens.primary;

    final fgColor = isOutlined
        ? (isDanger ? AppTokens.danger : AppTokens.primary)
        : AppTokens.textOnPrimary;

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: fgColor),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: TextStyle(fontSize: AppTokens.fontSizeBody,
            fontWeight: FontWeight.w600,
            color: fgColor,
          ),
        ),
      ],
    );

    return GestureDetector(
      onTap: onPressed != null
          ? () {
              HapticFeedback.lightImpact();
              onPressed!.call();
            }
          : null,
      child: AnimatedOpacity(
        opacity: onPressed == null ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space2XL,
            vertical: AppTokens.spaceMD + 2,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppTokens.radiusMD),
            border: isOutlined
                ? Border.all(
                    color: fgColor.withValues(alpha: 0.4),
                    width: 1,
                  )
                : null,
            boxShadow: onPressed != null && !isOutlined
                ? [
                    BoxShadow(
                      color: bgColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
