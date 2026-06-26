import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_design_tokens.dart';
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

class _SettingsPageState extends ConsumerState<SettingsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
    super.build(context);
    final state = ref.watch(reviewListProvider);
    final brightness = CupertinoTheme.brightnessOf(context);
    final items = state.items;

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg(brightness),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('设置'),
            backgroundColor:
                AppTokens.bg(brightness).withValues(alpha: 0.85),
            border: null,
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SettingsSectionTitle(title: '本地数据'),
                _InfoCard(
                  children: [
                    _InfoRow(
                      icon: CupertinoIcons.doc_text,
                      label: '评分条数',
                      value: '${items.length}',
                    ),
                    Divider(
                        color: AppTokens.sep(brightness).withValues(alpha: 0.5),
                        height: 1),
                    _InfoRow(
                      icon: CupertinoIcons.photo,
                      label: '图片数量',
                      value: '$_imageCount',
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.pagePaddingH,
                    AppTokens.spaceSM,
                    AppTokens.pagePaddingH,
                    0,
                  ),
                  child: Text(
                    '所有数据保存在本地，不经过任何服务器。',
                    style: TextStyle(fontSize: AppTokens.fontSizeCaption,
                      color: AppTokens.txt3(brightness),
                    ),
                  ),
                ),
                const _SettingsSectionTitle(title: '外观'),
                _buildThemeSelector(context),
                const _SettingsSectionTitle(title: '数据同步'),
                _ActionRow(
                  icon: CupertinoIcons.arrow_2_squarepath,
                  title: '服务器同步',
                  subtitle: '连接自建服务器，上传和拉取数据',
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const SyncSettingsPage(),
                      ),
                    );
                  },
                ),
                const _SettingsSectionTitle(title: '数据备份'),
                _ActionRow(
                  icon: CupertinoIcons.square_arrow_down,
                  title: '导出备份（ZIP）',
                  subtitle: '按分类打包评分、评价和图片为压缩包',
                  onTap: () => _exportBackup(context),
                ),
                _ActionRow(
                  icon: CupertinoIcons.square_arrow_up,
                  title: '导入备份',
                  subtitle: '从压缩包恢复数据（不覆盖已有记录）',
                  onTap: () => _importBackup(context),
                ),
                _RecycleBinCard(
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const RecycleBinPage(),
                      ),
                    );
                  },
                ),
                _DraftBoxCard(
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const DraftListPage(),
                      ),
                    );
                  },
                ),
                const _SettingsSectionTitle(
                    title: '危险操作', isDanger: true),
                _ActionRow(
                  icon: CupertinoIcons.trash,
                  title: '清空全部数据',
                  subtitle: '删除所有评分和图片，此操作不可撤销',
                  isDanger: true,
                  onTap: () => _confirmClearAll(context),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    'private_review_app v1.0.0',
                    style: TextStyle(fontSize: AppTokens.fontSizeCaption,
                      color: AppTokens.txt3(brightness),
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.space3XL),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    final currentTheme = ref.watch(themeProvider);
    final brightness = CupertinoTheme.brightnessOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.pagePaddingH),
      child: Container(
        decoration: BoxDecoration(
          color: AppTokens.card(brightness),
          borderRadius: BorderRadius.circular(AppTokens.radiusMD),
          border: Border.all(
            color: AppTokens.sep(brightness).withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          children: ThemeMode.values.map((mode) {
            final isSelected = currentTheme == mode;
            final (icon, label) = switch (mode) {
              ThemeMode.light =>
                (CupertinoIcons.sun_max, '浅色模式'),
              ThemeMode.dark =>
                (CupertinoIcons.moon, '暗色模式'),
              ThemeMode.system =>
                (CupertinoIcons.gear, '跟随系统'),
            };
            return GestureDetector(
              onTap: () =>
                  ref.read(themeProvider.notifier).setTheme(mode),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(icon,
                        size: 20,
                        color: isSelected
                            ? AppTokens.primary
                            : AppTokens.txt2(brightness)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(fontSize: AppTokens.fontSizeBody,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: AppTokens.txt(brightness),
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(CupertinoIcons.checkmark_alt,
                          size: 20, color: AppTokens.primary),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null || !mounted) return;

      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final zipPath = p.join(dir, 'private_review_backup_$now.zip');

      final repo =
          ref.read(reviewRepositoryProvider) as LocalJsonReviewRepository;
      final resultPath = await repo.exportBackup(zipPath);

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('导出成功'),
            content: Text('备份文件已保存到：\n$resultPath'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showToast('导出失败：$e');
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

      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('导入中...'),
          content: const Row(children: [
            CupertinoActivityIndicator(),
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
        Navigator.pop(context);
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('导入完成'),
            content: Text('成功导入 $count 条新记录。'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        _showToast('导入失败：$e');
      }
    }
  }

  void _confirmClearAll(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('确认清空'),
        content:
            const Text('确定要清空全部数据吗？\n\n这将删除所有评分记录和图片文件，此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _showBackupDialog(context);
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog(BuildContext context) {
    showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('备份数据'),
        content: const Text('清空数据前，是否需要备份当前数据？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, 'skip'),
            child: const Text('跳过备份'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, 'local'),
            child: const Text('备份到本地'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, 'cloud'),
            isDefaultAction: true,
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
      final dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null || !mounted) return;

      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final zipPath = p.join(dir, 'pre_clear_backup_$now.zip');

      final repo =
          ref.read(reviewRepositoryProvider) as LocalJsonReviewRepository;
      await repo.exportBackup(zipPath);

      if (mounted) {
        _showToast('备份已保存到 $zipPath');
        await _doClearAll(context);
      }
    } catch (e) {
      if (mounted) {
        _showToast('备份失败：$e');
      }
    }
  }

  Future<void> _backupToCloudThenClear(BuildContext context) async {
    final svc = ref.read(syncServiceProvider);
    if (!svc.isConfigured) {
      if (mounted) {
        _showToast('未配置云端服务器，无法备份到云端');
      }
      return;
    }

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        title: Text('云端备份中...'),
        content: Row(children: [
          CupertinoActivityIndicator(),
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
        Navigator.pop(context);
        if (verified) {
          await svc.markPulledBackup(uploadedBackup);
          _showToast('云端备份成功');
          await _doClearAll(context);
        } else {
          _showToast('云端备份失败，数据未清空');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showToast('云端备份失败：$e');
      }
    }
  }

  Future<void> _doClearAll(BuildContext context) async {
    final success = await ref.read(reviewListProvider.notifier).clearAll();
    if (mounted) {
      if (success) {
        await ref.read(syncServiceProvider).forgetPulledBackup();
        await _loadImageCount();
        _showToast('已清空全部数据');
      } else {
        _showToast('清空失败');
      }
    }
  }

  void _showToast(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  final String title;
  final bool isDanger;

  const _SettingsSectionTitle({
    required this.title,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.pagePaddingH,
        AppTokens.space2XL,
        AppTokens.pagePaddingH,
        AppTokens.spaceSM,
      ),
      child: Text(
        title,
        style: TextStyle(fontSize: AppTokens.fontSizeCaption,
          fontWeight: FontWeight.w600,
          color: isDanger
              ? AppTokens.danger
              : AppTokens.txt2(brightness),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.pagePaddingH),
      child: Container(
        decoration: BoxDecoration(
          color: AppTokens.card(brightness),
          borderRadius: BorderRadius.circular(AppTokens.radiusMD),
          border: Border.all(
            color: AppTokens.sep(brightness).withValues(alpha: 0.6),
          ),
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
    final brightness = CupertinoTheme.brightnessOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTokens.txt2(brightness)),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: AppTokens.fontSizeBody,
              color: AppTokens.txt(brightness),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontSize: AppTokens.fontSizeBody,
              fontWeight: FontWeight.w700,
              color: AppTokens.txt(brightness),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDanger;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);
    final color = isDanger ? AppTokens.danger : AppTokens.txt(brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.pagePaddingH, vertical: 3),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTokens.card(brightness),
            borderRadius: BorderRadius.circular(AppTokens.radiusMD),
            border: Border.all(
              color: isDanger
                  ? AppTokens.danger.withValues(alpha: 0.2)
                  : AppTokens.sep(brightness).withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: AppTokens.fontSizeBody,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: AppTokens.fontSizeCaption,
                        color: AppTokens.txt2(brightness),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: AppTokens.txt3(brightness),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecycleBinCard extends ConsumerWidget {
  final VoidCallback onTap;
  const _RecycleBinCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedState = ref.watch(deletedListProvider);
    final count = deletedState.items.length;
    final brightness = CupertinoTheme.brightnessOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.pagePaddingH, vertical: 3),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTokens.card(brightness),
            borderRadius: BorderRadius.circular(AppTokens.radiusMD),
            border: Border.all(
              color: AppTokens.sep(brightness).withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.tray, size: 22,
                  color: AppTokens.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '回收站',
                      style: TextStyle(fontSize: AppTokens.fontSizeBody,
                        fontWeight: FontWeight.w500,
                        color: AppTokens.primary,
                      ),
                    ),
                    Text(
                      count > 0 ? '$count 条待清理' : '暂无已删除评分',
                      style: TextStyle(fontSize: AppTokens.fontSizeCaption,
                        color: AppTokens.txt2(brightness),
                      ),
                    ),
                  ],
                ),
              ),
              if (count > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTokens.danger.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppTokens.radiusXS),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTokens.danger,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(CupertinoIcons.chevron_right,
                  size: 18, color: AppTokens.txt3(brightness)),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final brightness = CupertinoTheme.brightnessOf(context);
    final items = state.items;

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg(brightness),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('回收站'),
        backgroundColor: AppTokens.bg(brightness).withValues(alpha: 0.85),
        border: null,
      ),
      child: state.isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.tray, size: 64,
                          color: AppTokens.textWeak),
                      SizedBox(height: 12),
                      Text('回收站是空的',
                          style: TextStyle(color: AppTokens.textSecondary)),
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
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: AppTokens.pagePaddingH, vertical: 4),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTokens.card(brightness),
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusMD),
                        border: Border.all(
                          color: AppTokens.sep(brightness)
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(fontSize:
                                        AppTokens.fontSizeCardTitle,
                                    fontWeight: FontWeight.w600,
                                    color: AppTokens.txt(brightness),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item.score.toStringAsFixed(1)} 分 · 剩余 ${remaining > 0 ? '$remaining 天' : '即将过期'}',
                                  style: TextStyle(fontSize: AppTokens.fontSizeCaption,
                                    color: AppTokens.txt2(brightness),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: const Icon(CupertinoIcons.arrow_clockwise,
                                size: 20),
                            onPressed: () async {
                              final success = await ref
                                  .read(deletedListProvider.notifier)
                                  .restore(item.id);
                              if (success) {
                                ref
                                    .read(reviewListProvider.notifier)
                                    .loadAll();
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: const Icon(CupertinoIcons.trash,
                                size: 20, color: AppTokens.danger),
                            onPressed: () async {
                              final confirmed =
                                  await showCupertinoDialog<bool>(
                                context: context,
                                builder: (ctx) => CupertinoAlertDialog(
                                  title: const Text('永久删除'),
                                  content: Text(
                                      '确定永久删除「${item.title}」吗？\n此操作不可撤销。'),
                                  actions: [
                                    CupertinoDialogAction(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('取消'),
                                    ),
                                    CupertinoDialogAction(
                                      isDestructiveAction: true,
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('永久删除'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await ref
                                    .read(deletedListProvider.notifier)
                                    .permanentDelete(item.id);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _DraftBoxCard extends ConsumerWidget {
  final VoidCallback onTap;
  const _DraftBoxCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftState = ref.watch(draftListProvider);
    final count = draftState.items.length;
    final brightness = CupertinoTheme.brightnessOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.pagePaddingH, vertical: 3),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTokens.card(brightness),
            borderRadius: BorderRadius.circular(AppTokens.radiusMD),
            border: Border.all(
              color: AppTokens.sep(brightness).withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.doc_plaintext, size: 22,
                  color: AppTokens.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '草稿箱',
                      style: TextStyle(fontSize: AppTokens.fontSizeBody,
                        fontWeight: FontWeight.w500,
                        color: AppTokens.primary,
                      ),
                    ),
                    Text(
                      count > 0 ? '$count 条未完成的评分' : '暂无草稿',
                      style: TextStyle(fontSize: AppTokens.fontSizeCaption,
                        color: AppTokens.txt2(brightness),
                      ),
                    ),
                  ],
                ),
              ),
              if (count > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTokens.warning.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppTokens.radiusXS),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTokens.warning,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(CupertinoIcons.chevron_right,
                  size: 18, color: AppTokens.txt3(brightness)),
            ],
          ),
        ),
      ),
    );
  }
}
