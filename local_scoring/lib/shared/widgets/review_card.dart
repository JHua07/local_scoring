import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/categories.dart';
import '../../core/utils/date_formatters.dart';
import '../../data/models/review_item.dart';
import 'score_badge.dart';

class ReviewCard extends StatelessWidget {
  final ReviewItem item;
  final VoidCallback? onTap;

  const ReviewCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final catIcon = getCategoryIcon(item.category);
    final thumbPath = item.firstImagePath;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // 缩略图（最早一张）
              if (thumbPath != null && File(thumbPath).existsSync())
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(thumbPath), width: 72, height: 72, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallbackThumb(colorScheme)),
                )
              else
                _fallbackThumb(colorScheme),
              const SizedBox(width: 14),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // 分类图标在标题左边
                        Text(catIcon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    if (item.reviewText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.reviewText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ScoreBadge(score: item.score, size: 32),
                        const SizedBox(width: 8),
                        if (item.worth == 'worth')
                          _worthBadge(context, '值', const Color(0xFF4CAF50))
                        else if (item.worth == 'not_worth')
                          _worthBadge(context, '不值', const Color(0xFFEF5350)),
                        if (item.recommendToFriends)
                          _worthBadge(context, '推荐', const Color(0xFF7E57C2)),
                        const Spacer(),
                        Text(
                          formatRelative(item.updatedAt),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: colorScheme.outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 无图片时的占位缩略图
  Widget _fallbackThumb(ColorScheme colorScheme) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.image_outlined, size: 28, color: colorScheme.outline.withValues(alpha: 0.4)),
    );
  }

  Widget _worthBadge(BuildContext context, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
