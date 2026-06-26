import 'package:flutter/cupertino.dart';

import '../../core/theme/app_design_tokens.dart';

/// iOS 风格分组 Section 标题
class IosSectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  const IosSectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.pagePaddingH,
        AppTokens.space2XL,
        AppTokens.pagePaddingH,
        AppTokens.spaceSM,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: AppTokens.fontSizeTitle,
                fontWeight: FontWeight.w700,
                color: AppTokens.txt(brightness),
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: () {},
              child: Text(
                trailing!,
                style: TextStyle(fontSize: AppTokens.fontSizeCaption,
                  color: AppTokens.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// iOS 风格分组卡片容器
class IosCardSection extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const IosCardSection({
    super.key,
    required this.children,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTokens.pagePaddingH,
        vertical: 4,
      ),
      padding: padding ??
          const EdgeInsets.all(AppTokens.cardPaddingH),
      decoration: BoxDecoration(
        color: AppTokens.card(brightness),
        borderRadius: BorderRadius.circular(AppTokens.radiusLG),
        border: Border.all(
          color: AppTokens.sep(brightness).withValues(alpha: 0.6),
        ),
        boxShadow: AppTokens.cardShadow(brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
