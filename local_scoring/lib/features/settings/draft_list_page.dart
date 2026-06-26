import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/draft_provider.dart';
import '../../data/models/draft_item.dart';
import '../review_form/review_form_page.dart';

class DraftListPage extends ConsumerStatefulWidget {
  const DraftListPage({super.key});

  @override
  ConsumerState<DraftListPage> createState() => _DraftListPageState();
}

class _DraftListPageState extends ConsumerState<DraftListPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(draftListProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(draftListProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        title: const Text('草稿箱'),
        backgroundColor: _bg(context),
        surfaceTintColor: Colors.transparent,
        actions: state.items.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: '清空草稿箱',
                  onPressed: _clearAllDrafts,
                ),
              ]
            : null,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.drafts_outlined,
                          size: 64, color: cs.outline.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text(
                        '草稿箱为空',
                        style: TextStyle(
                          fontSize: 16,
                          color: cs.outline.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: state.items.length,
                  itemBuilder: (_, i) => _DraftCard(
                    draft: state.items[i],
                    onTap: () => _openDraft(state.items[i]),
                    onDelete: () => _deleteDraft(state.items[i]),
                  ),
                ),
    );
  }

  Color _bg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF000000)
        : const Color(0xFFF2F2F7);
  }

  void _openDraft(DraftItem draft) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewFormPage(draftId: draft.id),
      ),
    );
    // 返回后刷新草稿列表
    if (mounted) {
      ref.read(draftListProvider.notifier).loadAll();
    }
  }

  void _deleteDraft(DraftItem draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除草稿'),
        content: Text('确定要删除「${draft.title.isNotEmpty ? draft.title : "无标题"}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(draftListProvider.notifier).delete(draft.id);
    }
  }

  void _clearAllDrafts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空草稿箱'),
        content: const Text('确定要清空所有草稿吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final notifier = ref.read(draftListProvider.notifier);
      final items = List.from(ref.read(draftListProvider).items);
      for (final draft in items) {
        await notifier.delete(draft.id);
      }
    }
  }
}

class _DraftCard extends StatelessWidget {
  final DraftItem draft;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DraftCard({
    required this.draft,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = DateFormat('MM-dd HH:mm').format(draft.updatedAt);
    final title = draft.title.isNotEmpty ? draft.title : '无标题';
    final preview =
        draft.reviewText.isNotEmpty ? draft.reviewText : '暂无评价内容';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9F0A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.drafts_rounded,
                        size: 20,
                        color: Color(0xFFFF9F0A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 20, color: cs.outline.withValues(alpha: 0.6)),
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  preview,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.outline,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 13, color: cs.outline),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 11, color: cs.outline),
                    ),
                    if (draft.tags.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.label_outline, size: 13, color: cs.outline),
                      const SizedBox(width: 4),
                      Text(
                        '${draft.tags.length} 个标签',
                        style: TextStyle(fontSize: 11, color: cs.outline),
                      ),
                    ],
                    if (draft.imagePaths.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.photo_outlined, size: 13, color: cs.outline),
                      const SizedBox(width: 4),
                      Text(
                        '${draft.imagePaths.length} 张图片',
                        style: TextStyle(fontSize: 11, color: cs.outline),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
