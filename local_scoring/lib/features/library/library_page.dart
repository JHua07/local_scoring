import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/evaluation.dart';
import '../../data/models/filter_state.dart';
import '../../data/models/review_item.dart';
import '../../providers/review_provider.dart';
import 'widgets/filter_bottom_sheet.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/review_card.dart';
import '../../shared/widgets/swipe_wrapper.dart';
import '../../shared/widgets/timeline_entry.dart';
import '../review_detail/review_detail_page.dart';
import '../review_form/review_form_page.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  String _searchQuery = '';
  String? _selectedTemplateId;
  SortMode _sortMode = SortMode.time;
  bool _isTimelineMode = false;
  String? _expandedId;
  FilterState _filterState = FilterState.empty;
  final _evalTextController = TextEditingController(); // 新增评价输入
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _evalTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(reviewListProvider);
    final templateState = ref.watch(templateListProvider);
    final colorScheme = Theme.of(context).colorScheme;
    var items = List<ReviewItem>.from(reviewState.items);

    // 搜索
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((r) {
        return r.title.toLowerCase().contains(q) ||
            r.reviewText.toLowerCase().contains(q) ||
            r.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    // 模板筛选
    if (_selectedTemplateId != null) {
      items =
          items.where((r) => r.category == _selectedTemplateId).toList();
    }

    // 高级筛选
    final allTemplates = templateState.templates;
    if (_filterState.isActive) {
      items = items
          .where((r) => _filterState.matches(r, allTemplates))
          .toList();
    }

    // 排序（时间线模式始终按时间降序）
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('评分库'),
        centerTitle: false,
        actions: [
          // 视图切换
          TextButton.icon(
            icon: Icon(
                _isTimelineMode ? Icons.view_list : Icons.timeline),
            label: Text(_isTimelineMode ? '列表' : '时间线'),
            onPressed: () =>
                setState(() => _isTimelineMode = !_isTimelineMode),
          ),
          if (!_isTimelineMode)
            PopupMenuButton<SortMode>(
              icon: const Icon(Icons.sort),
              tooltip: '排序方式',
              onSelected: (mode) => setState(() => _sortMode = mode),
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: SortMode.time, child: Text('按时间')),
                const PopupMenuItem(
                    value: SortMode.scoreDesc, child: Text('按分数↓')),
                const PopupMenuItem(
                    value: SortMode.scoreAsc, child: Text('按分数↑')),
              ],
            ),
        ],
      ),
      body: reviewState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty &&
                  _searchQuery.isEmpty &&
                  _selectedTemplateId == null
              ? EmptyState(
                  icon: Icons.library_books_outlined,
                  title: '评分库是空的',
                  subtitle: '添加你的第一条评分吧。',
                  action: FilledButton.icon(
                    onPressed: () => _navigateToForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('新增评分'),
                  ),
                )
              : Column(
                  children: [
                    // 搜索栏
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: '搜索名称、评价、标签...',
                                prefixIcon:
                                    const Icon(Icons.search, size: 20),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear,
                                            size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() =>
                                              _searchQuery = '');
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                              ),
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterButton(colorScheme),
                        ],
                      ),
                    ),
                    // 模板筛选
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 6),
                            child: FilterChip(
                              label: const Text('全部'),
                              selected: _selectedTemplateId == null,
                              onSelected: (_) => setState(
                                  () => _selectedTemplateId = null),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              side: BorderSide.none,
                            ),
                          ),
                          ...topLevelTemplates.map((t) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 6),
                              child: FilterChip(
                                avatar: Text(t.icon,
                                    style: const TextStyle(
                                        fontSize: 14)),
                                label: Text(t.name),
                                selected:
                                    _selectedTemplateId == t.id,
                                onSelected: (_) => setState(() =>
                                    _selectedTemplateId = t.id),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                side: BorderSide.none,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    // 列表 / 时间线
                    Expanded(
                      child: items.isEmpty
                          ? const EmptyState(
                              icon: Icons.search_off,
                              title: '没有找到匹配的评分',
                              subtitle: '试试其他关键词或筛选条件。',
                            )
                          : _isTimelineMode
                              ? _buildTimeline(items, colorScheme)
                              : _buildList(items),
                    ),
                  ],
                ),
    );
  }

  // ========== 筛选按钮 ==========
  Widget _buildFilterButton(ColorScheme colorScheme) {
    return Badge(
      isLabelVisible: _filterState.isActive,
      child: IconButton.filledTonal(
        icon: const Icon(Icons.filter_list, size: 20),
        onPressed: () => _showFilterSheet(),
        style: IconButton.styleFrom(
          backgroundColor:
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FilterBottomSheet(
        initialFilter: _filterState,
        selectedTemplate: selectedTemplate,
        maxEvalCount: maxEvalCount,
        onChanged: (filter) => setState(() => _filterState = filter),
      ),
    );
  }

  // ========== 列表视图 ==========
  Widget _buildList(List<ReviewItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return SwipeActionWrapper(
          onDelete: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('删除评分'),
                content: Text('确认删除「${item.title}」？\n删除后可在回收站恢复。'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('删除')),
                ],
              ),
            );
            if (confirmed == true && mounted) {
              await ref.read(reviewListProvider.notifier).softDeleteItem(item.id);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已移入回收站')));
            }
          },
          onEdit: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReviewFormPage(existingItem: item))),
          child: ReviewCard(
            item: item,
            onTap: () => _navigateToDetail(item.id),
          ),
        );
      },
    );
  }

  // ========== 时间线视图 ==========
  Widget _buildTimeline(
      List<ReviewItem> items, ColorScheme colorScheme) {
    // 按月分组
    final groups = <String, List<ReviewItem>>{};
    for (final item in items) {
      final key = '${item.createdAt.year}-${item.createdAt.month}';
      groups.putIfAbsent(key, () => []).add(item);
    }
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: sortedKeys.length,
      itemBuilder: (_, groupIndex) {
        final key = sortedKeys[groupIndex];
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
                buttonHeight: 44, // 匹配未展开面板高度
                onDelete: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('删除评分'),
                      content: Text('确认删除「${item.title}」？\n删除后可在回收站恢复。'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                        FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('删除')),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted) {
                    await ref.read(reviewListProvider.notifier).softDeleteItem(item.id);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已移入回收站')));
                  }
                },
                onEdit: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReviewFormPage(existingItem: item))),
                child: TimelineEntry(
                  item: item,
                  isExpanded: isExpanded,
                  onTap: () { setState(() { _expandedId = isExpanded ? null : item.id; }); },
                  expandedContent: _buildExpandedContent(item, colorScheme),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildExpandedContent(
      ReviewItem item, ColorScheme colorScheme) {
    final evals = item.evaluations;
    if (evals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 快速信息
        Row(
          children: [
            _miniBadge(
                item.worth == 'worth'
                    ? '值得'
                    : item.worth == 'not_worth'
                        ? '不值'
                        : '一般',
                item.worth == 'worth'
                    ? const Color(0xFF4CAF50)
                    : item.worth == 'not_worth'
                        ? const Color(0xFFEF5350)
                        : Colors.grey),
            if (item.revisit)
              _miniBadge('会再来', const Color(0xFF26A69A)),
            if (item.recommendToFriends)
              _miniBadge('推荐', const Color(0xFF7E57C2)),
          ],
        ),
        if (item.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: item.tags
                .map((t) => Chip(
                      label: Text(t, style: const TextStyle(fontSize: 11)),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      side: BorderSide.none,
                      backgroundColor:
                          colorScheme.secondaryContainer,
                    ))
                .toList(),
          ),
        ],
        // 历史评价列表（无批注）
        const SizedBox(height: 12),
        Text('历史评价',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...evals.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final isLatest = i == 0;
          return InkWell(
            onTap: () => _navigateToDetailWithEval(item.id, e.id),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 评价头部：日期 + 分数 + 最新标记
                Row(children: [
                  Icon(Icons.access_time, size: 13, color: colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    '${e.createdAt.month.toString().padLeft(2, '0')}-${e.createdAt.day.toString().padLeft(2, '0')} ${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 11, color: colorScheme.outline),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _scoreColor(e.score).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${e.score.toStringAsFixed(1)} 分',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _scoreColor(e.score))),
                  ),
                  if (isLatest) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                      child: Text('最新', style: TextStyle(fontSize: 9, color: colorScheme.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
                // 评价文字
                if (e.reviewText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(e.reviewText, style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.7))),
                ],
                // 评价图片
                if (e.imagePaths.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 4, runSpacing: 4, children: e.imagePaths.map((p) {
                    final f = File(p);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(width: 36, height: 36,
                          child: f.existsSync() ? Image.file(f, fit: BoxFit.cover) : Icon(Icons.broken_image, size: 16, color: colorScheme.outline)),
                    );
                  }).toList()),
                ],
              ]),
            ),
          );
        }),
        // 新增评价输入
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _evalTextController,
                decoration: InputDecoration(
                  hintText: '新增评价...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.send, size: 18),
              onPressed: () => _addEvaluation(item),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 查看详情
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => _navigateToDetail(item.id),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('查看详情'),
            ),
          ],
        ),
      ],
    );
  }

  Color _scoreColor(double s) {
    if (s >= 8) return const Color(0xFF4CAF50);
    if (s >= 6) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }

  Widget _miniBadge(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  /// 快速新增一条评价（仅文字，评分默认 5.0）
  Future<void> _addEvaluation(ReviewItem item) async {
    final text = _evalTextController.text.trim();
    if (text.isEmpty) return;
    final eval = Evaluation(
      id: const Uuid().v4(),
      score: 5.0,
      reviewText: text,
      dimensions: Map.from(item.dimensions),
      createdAt: DateTime.now(),
    );
    final success = await ref
        .read(reviewListProvider.notifier)
        .addEvaluation(item.id, eval);
    if (success && mounted) {
      _evalTextController.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('评价已添加')));
    }
  }

  void _navigateToForm() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ReviewFormPage()));
  }

  void _navigateToDetail(String id) {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReviewDetailPage(reviewId: id)));
  }

  /// 跳转详情页并定位到指定评价
  void _navigateToDetailWithEval(String reviewId, String evalId) {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReviewDetailPage(reviewId: reviewId, scrollToEvalId: evalId)));
  }
}

enum SortMode { time, scoreDesc, scoreAsc }
