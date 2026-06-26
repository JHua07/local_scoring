import 'package:flutter/cupertino.dart';

import '../../core/theme/app_design_tokens.dart';

/// iOS 风格页面 Scaffold（大标题 + CupertinoSliverNavigationBar）
class IosPageScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget>? headerChildren; // 在标题下方但在列表之前的内容
  final Widget? trailing;
  final bool largeTitle;
  final EdgeInsetsGeometry? padding;

  const IosPageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.headerChildren,
    this.trailing,
    this.largeTitle = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg(brightness),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: largeTitle ? Text(title) : null,
            backgroundColor: AppTokens.bg(brightness).withValues(alpha: 0.85),
            border: null,
            trailing: trailing,
          ),
          if (!largeTitle)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.pagePaddingH,
                  AppTokens.spaceSM,
                  AppTokens.pagePaddingH,
                  AppTokens.spaceMD,
                ),
                child: Text(
                  title,
                  style: TextStyle(fontSize: AppTokens.fontSizeHero,
                    fontWeight: FontWeight.w800,
                    color: AppTokens.txt(brightness),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
          if (headerChildren != null)
            SliverToBoxAdapter(
              child: Column(children: headerChildren!),
            ),
          SliverPadding(
            padding: padding ??
                const EdgeInsets.only(bottom: AppTokens.space3XL),
            sliver: SliverList(
              delegate: SliverChildListDelegate(children),
            ),
          ),
        ],
      ),
    );
  }
}

/// iOS 风格简单页面 Scaffold（带普通导航栏）
class IosSimpleScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final Widget? leading;
  final EdgeInsetsGeometry? padding;

  const IosSimpleScaffold({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.leading,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg(brightness),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          title,
          style: TextStyle(fontSize: AppTokens.fontSizeCardTitle,
            fontWeight: FontWeight.w600,
            color: AppTokens.txt(brightness),
          ),
        ),
        backgroundColor: AppTokens.bg(brightness).withValues(alpha: 0.85),
        border: null,
        trailing: trailing,
        leading: leading,
      ),
      child: SafeArea(
        child: ListView(
          padding: padding ??
              const EdgeInsets.only(bottom: AppTokens.space3XL),
          children: children,
        ),
      ),
    );
  }
}
