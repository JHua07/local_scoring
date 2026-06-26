import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_design_tokens.dart';

/// iOS 风格空状态
class IosEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const IosEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space3XL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTokens.elevated(brightness),
                borderRadius: BorderRadius.circular(AppTokens.radiusXL),
              ),
              child: Icon(
                icon,
                size: 36,
                color: AppTokens.txt3(brightness),
              ),
            ),
            const SizedBox(height: AppTokens.spaceXL),
            Text(
              title,
              style: TextStyle(fontSize: AppTokens.fontSizeCardTitle,
                fontWeight: FontWeight.w600,
                color: AppTokens.txt2(brightness),
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTokens.spaceSM),
              Text(
                subtitle!,
                style: TextStyle(fontSize: AppTokens.fontSizeCaption,
                  color: AppTokens.txt3(brightness),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTokens.space2XL),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
