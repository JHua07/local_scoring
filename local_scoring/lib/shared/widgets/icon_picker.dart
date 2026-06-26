import 'package:flutter/cupertino.dart';

import '../../core/theme/app_design_tokens.dart';

/// 预设图标库 —— 30 个生活评分常用 Emoji
const List<String> iconLibrary = [
  '🍜', '🍕', '🍔', '🍣', '🥩', '🍰', '☕', '🍺', '🥤',
  '🛍️', '👗', '👟', '⌚', '💄',
  '📱', '💻', '🎧', '📷',
  '🎮', '🎬', '🎵', '📚',
  '✈️', '🏨', '🏕️', '🚗',
  '🏋️', '🎨', '🐱', '💊',
];

/// 图标选择器弹窗 —— 网格展示，点击选择
class IconPicker extends StatelessWidget {
  final String currentIcon;
  final ValueChanged<String> onSelected;

  const IconPicker({
    super.key,
    required this.currentIcon,
    required this.onSelected,
  });

  /// 弹出图标选择器
  static void show(BuildContext context, {
    required String currentIcon,
    required ValueChanged<String> onSelected,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => IconPicker(
        currentIcon: currentIcon,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTokens.card(brightness),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动指示条
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppTokens.txt3(brightness).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  const Text('选择图标',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('关闭',
                        style: TextStyle(fontSize: 16)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 图标网格
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: iconLibrary.map((icon) {
                  final selected = icon == currentIcon;
                  return GestureDetector(
                    onTap: () {
                      onSelected(icon);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTokens.primary.withValues(alpha: 0.12)
                            : AppTokens.elevated(brightness),
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusMD),
                        border: selected
                            ? Border.all(color: AppTokens.primary, width: 2)
                            : Border.all(
                                color: AppTokens.sep(brightness)
                                    .withValues(alpha: 0.5)),
                      ),
                      alignment: Alignment.center,
                      child: Text(icon, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
