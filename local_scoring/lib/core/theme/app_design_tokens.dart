import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 统一设计 Token —— iOS 风格私人评分 App
class AppTokens {
  AppTokens._();

  // ── 色彩系统 ──
  static const Color pageBackground = Color(0xFFF2F2F7); // iOS 系统背景
  static const Color cardBackground = Color(0xFFFFFFFF); // 卡片白
  static const Color elevatedSurface = Color(0xFFF8F8FA); // 轻微抬高

  // 主色（iOS 蓝）
  static const Color primary = Color(0xFF007AFF);
  static const Color primaryLight = Color(0xFFE8F1FD); // 浅蓝背景

  // 语义色
  static const Color success = Color(0xFF34C759); // 柔和绿
  static const Color warning = Color(0xFFFF9500); // 暖橙
  static const Color danger = Color(0xFFFF3B30); // iOS 红
  static const Color purple = Color(0xFFAF52DE); // 推荐/紫色

  // 文字
  static const Color textPrimary = Color(0xFF1C1C1E); // 主文字
  static const Color textSecondary = Color(0xFF8E8E93); // 次级文字
  static const Color textWeak = Color(0xFFC7C7CC); // 弱文字
  static const Color textOnPrimary = Color(0xFFFFFFFF); // 主色上文字

  // 分割 / 边框
  static const Color separator = Color(0xFFE5E5EA); // 分割线
  static const Color borderLight = Color(0xFFF0F0F3); // 极浅边框

  // 分数色
  static const Color scoreHigh = Color(0xFF34C759); // ≥8
  static const Color scoreMid = Color(0xFFFF9500); // ≥6
  static const Color scoreLow = Color(0xFFFF3B30); // <6

  // 暗色模式
  static const Color darkPageBackground = Color(0xFF1C1C1E);
  static const Color darkCardBackground = Color(0xFF2C2C2E);
  static const Color darkElevatedSurface = Color(0xFF3A3A3C);
  static const Color darkSeparator = Color(0xFF38383A);
  static const Color darkTextPrimary = Color(0xFFF2F2F7);
  static const Color darkTextSecondary = Color(0xFF8E8E93);
  static const Color darkTextWeak = Color(0xFF636366);

  // ── 圆角 ──
  static const double radiusXS = 6;
  static const double radiusSM = 10;
  static const double radiusMD = 14;
  static const double radiusLG = 18;
  static const double radiusXL = 22;
  static const double radiusFull = 999;

  // ── 间距 ──
  static const double spaceXS = 4;
  static const double spaceSM = 8;
  static const double spaceMD = 12;
  static const double spaceLG = 16;
  static const double spaceXL = 20;
  static const double space2XL = 24;
  static const double space3XL = 32;

  // 页面水平边距
  static const double pagePaddingH = 16;

  // 卡片内边距
  static const double cardPaddingV = 16;
  static const double cardPaddingH = 16;

  // ── 字体大小 ──
  static const double fontSizeHero = 34; // 大标题
  static const double fontSizeTitle = 20; // 页面小标题
  static const double fontSizeCardTitle = 17; // 卡片标题
  static const double fontSizeBody = 15; // 正文
  static const double fontSizeCaption = 13; // 说明文字
  static const double fontSizeSmall = 11; // 极小文字

  // ── 阴影 ──
  static List<BoxShadow> cardShadow(Brightness brightness) {
    if (brightness == Brightness.dark) return [];
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  // ── 快捷获取 ──
  static Color bg(Brightness b) =>
      b == Brightness.dark ? darkPageBackground : pageBackground;
  static Color card(Brightness b) =>
      b == Brightness.dark ? darkCardBackground : cardBackground;
  static Color elevated(Brightness b) =>
      b == Brightness.dark ? darkElevatedSurface : elevatedSurface;
  static Color sep(Brightness b) =>
      b == Brightness.dark ? darkSeparator : separator;
  static Color txt(Brightness b) =>
      b == Brightness.dark ? darkTextPrimary : textPrimary;
  static Color txt2(Brightness b) =>
      b == Brightness.dark ? darkTextSecondary : textSecondary;
  static Color txt3(Brightness b) =>
      b == Brightness.dark ? darkTextWeak : textWeak;

  /// 根据分数获取颜色
  static Color scoreColor(double score) {
    if (score >= 8) return scoreHigh;
    if (score >= 6) return scoreMid;
    if (score > 0) return scoreLow;
    return textSecondary;
  }
}
