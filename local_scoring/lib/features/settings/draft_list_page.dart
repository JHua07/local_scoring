import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_design_tokens.dart';
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
    final brightness = CupertinoTheme.brightnessOf(context);

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg(brightness),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('草稿箱'),
        backgroundColor: AppTokens.bg(brightness).withValues(alpha: 0.85),
        border: null,
        trailing: state.items.isNotEmpty
            ? GestureDetector(
                onTap: _clearAllDrafts,
                child: const Icon(CupertinoIcons.delete_solid, size: 22),
              )
            : null,
      ),
      child: SafeArea(
        child: state.isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : state.items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.doc_plaintext,
                      size: 64,
                      color: AppTokens.txt3(brightness),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '草稿箱为空',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTokens.txt2(brightness),
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
      ),
    );
  }

  void _openDraft(DraftItem draft) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => ReviewFormPage(draftId: draft.id)),
    );
    if (mounted) {
      ref.read(draftListProvider.notifier).loadAll();
    }
  }

  void _deleteDraft(DraftItem draft) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除草稿'),
        content: Text(
          '确定要删除「${draft.title.isNotEmpty ? draft.title : "无标题"}」吗？',
        ),
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

    if (confirmed == true) {
      await ref.read(draftListProvider.notifier).delete(draft.id);
    }
  }

  void _clearAllDrafts() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('清空草稿箱'),
        content: const Text('确定要清空所有草稿吗？此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
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
    final brightness = CupertinoTheme.brightnessOf(context);
    final dateStr = DateFormat('MM-dd HH:mm').format(draft.updatedAt);
    final title = draft.title.isNotEmpty ? draft.title : '无标题';
    final preview = draft.reviewText.isNotEmpty ? draft.reviewText : '暂无评价内容';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTokens.card(brightness),
          borderRadius: BorderRadius.circular(AppTokens.radiusMD),
          border: Border.all(
            color: AppTokens.sep(brightness).withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTokens.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    CupertinoIcons.doc_plaintext,
                    size: 18,
                    color: AppTokens.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: AppTokens.fontSizeCardTitle,
                          color: AppTokens.txt(brightness),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppTokens.fontSizeCaption,
                          color: AppTokens.txt2(brightness),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTokens.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      CupertinoIcons.trash,
                      size: 16,
                      color: AppTokens.danger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              dateStr,
              style: TextStyle(
                fontSize: AppTokens.fontSizeSmall,
                color: AppTokens.txt2(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
