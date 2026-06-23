import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/review_item.dart';
import '../../providers/review_provider.dart';
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

class _LibraryPageState extends ConsumerState<LibraryPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _searchQuery = '';
  String? _selectedTemplateId;
  SortMode _sortMode = SortMode.time;
  bool _isTimelineMode = false;
  String? _expandedId;
  final _searchController = TextEditingController();
  final _annotationController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _annotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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

    final templates = templateState.topLevel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('评分库'),
        centerTitle: false,
        actions: [
          // 视图切换
          IconButton(
            icon: Icon(
                _isTimelineMode ? Icons.view_list : Icons.timeline),
            tooltip: _isTimelineMode ? '列表视图' : '时间线视图',
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
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        onChanged: (v) =>
                            setState(() => _searchQuery = v),
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
                          ...templates.map((t) {
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

  // ========== 列表视图 ==========
  Widget _buildList(List<ReviewItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return ReviewCard(
          item: item,
          onTap: () => _navigateToDetail(item.id),
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
        // 批注列表（所有评价的批注汇总）
        ...() {
          final allAnnots =
              item.evaluations.expand((e) => e.annotations).toList();
          if (allAnnots.isEmpty) return <Widget>[];
          return <Widget>[
            const SizedBox(height: 10),
            Text('批注记录',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...allAnnots.map((a) => AnnotationCard(
                  text: a.text,
                  createdAt: a.createdAt,
                )),
          ];
        }(),
        // 添加批注
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _annotationController,
                decoration: InputDecoration(
                  hintText: '添加批注...',
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
              onPressed: () => _addAnnotation(item),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 查看详情 / 编辑
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

  Future<void> _addAnnotation(ReviewItem item) async {
    final text = _annotationController.text.trim();
    if (text.isEmpty) return;
    final evalId = item.latestEvaluation?.id;
    if (evalId == null) return;
    final success = await ref
        .read(reviewListProvider.notifier)
        .addAnnotation(item.id, evalId, text);
    if (success && mounted) {
      _annotationController.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('批注已添加')));
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
}

enum SortMode { time, scoreDesc, scoreAsc }
