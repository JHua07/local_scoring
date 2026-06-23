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
    final config = getCategoryConfig(item.category);

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
              // 图片缩略图
              if (item.imagePaths.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImage(context, item.imagePaths.first, colorScheme),
                )
              else
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(config.icon, style: const TextStyle(fontSize: 28)),
                  ),
                ),
              const SizedBox(width: 14),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
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
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            config.name,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
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

  Widget _buildImage(BuildContext context, String path, ColorScheme colorScheme) {
    final file = File(path);
    if (!file.existsSync()) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.broken_image_outlined,
            color: colorScheme.outline.withValues(alpha: 0.5)),
      );
    }
    return Image.file(file, width: 72, height: 72, fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.broken_image_outlined,
                  color: colorScheme.outline.withValues(alpha: 0.5)),
            ));
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
