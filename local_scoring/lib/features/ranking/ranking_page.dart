import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/templates.dart' as tmpl;
import '../../data/models/review_item.dart';
import '../../providers/review_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/review_card.dart';
import '../../shared/widgets/score_badge.dart';
import '../review_detail/review_detail_page.dart';

class RankingPage extends ConsumerStatefulWidget {
  const RankingPage({super.key});

  @override
  ConsumerState<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends ConsumerState<RankingPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(reviewListProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final items = state.items;

    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('排行榜')),
        body: const EmptyState(
          icon: Icons.leaderboard_outlined,
          title: '还没有评分',
          subtitle: '添加一些评分后，排行榜会在这里展示。',
        ),
      );
    }

    // Top 10
    final top10 = List<ReviewItem>.from(items)
      ..sort((a, b) => b.score.compareTo(a.score));
    final top10Limited = top10.take(10).toList();

    // Bottom 10
    final bottom10 = List<ReviewItem>.from(items)
      ..sort((a, b) => a.score.compareTo(b.score));
    final bottom10Limited = bottom10.take(10).toList();

    // Worth
    final worthItems =
        items.where((r) => r.worth == 'worth').toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    // Not worth
    final notWorthItems =
        items.where((r) => r.worth == 'not_worth').toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    // Recommend
    final recommendItems =
        items.where((r) => r.recommendToFriends).toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    // 各分类最高分
    final templates = ref.watch(templateListProvider).templates;
    final categoryBest = <String, ReviewItem>{};
    for (final template in templates.where((t) => t.parentTemplateId == null)) {
      final catItems = items
          .where((r) => r.category == template.id)
          .toList();
      if (catItems.isNotEmpty) {
        catItems.sort((a, b) => b.score.compareTo(a.score));
        categoryBest[template.id] = catItems.first;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('排行榜')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (top10Limited.isNotEmpty)
            _Section(
              icon: '🏆',
              title: '最高分 Top ${top10Limited.length}',
              items: top10Limited,
              onTap: (item) => _navigateToDetail(item),
            ),
          if (bottom10Limited.isNotEmpty)
            _Section(
              icon: '📉',
              title: '最低分 Bottom ${bottom10Limited.length}',
              items: bottom10Limited,
              onTap: (item) => _navigateToDetail(item),
            ),
          if (worthItems.isNotEmpty)
            _Section(
              icon: '💎',
              title: '最值得（${worthItems.length}）',
              items: worthItems.take(10).toList(),
              onTap: (item) => _navigateToDetail(item),
            ),
          if (notWorthItems.isNotEmpty)
            _Section(
              icon: '💣',
              title: '最不值（${notWorthItems.length}）',
              items: notWorthItems.take(10).toList(),
              onTap: (item) => _navigateToDetail(item),
            ),
          if (recommendItems.isNotEmpty)
            _Section(
              icon: '❤️',
              title: '推荐给朋友（${recommendItems.length}）',
              items: recommendItems.take(10).toList(),
              onTap: (item) => _navigateToDetail(item),
            ),
          if (categoryBest.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const Text('🥇', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    '各分类最高分',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            ...categoryBest.entries.map((entry) {
              final template = tmpl.getTemplateById(templates, entry.key);
              final item = entry.value;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                        color: colorScheme.outlineVariant
                            .withValues(alpha: 0.3)),
                  ),
                  child: InkWell(
                    onTap: () => _navigateToDetail(item),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Text(template.icon,
                              style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(template.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                            color: colorScheme
                                                .onSurface
                                                .withValues(
                                                    alpha: 0.5))),
                                Text(item.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            fontWeight:
                                                FontWeight.w600)),
                              ],
                            ),
                          ),
                          ScoreBadge(score: item.score, size: 36),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  void _navigateToDetail(ReviewItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ReviewDetailPage(reviewId: item.id)),
    );
  }
}

class _Section extends StatelessWidget {
  final String icon;
  final String title;
  final List<ReviewItem> items;
  final void Function(ReviewItem) onTap;

  const _Section({
    required this.icon,
    required this.title,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        ...items.map((item) => ReviewCard(
              item: item,
              onTap: () => onTap(item),
            )),
      ],
    );
  }
}
