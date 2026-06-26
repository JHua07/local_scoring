import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_design_tokens.dart';
import '../../data/models/review_item.dart';
import '../../providers/review_provider.dart';
import '../../shared/widgets/ios_empty_state.dart';
import '../../shared/widgets/ios_primary_button.dart';
import '../../shared/widgets/ios_review_card.dart';
import '../../shared/widgets/ios_section.dart';
import '../review_detail/review_detail_page.dart';
import '../review_form/review_form_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(reviewListProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(reviewListProvider);
    final brightness = CupertinoTheme.brightnessOf(context);
    final items = state.items;

    final now = DateTime.now();
    final thisMonth = items
        .where((r) =>
            r.createdAt.year == now.year && r.createdAt.month == now.month)
        .toList();
    final monthCount = thisMonth.length;
    final recentItems = items.take(5).toList();
    final monthBest = thisMonth.isNotEmpty
        ? thisMonth.reduce((a, b) => a.score > b.score ? a : b)
        : null;
    final monthWorst = thisMonth.isNotEmpty
        ? thisMonth.reduce((a, b) => a.score < b.score ? a : b)
        : null;
    final avgScore = thisMonth.isNotEmpty
        ? thisMonth.map((r) => r.score).reduce((a, b) => a + b) /
            thisMonth.length
        : 0.0;

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg(brightness),
      child: state.isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : items.isEmpty
              ? _buildEmptyState(brightness)
              : Stack(
                  children: [
                    CustomScrollView(
                      slivers: [
                        CupertinoSliverNavigationBar(
                          largeTitle: const Text('今天'),
                          backgroundColor:
                              AppTokens.bg(brightness).withValues(alpha: 0.85),
                          border: null,
                        ),
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              _buildHeroCard(
                                  brightness, monthCount, avgScore, monthBest, monthWorst),
                              if (recentItems.isNotEmpty) ...[
                                const IosSectionHeader(title: '最近记录'),
                                ...recentItems.map(
                                  (item) => IosReviewCard(
                                    item: item,
                                    onTap: () => _navigateToDetail(context, item),
                                    onLongPress: () => _showContextMenu(context, item),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 100), // space for FAB
                            ],
                          ),
                        ),
                      ],
                    ),
                    // 右下角新增按钮（iOS 风格 FAB）
                    Positioned(
                      right: AppTokens.pagePaddingH,
                      bottom: AppTokens.space3XL,
                      child: GestureDetector(
                        onTap: () => _navigateToForm(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 15),
                          decoration: BoxDecoration(
                            color: AppTokens.primary,
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusMD),
                            boxShadow: [
                              BoxShadow(
                                color: AppTokens.primary.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.add,
                                  color: Colors.white, size: 26),
                              SizedBox(width: 8),
                              Text(
                                '记录体验',
                                style: TextStyle(color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState(Brightness brightness) {
    return CustomScrollView(
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('今天'),
          backgroundColor: AppTokens.bg(brightness).withValues(alpha: 0.85),
          border: null,
        ),
        SliverFillRemaining(
          child: IosEmptyState(
            icon: CupertinoIcons.star,
            title: '最近有什么值得记住？',
            subtitle: '记录吃到、买到、玩到、看过的体验，\n给自己一个真实的评分。',
            action: IosPrimaryButton(
              label: '记录一次体验',
              icon: CupertinoIcons.add,
              onPressed: () => _navigateToForm(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(
    Brightness brightness,
    int monthCount,
    double avgScore,
    ReviewItem? monthBest,
    ReviewItem? monthWorst,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.pagePaddingH,
        AppTokens.spaceSM,
        AppTokens.pagePaddingH,
        AppTokens.spaceLG,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTokens.spaceXL),
        decoration: BoxDecoration(
          color: AppTokens.card(brightness),
          borderRadius: BorderRadius.circular(AppTokens.radiusXL),
          border: Border.all(
            color: AppTokens.sep(brightness).withValues(alpha: 0.6),
          ),
          boxShadow: AppTokens.cardShadow(brightness),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最近有什么值得记住？',
              style: TextStyle(fontSize: AppTokens.fontSizeTitle,
                fontWeight: FontWeight.w700,
                color: AppTokens.txt(brightness),
              ),
            ),
            const SizedBox(height: AppTokens.spaceXL),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _heroStat(
                    brightness, '本月记录', '$monthCount', CupertinoIcons.calendar),
                Container(
                    width: 1,
                    height: 40,
                    color: AppTokens.sep(brightness)),
                _heroStat(brightness, '平均分',
                    avgScore > 0 ? avgScore.toStringAsFixed(1) : '--',
                    CupertinoIcons.chart_bar),
                Container(
                    width: 1,
                    height: 40,
                    color: AppTokens.sep(brightness)),
                _heroStat(
                    brightness, '本月最值',
                    monthBest != null
                        ? _truncateText(monthBest.title, 6)
                        : '暂无',
                    CupertinoIcons.heart),
              ],
            ),
            if (monthWorst != null) ...[
              const SizedBox(height: AppTokens.spaceMD),
              Container(
                  color: AppTokens.sep(brightness).withValues(alpha: 0.5),
                  height: 1),
              const SizedBox(height: AppTokens.spaceMD),
              Row(
                children: [
                  Icon(CupertinoIcons.clear_thick,
                      size: 16, color: AppTokens.danger),
                  const SizedBox(width: 6),
                  Text(
                    '本月踩雷：${monthWorst.title}',
                    style: TextStyle(fontSize: AppTokens.fontSizeCaption,
                      color: AppTokens.txt2(brightness),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _heroStat(
      Brightness brightness, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTokens.primary),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(fontSize: AppTokens.fontSizeTitle,
            fontWeight: FontWeight.w800,
            color: AppTokens.txt(brightness),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: AppTokens.fontSizeSmall,
            color: AppTokens.txt2(brightness),
          ),
        ),
      ],
    );
  }

  String _truncateText(String text, int maxLen) {
    return text.length > maxLen ? '${text.substring(0, maxLen)}...' : text;
  }

  void _showContextMenu(BuildContext context, ReviewItem item) {
    HapticFeedback.mediumImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(item.title),
        message: Text('总分：${item.score.toStringAsFixed(1)}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToDetail(context, item);
            },
            child: const Text('查看详情'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => ReviewFormPage(existingItem: item),
                ),
              );
            },
            child: const Text('编辑评分'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          isDefaultAction: true,
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _navigateToForm(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ReviewFormPage(),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, ReviewItem item) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ReviewDetailPage(reviewId: item.id),
      ),
    );
  }
}

