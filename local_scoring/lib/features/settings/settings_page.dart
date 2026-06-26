import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../data/repositories/local_json_review_repository.dart';
import '../../providers/draft_provider.dart';
import '../../providers/review_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/sync_service.dart';
import 'draft_list_page.dart';
import 'sync_settings_page.dart';

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
    Future.microtask(() {
      ref.read(draftListProvider.notifier).loadAll();
    });
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

          // 主题设置
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              '外观',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          _buildThemeSelector(context),

          const SizedBox(height: 28),

          // 数据同步
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              '数据同步',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          _ActionCard(
            icon: Icons.sync,
            title: '服务器同步',
            subtitle: '连接自建服务器，上传和拉取数据',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SyncSettingsPage()),
              );
            },
          ),

          const SizedBox(height: 28),

          // 操作
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              '数据备份',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          _ActionCard(
            icon: Icons.file_download_outlined,
            title: '导出备份（ZIP）',
            subtitle: '按分类打包评分、评价和图片为压缩包',
            onTap: () => _exportBackup(context),
          ),
          const SizedBox(height: 8),
          _ActionCard(
            icon: Icons.file_upload_outlined,
            title: '导入备份',
            subtitle: '从压缩包恢复数据（不覆盖已有记录）',
            onTap: () => _importBackup(context),
          ),
          const SizedBox(height: 8),
          _RecycleBinCard(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecycleBinPage()),
              );
            },
          ),
          const SizedBox(height: 8),
          _DraftBoxCard(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DraftListPage()),
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

  Widget _buildThemeSelector(BuildContext context) {
    final currentTheme = ref.watch(themeProvider);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: Column(
          children: ThemeMode.values.map((mode) {
            final isSelected = currentTheme == mode;
            final (icon, label) = switch (mode) {
              ThemeMode.light => (Icons.light_mode, '浅色模式'),
              ThemeMode.dark => (Icons.dark_mode, '暗色模式'),
              ThemeMode.system => (Icons.settings_brightness, '跟随系统'),
            };
            return ListTile(
              leading: Icon(icon, color: isSelected ? cs.primary : cs.outline),
              title: Text(label,
                  style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal)),
              trailing: isSelected
                  ? Icon(Icons.check, color: cs.primary)
                  : null,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              onTap: () =>
                  ref.read(themeProvider.notifier).setTheme(mode),
            );
          }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      // 让用户选择导出目录
      final dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null || !mounted) return;

      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final zipPath = p.join(dir, 'private_review_backup_$now.zip');

      final repo =
          ref.read(reviewRepositoryProvider) as LocalJsonReviewRepository;
      final resultPath = await repo.exportBackup(zipPath);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('导出成功'),
            content: SelectableText('备份文件已保存到：\n$resultPath'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败：$e')));
      }
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final zipPath = result.files.single.path;
      if (zipPath == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          title: Text('导入中...'),
          content: Row(children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在恢复数据...'),
          ]),
        ),
      );

      final repo =
          ref.read(reviewRepositoryProvider) as LocalJsonReviewRepository;
      final count = await repo.importBackup(zipPath);

      await ref.read(reviewListProvider.notifier).loadAll();
      await _loadImageCount();

      if (mounted) {
        Navigator.pop(context); // dismiss loading dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('导入完成'),
            content: Text('成功导入 $count 条新记录。'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // dismiss loading if still showing
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败：$e')));
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
            onPressed: () {
              Navigator.pop(ctx);
              _showBackupDialog(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
            ),
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('备份数据'),
        content: const Text('清空数据前，是否需要备份当前数据？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'skip'),
            child: const Text('跳过备份'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'local'),
            child: const Text('备份到本地'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'cloud'),
            child: const Text('备份到云端'),
          ),
        ],
      ),
    ).then((choice) async {
      if (choice == null || !mounted) return;

      if (choice == 'local') {
        await _backupToLocalThenClear(context);
      } else if (choice == 'cloud') {
        await _backupToCloudThenClear(context);
      } else if (choice == 'skip') {
        await _doClearAll(context);
      }
    });
  }

  Future<void> _backupToLocalThenClear(BuildContext context) async {
    try {
      // 让用户选择导出目录
      final dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null || !mounted) return;

      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final zipPath = p.join(dir, 'pre_clear_backup_$now.zip');

      final repo =
          ref.read(reviewRepositoryProvider) as LocalJsonReviewRepository;
      await repo.exportBackup(zipPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份已保存到 $zipPath')),
        );
        await _doClearAll(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败：$e')),
        );
      }
    }
  }

  Future<void> _backupToCloudThenClear(BuildContext context) async {
    final svc = ref.read(syncServiceProvider);
    if (!svc.isConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未配置云端服务器，无法备份到云端')),
        );
      }
      return;
    }

    // 显示加载
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('云端备份中...'),
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('正在打包并上传数据...'),
        ]),
      ),
    );

    try {
      final repo =
          ref.read(reviewRepositoryProvider) as LocalJsonReviewRepository;

      final tempZip = p.join(
        Directory.systemTemp.path,
        'pre_clear_cloud_${DateTime.now().millisecondsSinceEpoch}.zip',
      );
      await repo.exportBackup(tempZip);
      final zipToUpload = File(tempZip);

      final uploadedBackup = await svc.pushFullBackup(zipToUpload);
      final verified = uploadedBackup != null &&
          uploadedBackup.isNotEmpty &&
          await svc.verifyBackupMatches(uploadedBackup, zipToUpload);

      try {
        await zipToUpload.delete();
      } catch (_) {}

      if (mounted) {
        Navigator.pop(context); // dismiss loading
        if (verified) {
          await svc.markPulledBackup(uploadedBackup);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('云端备份成功')),
          );
          await _doClearAll(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('云端备份失败，数据未清空')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('云端备份失败：$e')),
        );
      }
    }
  }

  Future<void> _doClearAll(BuildContext context) async {
    final success = await ref.read(reviewListProvider.notifier).clearAll();
    if (mounted) {
      if (success) {
        await ref.read(syncServiceProvider).forgetPulledBackup();
        await _loadImageCount();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已清空全部数据')));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('清空失败')));
      }
    }
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
// ========== 草稿箱入口卡片 ==========

class _DraftBoxCard extends ConsumerWidget {
  final VoidCallback onTap;
  const _DraftBoxCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftState = ref.watch(draftListProvider);
    final count = draftState.items.length;
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
          leading: Icon(Icons.drafts_outlined, color: colorScheme.primary),
          title: Text('草稿箱', style: TextStyle(color: colorScheme.primary)),
          subtitle: Text(count > 0 ? '$count 条未完成的评分' : '暂无草稿'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFF9F0A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('$count',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF9F0A))),
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