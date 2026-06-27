import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/templates.dart' as tmpl;
import '../../core/theme/app_design_tokens.dart';
import '../../data/models/review_item.dart';
import '../../providers/review_provider.dart';
import '../../shared/widgets/ios_empty_state.dart';
import '../../shared/widgets/ios_score_badge.dart';
import '../../shared/widgets/ios_section.dart';
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
    final data = ref.watch(rankingDataProvider);
    final brightness = CupertinoTheme.brightnessOf(context);
    final templates = ref.watch(templateListProvider.select((s) => s.templates));

    final top10Limited = data.top10;
    final bottom10Limited = data.bottom10;
    final worthItems = data.worthItems;
    final notWorthItems = data.notWorthItems;
    final recommendItems = data.recommendItems;
    final categoryBest = data.categoryBest;

    if (data.isEmpty) {
      return CupertinoPageScaffold(
        backgroundColor: AppTokens.bg(brightness),
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: const Text('排行'),
              backgroundColor:
                  AppTokens.bg(brightness).withValues(alpha: 0.85),
              border: null,
            ),
            SliverFillRemaining(
              child: const IosEmptyState(
                icon: CupertinoIcons.chart_bar,
                title: '还没有评分',
                subtitle: '添加一些评分后，排行榜会在这里展示。',
              ),
            ),
          ],
        ),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg(brightness),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('排行'),
            backgroundColor:
                AppTokens.bg(brightness).withValues(alpha: 0.85),
            border: null,
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                if (top10Limited.isNotEmpty)
                  _RankSection(
                    icon: CupertinoIcons.rocket,
                    title: '最高分 Top ${top10Limited.length}',
                    items: top10Limited,
                    onTap: _navigateToDetail,
                  ),
                if (bottom10Limited.isNotEmpty)
                  _RankSection(
                    icon: CupertinoIcons.arrow_down,
                    title: '最低分 Bottom ${bottom10Limited.length}',
                    items: bottom10Limited,
                    onTap: _navigateToDetail,
                  ),
                if (worthItems.isNotEmpty)
                  _RankSection(
                    icon: CupertinoIcons.heart,
                    title: '最值得（${worthItems.length}）',
                    items: worthItems.take(10).toList(),
                    onTap: _navigateToDetail,
                  ),
                if (notWorthItems.isNotEmpty)
                  _RankSection(
                    icon: CupertinoIcons.clear_thick,
                    title: '最不值（${notWorthItems.length}）',
                    items: notWorthItems.take(10).toList(),
                    onTap: _navigateToDetail,
                    isNegative: true,
                  ),
                if (recommendItems.isNotEmpty)
                  _RankSection(
                    icon: CupertinoIcons.person_2,
                    title: '推荐给朋友（${recommendItems.length}）',
                    items: recommendItems.take(10).toList(),
                    onTap: _navigateToDetail,
                  ),
                if (categoryBest.isNotEmpty) ...[
                  const IosSectionHeader(title: '各分类最高分'),
                  ...categoryBest.entries.map((entry) {
                    final template =
                        tmpl.getTemplateById(templates, entry.key);
                    final item = entry.value;
                    return _CategoryBestCard(
                      emoji: template.icon,
                      categoryName: template.name,
                      item: item,
                      onTap: () => _navigateToDetail(item),
                    );
                  }),
                  const SizedBox(height: AppTokens.space3XL),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(ReviewItem item) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ReviewDetailPage(reviewId: item.id),
      ),
    );
  }
}

class _RankSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<ReviewItem> items;
  final void Function(ReviewItem) onTap;
  final bool isNegative;

  const _RankSection({
    required this.icon,
    required this.title,
    required this.items,
    required this.onTap,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.pagePaddingH,
            AppTokens.space2XL,
            AppTokens.pagePaddingH,
            AppTokens.spaceSM,
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 18,
                  color: isNegative ? AppTokens.danger : AppTokens.primary),
              const SizedBox(width: AppTokens.spaceSM),
              Text(
                title,
                style: TextStyle(fontSize: AppTokens.fontSizeCardTitle,
                  fontWeight: FontWeight.w700,
                  color: AppTokens.txt(CupertinoTheme.brightnessOf(context)),
                ),
              ),
            ],
          ),
        ),
        ...items.asMap().entries.map((entry) {
          final rank = entry.key;
          final item = entry.value;
          return _RankCard(
            rank: rank + 1,
            item: item,
            onTap: () => onTap(item),
          );
        }),
      ],
    );
  }
}

class _RankCard extends StatelessWidget {
  final int rank;
  final ReviewItem item;
  final VoidCallback onTap;

  const _RankCard({
    required this.rank,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTokens.pagePaddingH,
          vertical: 4,
        ),
        padding: const EdgeInsets.all(AppTokens.spaceMD),
        decoration: BoxDecoration(
          color: AppTokens.card(brightness),
          borderRadius: BorderRadius.circular(AppTokens.radiusMD),
          border: Border.all(
            color: AppTokens.sep(brightness).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: rank == 1 ? 18 : 14,
                  fontWeight: rank == 1 ? FontWeight.w800 : FontWeight.w600,
                  color: rank == 1
                      ? AppTokens.primary
                      : AppTokens.txt2(brightness),
                ),
              ),
            ),
            const SizedBox(width: AppTokens.spaceSM),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: AppTokens.fontSizeBody,
                  fontWeight: FontWeight.w500,
                  color: AppTokens.txt(brightness),
                ),
              ),
            ),
            const SizedBox(width: AppTokens.spaceSM),
            IosScoreBadge(score: item.score, size: 36),
          ],
        ),
      ),
    );
  }
}

class _CategoryBestCard extends StatelessWidget {
  final String emoji;
  final String categoryName;
  final ReviewItem item;
  final VoidCallback onTap;

  const _CategoryBestCard({
    required this.emoji,
    required this.categoryName,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTokens.pagePaddingH,
          vertical: 4,
        ),
        padding: const EdgeInsets.all(AppTokens.spaceMD),
        decoration: BoxDecoration(
          color: AppTokens.card(brightness),
          borderRadius: BorderRadius.circular(AppTokens.radiusMD),
          border: Border.all(
            color: AppTokens.sep(brightness).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryName,
                    style: TextStyle(fontSize: AppTokens.fontSizeSmall,
                      color: AppTokens.txt2(brightness),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.title,
                    style: TextStyle(fontSize: AppTokens.fontSizeBody,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.txt(brightness),
                    ),
                  ),
                ],
              ),
            ),
            IosScoreBadge(score: item.score, size: 36),
          ],
        ),
      ),
    );
  }
}

