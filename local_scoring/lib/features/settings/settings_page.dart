import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/local_json_review_repository.dart';
import '../../providers/review_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _imageCount = 0;

  @override
  void initState() {
    super.initState();
    _loadImageCount();
  }

  Future<void> _loadImageCount() async {
    final repo =
        ref.read(reviewRepositoryProvider) as LocalJsonReviewRepository;
    final count = await repo.getImageCount();
    if (mounted) {
      setState(() => _imageCount = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewListProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final items = state.items;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // 数据说明
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              '本地数据',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          _InfoCard(
            children: [
              _InfoRow(
                icon: Icons.rate_review_outlined,
                label: '评分条数',
                value: '${items.length}',
              ),
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.photo_library_outlined,
                label: '图片数量',
                value: '$_imageCount',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '所有数据保存在本地，不经过任何服务器。'
              '数据文件位于应用文档目录下的 private_review_app 文件夹。'
              '图片保存为独立的图片文件，JSON 中仅保存图片路径。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // 操作
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              '数据操作',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          _ActionCard(
            icon: Icons.file_download_outlined,
            title: '导出 JSON 备份',
            subtitle: '将评分数据导出为 JSON 文件',
            onTap: () => _exportJson(context),
          ),
          const SizedBox(height: 8),
          _ActionCard(
            icon: Icons.file_upload_outlined,
            title: '导入 JSON 备份',
            subtitle: '从 JSON 文件恢复评分数据（待实现）',
            onTap: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('导入功能将在后续版本中实现')));
            },
          ),
          const SizedBox(height: 8),
          _RecycleBinCard(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecycleBinPage()),
              );
            },
          ),
          const SizedBox(height: 28),

          // 危险操作
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              '危险操作',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFFEF5350),
              ),
            ),
          ),
          _ActionCard(
            icon: Icons.delete_forever_outlined,
            title: '清空全部数据',
            subtitle: '删除所有评分和图片，此操作不可撤销',
            isDanger: true,
            onTap: () => _confirmClearAll(context),
          ),

          const SizedBox(height: 40),

          // 版本信息
          Center(
            child: Text(
              'private_review_app v1.0.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportJson(BuildContext context) async {
    try {
      final path = await ref.read(reviewListProvider.notifier).exportJson();
      if (path != null && path.isNotEmpty && mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('导出成功'),
            content: SelectableText('备份文件路径：\n$path'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('暂无数据可导出')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败：$e')));
      }
    }
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空全部数据吗？\n\n这将删除所有评分记录和图片文件，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(reviewListProvider.notifier)
                  .clearAll();
              if (mounted) {
                if (success) {
                  await _loadImageCount();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已清空全部数据')));
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('清空失败')));
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
            ),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDanger;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDanger ? const Color(0xFFEF5350) : colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDanger
                ? const Color(0xFFEF5350).withValues(alpha: 0.2)
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(title, style: TextStyle(color: color)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ========== 回收站入口卡片 ==========

class _RecycleBinCard extends ConsumerWidget {
  final VoidCallback onTap;
  const _RecycleBinCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedState = ref.watch(deletedListProvider);
    final count = deletedState.items.length;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: ListTile(
          leading: Icon(Icons.restore_from_trash_outlined,
              color: colorScheme.primary),
          title: Text('回收站', style: TextStyle(color: colorScheme.primary)),
          subtitle: Text(count > 0 ? '$count 条待清理' : '暂无已删除评分'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEF5350).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('$count',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF5350))),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: onTap,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ========== 回收站页面 ==========

class RecycleBinPage extends ConsumerStatefulWidget {
  const RecycleBinPage({super.key});

  @override
  ConsumerState<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends ConsumerState<RecycleBinPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(deletedListProvider.notifier).loadDeleted());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deletedListProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final items = state.items;

    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restore_from_trash_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('回收站是空的',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final remaining = item.deletedAt != null
                        ? 30 -
                            DateTime.now()
                                .difference(item.deletedAt!)
                                .inDays
                        : 0;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.3))),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(item.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight:
                                                  FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.score.toStringAsFixed(1)} 分 · 剩余 ${remaining > 0 ? '$remaining 天' : '即将过期'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.restore),
                              tooltip: '恢复',
                              onPressed: () async {
                                final success = await ref
                                    .read(deletedListProvider.notifier)
                                    .restore(item.id);
                                if (success) {
                                  ref
                                      .read(reviewListProvider.notifier)
                                      .loadAll();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                          content: Text('已恢复')),
                                    );
                                  }
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever,
                                  color: Color(0xFFEF5350)),
                              tooltip: '永久删除',
                              onPressed: () async {
                                final confirmed =
                                    await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('永久删除'),
                                    content: Text(
                                        '确定永久删除「${item.title}」吗？\n此操作不可撤销。'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('取消'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFEF5350),
                                        ),
                                        child: const Text('永久删除'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await ref
                                      .read(deletedListProvider.notifier)
                                      .permanentDelete(item.id);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                          content: Text('已永久删除')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
