import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/review_item.dart';
import '../../providers/review_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/review_card.dart';
import '../../shared/widgets/score_badge.dart';
import '../review_detail/review_detail_page.dart';
import '../review_form/review_form_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(reviewListProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewListProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final items = state.items;

    // 统计数据
    final totalCount = items.length;
    final now = DateTime.now();
    final thisMonth = items
        .where((r) =>
            r.createdAt.year == now.year && r.createdAt.month == now.month)
        .toList();
    final monthCount = thisMonth.length;
    /// 最近一次添加距今天数（不足24h按小时计）
    final lastAdded = items.isNotEmpty
        ? _relativeTime(items.first.createdAt, now)
        : '--';
    final monthBest = thisMonth.isNotEmpty
        ? thisMonth
            .reduce((a, b) => a.score > b.score ? a : b)
        : null;
    final monthWorst = thisMonth.isNotEmpty
        ? thisMonth
            .reduce((a, b) => a.score < b.score ? a : b)
        : null;

    // 最近 5 条
    final recentItems = items.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的评分'),
        centerTitle: false,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? EmptyState(
                  icon: Icons.rate_review_outlined,
                  title: '还没有评分',
                  subtitle: '先记录一个最近体验过的东西吧。',
                  action: FilledButton.icon(
                    onPressed: () => _navigateToForm(context),
                    icon: const Icon(Icons.add),
                    label: const Text('新增评分'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(reviewListProvider.notifier).loadAll(),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      // 统计卡片区
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          '数据总览',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _StatCard(
                              label: '总记录',
                              value: '$totalCount',
                              icon: Icons.inventory_2_outlined,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            _StatCard(
                              label: '本月新增',
                              value: '$monthCount',
                              icon: Icons.trending_up,
                              color: const Color(0xFF4CAF50),
                            ),
                            const SizedBox(width: 10),
                            _StatCard(
                              label: '上次添加',
                              value: lastAdded,
                              icon: Icons.schedule,
                              color: const Color(0xFFFFA726),
                            ),
                          ],
                        ),
                        ),
                      ),

                      // 本月之最
                      if (monthBest != null || monthWorst != null) ...[
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            '本月之最',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (monthBest != null)
                          _MonthHighlightCard(
                            emoji: '🏆',
                            label: '这个月最值',
                            item: monthBest,
                            onTap: () => _navigateToDetail(context, monthBest),
                          ),
                        if (monthWorst != null) ...[
                          const SizedBox(height: 8),
                          _MonthHighlightCard(
                            emoji: '💣',
                            label: '这个月踩雷',
                            item: monthWorst,
                            onTap: () =>
                                _navigateToDetail(context, monthWorst),
                            isBad: true,
                          ),
                        ],
                      ],

                      // 最近记录
                      if (recentItems.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            '最近值得记住的体验',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        ...recentItems.map(
                          (item) => ReviewCard(
                            item: item,
                            onTap: () => _navigateToDetail(context, item),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(context),
        icon: const Icon(Icons.add),
        label: const Text('新增评分'),
      ),
    );
  }

  void _navigateToForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReviewFormPage()),
    );
  }

  void _navigateToDetail(BuildContext context, ReviewItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ReviewDetailPage(reviewId: item.id)),
    );
  }

  /// 计算相对时间（用于"上次添加"显示）
  static String _relativeTime(DateTime dt, DateTime now) {
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${(diff.inDays / 30).floor()}月前';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthHighlightCard extends StatelessWidget {
  final String emoji;
  final String label;
  final ReviewItem item;
  final VoidCallback onTap;
  final bool isBad;

  const _MonthHighlightCard({
    required this.emoji,
    required this.label,
    required this.item,
    required this.onTap,
    this.isBad = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isBad
                ? const Color(0xFFEF5350).withValues(alpha: 0.2)
                : const Color(0xFF4CAF50).withValues(alpha: 0.2),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ScoreBadge(score: item.score, size: 40),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
