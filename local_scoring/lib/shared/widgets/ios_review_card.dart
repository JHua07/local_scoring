import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_design_tokens.dart';
import '../../data/models/review_item.dart';
import 'ios_score_badge.dart';

/// iOS 风格评分卡片
class IosReviewCard extends StatelessWidget {
  final ReviewItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const IosReviewCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);
    final thumbPath = item.firstImagePath;
    final worthText = _worthLabel(item.worth);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTokens.pagePaddingH,
          vertical: 5,
        ),
        padding: const EdgeInsets.all(AppTokens.cardPaddingH),
        decoration: BoxDecoration(
          color: AppTokens.card(brightness),
          borderRadius: BorderRadius.circular(AppTokens.radiusLG),
          border: Border.all(
            color: AppTokens.sep(brightness).withValues(alpha: 0.6),
          ),
          boxShadow: AppTokens.cardShadow(brightness),
        ),
        child: Row(
          children: [
            // 缩略图
            _buildThumbnail(thumbPath, brightness),
            const SizedBox(width: 14),
            // 右侧内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppTokens.fontSizeCardTitle,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.txt(brightness),
                    ),
                  ),
                  // 评价文字（最多两行）
                  if (item.reviewText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.reviewText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: AppTokens.fontSizeCaption,
                        color: AppTokens.txt2(brightness),
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // 底部标签行
                  Row(
                    children: [
                      // 标签（最多3个）
                      ...item.tags.take(3).map((tag) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTokens.txt3(brightness)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                    AppTokens.radiusXS),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(fontSize: 11,
                                  color: AppTokens.txt2(brightness),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )),
                      if (worthText != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _worthColor(item.worth).withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusXS),
                          ),
                          child: Text(
                            worthText,
                            style: TextStyle(fontSize: 11,
                              color: _worthColor(item.worth),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (item.recommendToFriends)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            CupertinoIcons.heart_fill,
                            size: 13,
                            color: AppTokens.purple,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 评分
            IosScoreBadge(score: item.score, size: 44),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(String? path, Brightness brightness) {
    if (path != null && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusMD),
        child: Image.file(
          File(path),
          width: 68,
          height: 68,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(brightness),
        ),
      );
    }
    return _placeholder(brightness);
  }

  Widget _placeholder(Brightness brightness) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: AppTokens.elevated(brightness),
        borderRadius: BorderRadius.circular(AppTokens.radiusMD),
      ),
      child: Icon(
        CupertinoIcons.photo,
        size: 24,
        color: AppTokens.txt3(brightness),
      ),
    );
  }

  String? _worthLabel(String worth) {
    switch (worth) {
      case 'worth':
        return '值得';
      case 'normal':
        return '一般';
      case 'not_worth':
        return '不值';
      default:
        return null;
    }
  }

  Color _worthColor(String worth) {
    switch (worth) {
      case 'worth':
        return AppTokens.success;
      case 'not_worth':
        return AppTokens.danger;
      default:
        return AppTokens.textSecondary;
    }
  }
}
