import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_design_tokens.dart';
import '../../data/models/filter_state.dart';
import '../../data/models/review_item.dart';
import '../../providers/review_provider.dart';
import '../../shared/widgets/ios_empty_state.dart';
import '../../shared/widgets/ios_review_card.dart';
import '../../shared/widgets/swipe_wrapper.dart';
import '../../shared/widgets/timeline_entry.dart';
import '../review_detail/review_detail_page.dart';
import '../review_form/review_form_page.dart';
import 'widgets/filter_bottom_sheet.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _searchQuery = '';
  String? _selectedTemplateId;
  SortMode _sortMode = SortMode.time;
  bool _isTimelineMode = false;
  String? _expandedId;
  FilterState _filterState = FilterState.empty;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final reviewState = ref.watch(reviewListProvider);
    final templateState = ref.watch(templateListProvider);
    final brightness = CupertinoTheme.brightnessOf(context);
    var items = List<ReviewItem>.from(reviewState.items);

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((r) {
        return r.title.toLowerCase().contains(q) ||
            r.reviewText.toLowerCase().contains(q) ||
            r.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    // Category filter
    if (_selectedTemplateId != null) {
      items = items.where((r) => r.category == _selectedTemplateId).toList();
    }

    // Advanced filter
    final allTemplates = templateState.templates;
    if (_filterState.isActive) {
      items = items.where((r) => _filterState.matches(r, allTemplates)).toList();
    }

    // Sort
    if (!_isTimelineMode) {
      switch (_sortMode) {
        case SortMode.time:
          items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          break;
        case SortMode.scoreDesc:
          items.sort((a, b) => b.score.compareTo(a.score));
          break;
        case SortMode.scoreAsc:
          items.sort((a, b) => a.score.compareTo(b.score));
          break;
      }
    } else {
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final topLevelTemplates = templateState.topLevel;

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg(brightness),
      child: reviewState.isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : CustomScrollView(
              slivers: [
                CupertinoSliverNavigationBar(
                  largeTitle: const Text('评分库'),
                  backgroundColor:
                      AppTokens.bg(brightness).withValues(alpha: 0.85),
                  border: null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(
                          _isTimelineMode
                              ? CupertinoIcons.list_bullet
                              : CupertinoIcons.clock,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _isTimelineMode = !_isTimelineMode),
                      ),
                      if (!_isTimelineMode)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: const Icon(CupertinoIcons.sort_down, size: 20),
                          onPressed: () => _showSortActionSheet(),
                        ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTokens.pagePaddingH,
                          4,
                          AppTokens.pagePaddingH,
                          8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoSearchTextField(
                                controller: _searchController,
                                placeholder: '搜索名称、评价或标签',
                                onChanged: (v) =>
                                    setState(() => _searchQuery = v),
                                onSuffixTap: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _showFilterSheet,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTokens.elevated(brightness),
                                  borderRadius: BorderRadius.circular(
                                      AppTokens.radiusSM),
                                ),
                                child: Icon(
                                  CupertinoIcons.slider_horizontal_3,
                                  size: 20,
                                  color: _filterState.isActive
                                      ? AppTokens.primary
                                      : AppTokens.txt2(brightness),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Category chips
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            _buildChip('全部', _selectedTemplateId == null, () {
                              setState(() => _selectedTemplateId = null);
                            }),
                            ...topLevelTemplates.map((t) {
                              return _buildChip(
                                '${t.icon} ${t.name}',
                                _selectedTemplateId == t.id,
                                () {
                                  setState(() =>
                                      _selectedTemplateId = t.id);
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Content
                      if (items.isEmpty &&
                          _searchQuery.isEmpty &&
                          _selectedTemplateId == null)
                        const IosEmptyState(
                          icon: CupertinoIcons.archivebox,
                          title: '还没有记录',
                          subtitle: '先给最近一次体验打个分吧。',
                        )
                      else if (items.isEmpty)
                        const IosEmptyState(
                          icon: CupertinoIcons.search,
                          title: '没有找到匹配的评分',
                          subtitle: '试试其他关键词或筛选条件。',
                        )
                      else if (_isTimelineMode)
                        _buildTimeline(items)
                      else
                        _buildList(items),
                      const SizedBox(height: AppTokens.space3XL),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    final brightness = CupertinoTheme.brightnessOf(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTokens.primary
              : AppTokens.elevated(brightness),
          borderRadius: BorderRadius.circular(AppTokens.radiusFull),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: AppTokens.fontSizeCaption,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? AppTokens.textOnPrimary
                : AppTokens.txt(brightness),
          ),
        ),
      ),
    );
  }

  void _showSortActionSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('排序方式'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _sortMode = SortMode.time);
              Navigator.pop(ctx);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_sortMode == SortMode.time)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(CupertinoIcons.checkmark_alt, size: 18,
                        color: AppTokens.primary),
                  ),
                const Text('按时间'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _sortMode = SortMode.scoreDesc);
              Navigator.pop(ctx);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_sortMode == SortMode.scoreDesc)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(CupertinoIcons.checkmark_alt, size: 18,
                        color: AppTokens.primary),
                  ),
                const Text('按分数 ↓'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _sortMode = SortMode.scoreAsc);
              Navigator.pop(ctx);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_sortMode == SortMode.scoreAsc)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(CupertinoIcons.checkmark_alt, size: 18,
                        color: AppTokens.primary),
                  ),
                const Text('按分数 ↑'),
              ],
            ),
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

  void _showFilterSheet() {
    final templateState = ref.read(templateListProvider);
    final reviewState = ref.read(reviewListProvider);
    final selectedTemplate = _selectedTemplateId != null
        ? templateState.templates
            .where((t) => t.id == _selectedTemplateId)
            .firstOrNull
        : null;
    final maxEvalCount = reviewState.items
        .map((r) => r.evaluations.length)
        .fold(0, (a, b) => a > b ? a : b);

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Material(
        color: Colors.transparent,
        child: FilterBottomSheet(
          initialFilter: _filterState,
          selectedTemplate: selectedTemplate,
          maxEvalCount: maxEvalCount,
          onChanged: (filter) => setState(() => _filterState = filter),
        ),
      ),
    );
  }

  Widget _buildList(List<ReviewItem> items) {
    return Column(
      children: items.map((item) {
        return SwipeActionWrapper(
          onDelete: () async {
            final confirmed = await showCupertinoDialog<bool>(
              context: context,
              builder: (ctx) => CupertinoAlertDialog(
                title: const Text('删除评分'),
                content: Text('确认删除「${item.title}」？\n删除后可在回收站恢复。'),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消'),
                  ),
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
            if (confirmed == true && mounted) {
              await ref
                  .read(reviewListProvider.notifier)
                  .softDeleteItem(item.id);
            }
          },
          onEdit: () => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => ReviewFormPage(existingItem: item),
            ),
          ),
          child: IosReviewCard(
            item: item,
            onTap: () => _navigateToDetail(item.id),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeline(List<ReviewItem> items) {
    final groups = <String, List<ReviewItem>>{};
    for (final item in items) {
      final key = '${item.createdAt.year}-${item.createdAt.month}';
      groups.putIfAbsent(key, () => []).add(item);
    }
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: sortedKeys.map((key) {
        final parts = key.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final groupItems = groups[key]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TimelineMonthHeader(year: year, month: month),
            ...groupItems.map((item) {
              final isExpanded = _expandedId == item.id;
              return SwipeActionWrapper(
                buttonHeight: 44,
                onDelete: () async {
                  final confirmed = await showCupertinoDialog<bool>(
                    context: context,
                    builder: (ctx) => CupertinoAlertDialog(
                      title: const Text('删除评分'),
                      content:
                          Text('确认删除「${item.title}」？\n删除后可在回收站恢复。'),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消'),
                        ),
                        CupertinoDialogAction(
                          isDestructiveAction: true,
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted) {
                    await ref
                        .read(reviewListProvider.notifier)
                        .softDeleteItem(item.id);
                  }
                },
                onEdit: () => Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => ReviewFormPage(existingItem: item),
                  ),
                ),
                child: TimelineEntry(
                  item: item,
                  isExpanded: isExpanded,
                  onTap: () {
                    setState(() {
                      _expandedId = isExpanded ? null : item.id;
                    });
                  },
                  expandedContent: isExpanded
                      ? _TimelineEvalList(item: item, onNavigate: () => _navigateToDetail(item.id))
                      : null,
                ),
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  void _navigateToForm() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ReviewFormPage(),
      ),
    );
  }

  void _navigateToDetail(String id) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ReviewDetailPage(reviewId: id),
      ),
    );
  }
}

/// 时间线展开后的评价列表（兼容旧版）
class _TimelineEvalList extends StatelessWidget {
  final ReviewItem item;
  final VoidCallback onNavigate;

  const _TimelineEvalList({
    required this.item,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);
    final evals = item.evaluations;
    if (evals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _miniBadge(
                item.worth == 'worth'
                    ? '值得'
                    : item.worth == 'not_worth'
                        ? '不值'
                        : '一般',
                item.worth == 'worth'
                    ? AppTokens.success
                    : item.worth == 'not_worth'
                        ? AppTokens.danger
                        : AppTokens.textSecondary),
            if (item.revisit) _miniBadge('会再来', const Color(0xFF26A69A)),
            if (item.recommendToFriends)
              _miniBadge('推荐', AppTokens.purple),
          ],
        ),
        if (item.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: item.tags.map((t) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTokens.elevated(brightness),
                  borderRadius:
                      BorderRadius.circular(AppTokens.radiusXS),
                ),
                child: Text(
                  t,
                  style: TextStyle(fontSize: 11,
                    color: AppTokens.txt2(brightness),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          '历史评价',
          style: TextStyle(fontSize: AppTokens.fontSizeCaption,
            fontWeight: FontWeight.w600,
            color: AppTokens.txt(brightness),
          ),
        ),
        const SizedBox(height: 8),
        ...evals.asMap().entries.map((entry) {
          final e = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTokens.elevated(brightness),
              borderRadius:
                  BorderRadius.circular(AppTokens.radiusSM),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(CupertinoIcons.clock,
                        size: 13, color: AppTokens.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${e.createdAt.month.toString().padLeft(2, '0')}-${e.createdAt.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11,
                          color: AppTokens.textSecondary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTokens.scoreColor(e.score)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${e.score.toStringAsFixed(1)} 分',
                        style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTokens.scoreColor(e.score),
                        ),
                      ),
                    ),
                  ],
                ),
                if (e.reviewText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    e.reviewText,
                    style: TextStyle(fontSize: 13,
                      color: AppTokens.txt2(brightness),
                    ),
                  ),
                ],
                if (e.imagePaths.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: e.imagePaths.map((p) {
                      final f = File(p);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: f.existsSync()
                              ? Image.file(f, fit: BoxFit.cover)
                              : const Icon(CupertinoIcons.photo,
                                  size: 16,
                                  color: AppTokens.textSecondary),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          );
        }),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.arrow_right, size: 16),
                  SizedBox(width: 4),
                  Text('查看详情', style: TextStyle(fontSize: 13)),
                ],
              ),
              onPressed: onNavigate,
            ),
          ],
        ),
      ],
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

enum SortMode { time, scoreDesc, scoreAsc }

