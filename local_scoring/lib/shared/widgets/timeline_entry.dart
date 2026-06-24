import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/categories.dart';
import '../../data/models/review_item.dart';

/// 时间线条目：折叠态=缩略图+分数+标题+分类图标；展开态=历史评价列表
class TimelineEntry extends StatelessWidget {
  final ReviewItem item;
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget? expandedContent;

  const TimelineEntry({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onTap,
    this.expandedContent,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final catIcon = getCategoryIcon(item.category);
    final thumbPath = item.firstImagePath;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isExpanded
                ? colorScheme.primaryContainer.withValues(alpha: 0.15)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: isExpanded
                ? Border.all(color: colorScheme.primary.withValues(alpha: 0.3))
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // 日期
                SizedBox(
                  width: 72,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_monthDay(item.createdAt),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.primary)),
                    Text(_year(item.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.outline, fontSize: 10)),
                  ]),
                ),
                // 竖线
                Container(width: 2, height: 36, margin: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(1))),
                // 缩略图（最早一张）
                if (thumbPath != null && File(thumbPath).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(width: 40, height: 40, child: Image.file(File(thumbPath), fit: BoxFit.cover)),
                  )
                else
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text(catIcon, style: const TextStyle(fontSize: 20))),
                  ),
                const SizedBox(width: 10),
                // 分数 panel
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _scoreColor(item.score).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(item.score.toStringAsFixed(1),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _scoreColor(item.score))),
                ),
                const SizedBox(width: 8),
                // 标题 + 分类图标
                Expanded(
                  child: Row(children: [
                    Flexible(
                      child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    Text(catIcon, style: const TextStyle(fontSize: 16)),
                  ]),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.chevron_right, size: 20, color: colorScheme.outline),
                ),
              ]),
              if (isExpanded && expandedContent != null)
                Padding(padding: const EdgeInsets.only(top: 12, left: 84), child: expandedContent!),
            ],
          ),
        ),
      ),
    );
  }

  Color _scoreColor(double s) {
    if (s >= 8) return const Color(0xFF4CAF50);
    if (s >= 6) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }

  String _monthDay(DateTime d) => '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _year(DateTime d) => '${d.year}';
}

/// 时间线月份分隔标题
class TimelineMonthHeader extends StatelessWidget {
  final int year;
  final int month;

  const TimelineMonthHeader({
    super.key,
    required this.year,
    required this.month,
  });

  static const _months = [
    '',
    '1月',
    '2月',
    '3月',
    '4月',
    '5月',
    '6月',
    '7月',
    '8月',
    '9月',
    '10月',
    '11月',
    '12月'
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: [
          Text(
            '$year年${_months[month]}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: colorScheme.primary.withValues(alpha: 0.2),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 批注小卡片（在时间线展开态中显示）
class AnnotationCard extends StatelessWidget {
  final String text;
  final DateTime createdAt;

  const AnnotationCard({
    super.key,
    required this.text,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 14, color: colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                    '${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: colorScheme.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
