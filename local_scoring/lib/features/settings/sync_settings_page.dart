import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../data/repositories/local_json_review_repository.dart';
import '../../providers/review_provider.dart';
import '../../services/sync_service.dart';

/// 同步设置页：服务器连接、自动备份、数据源切换、云端覆盖本地
class SyncSettingsPage extends ConsumerStatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  ConsumerState<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends ConsumerState<SyncSettingsPage> {
  final _urlCtrl = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = ref.read(syncServiceProvider);
    await svc.loadConfig();
    if (mounted) {
      setState(() {
        _urlCtrl.text = svc.baseUrl;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(syncServiceProvider);
    final cs = Theme.of(context).colorScheme;
    final connected = svc.isConfigured;

    return Scaffold(
      appBar: AppBar(title: const Text('同步设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
              // ═══ 连接状态卡片 ═══
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                builder: (_, v, _) => Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, (1 - v) * 20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: connected
                              ? [cs.primaryContainer.withValues(alpha: 0.6), cs.primaryContainer.withValues(alpha: 0.2)]
                              : [cs.surfaceContainerHighest, cs.surfaceContainerHighest.withValues(alpha: 0.5)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: connected ? Border.all(color: cs.primary.withValues(alpha: 0.2)) : null,
                      ),
                      child: Column(children: [
                        // 状态图标
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: Icon(
                            connected ? Icons.cloud_done : Icons.cloud_off,
                            key: ValueKey(connected),
                            size: 40,
                            color: connected ? cs.primary : cs.outline,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          connected ? '已连接到服务器' : '未连接',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (connected) ...[
                          const SizedBox(height: 4),
                          Text('设备 ${svc.deviceId}',
                              style: TextStyle(fontSize: 12, color: cs.outline, fontFamily: 'monospace')),
                        ],
                        const SizedBox(height: 16),

                        // 地址输入
                        TextField(
                          controller: _urlCtrl,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'https://your-server.com',
                            prefixIcon: const Icon(Icons.link, size: 18),
                            filled: true,
                            fillColor: cs.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          keyboardType: TextInputType.url,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),

                        // 按钮
                        _bigBtn(Icons.wifi_find, '测试连接', cs.primary, () => _testConnect()),
                        if (!connected)
                          _bigBtn(Icons.power_settings_new, '连接服务器', const Color(0xFF4CAF50), () => _connect()),

                        if (connected) ...[
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: _bigBtn(Icons.cloud_download, '拉取', cs.primary, () => _syncAll())),
                            const SizedBox(width: 10),
                            Expanded(child: _bigBtn(Icons.cloud_upload, '推送', const Color(0xFFFFA726), () => _pushToCloud())),
                          ]),
                          const SizedBox(height: 10),
                          _bigBtn(Icons.backup_outlined, '上传完整备份', cs.secondary, () => _uploadFullBackup()),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: _bigBtn(Icons.archive_outlined, '管理备份', cs.outline.withValues(alpha: 0.7), () => _manageBackups())),
                            const SizedBox(width: 10),
                            Expanded(child: _bigBtn(Icons.link_off, '断开连接', const Color(0xFFEF5350), () => _disconnect())),
                          ]),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ═══ 自动同步 ═══
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                builder: (_, v, _) => Opacity(
                  opacity: v,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: const Text('自动同步', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text(svc.autoBackup ? '间隔: ${svc.backupIntervalLabel}' : (connected ? '关闭' : '请先连接'),
                          style: TextStyle(fontSize: 12, color: cs.outline)),
                      value: svc.autoBackup,
                      onChanged: connected ? (v) { ref.read(syncServiceProvider).setAutoBackup(v, interval: svc.backupInterval); setState(() {}); } : null,
                    ),
                  ),
                ),
              ),
              if (svc.autoBackup)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    builder: (_, v, _) => Opacity(
                      opacity: v,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: DropdownButtonFormField<BackupInterval>(
                          initialValue: svc.backupInterval,
                          decoration: const InputDecoration(labelText: '同步间隔', border: InputBorder.none),
                          items: BackupInterval.values.map((e) => DropdownMenuItem(value: e, child: Text(switch (e) {
                                BackupInterval.oneHour => '每小时', BackupInterval.sixHours => '每 6 小时',
                                BackupInterval.twelveHours => '每 12 小时', BackupInterval.oneDay => '每天',
                                BackupInterval.oneWeek => '每周',
                              }))).toList(),
                          onChanged: (v) { if (v != null) { ref.read(syncServiceProvider).setAutoBackup(true, interval: v); setState(() {}); } },
                        ),
                      ),
                    ),
                  ),
                ),

              // ═══ 状态信息 ═══
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 16),
                AnimatedOpacity(
                  opacity: _status.isNotEmpty ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _status.startsWith('✅') ? const Color(0xFF4CAF50).withValues(alpha: 0.1) : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(_status.startsWith('✅') ? Icons.check_circle : _status.startsWith('❌') ? Icons.error : Icons.info,
                          size: 18, color: cs.outline),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_status, style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)))),
                    ]),
                  ),
                ),
              ],
            ]),
    );
  }

  Widget _bigBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    final isBusy = _busy && _activeLabel == label;
    return AnimatedScale(
      scale: isBusy ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _busy ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _busy ? color.withValues(alpha: 0.04) : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: _busy ? 0.1 : 0.18)),
            ),
            child: Center(
              child: isBusy
                  ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: color))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 20, color: color),
                      const SizedBox(width: 8),
                      Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }

  String _activeLabel = '';

  // ═══════════ 操作 ═══════════

  Future<void> _testConnect() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) { _showMsg('请输入服务器地址'); return; }
    final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _busy = true; _status = '正在测试...'; setState(() {});
    try {
      final resp = await http.get(Uri.parse('$base/api/health')).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        _status = '✅ 连接成功！服务器正常';
        // 保存地址到磁盘，下次进来直接显示
        final svc = ref.read(syncServiceProvider);
        svc.configure(baseUrl: url, token: svc.token, deviceId: svc.deviceId);
        svc.saveConfig();
      } else {
        _status = '⚠️ 状态码: ${resp.statusCode}';
      }
    } catch (_) { _status = '❌ 无法连接'; }
    _busy = false; setState(() {});
  }

  Future<void> _connect() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) { _showMsg('请输入服务器地址'); return; }
    final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _busy = true; _status = '正在连接...'; setState(() {});
    final svc = ref.read(syncServiceProvider);
    svc.configure(baseUrl: url, token: '', deviceId: '');
    try {
      final resp = await http.get(Uri.parse('$base/api/health')).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) { _status = '⚠️ 服务器不可达 (${resp.statusCode})'; _busy = false; setState(() {}); return; }
    } catch (_) { _status = '❌ 无法连接'; _busy = false; setState(() {}); return; }
    final result = await svc.register('Flutter-${DateTime.now().millisecondsSinceEpoch}');
    if (result == null) { _status = '❌ 注册失败'; _busy = false; setState(() {}); return; }
    svc.configure(baseUrl: url, token: result.token, deviceId: result.deviceId);
    await svc.saveConfig();
    _busy = false; _status = '✅ 已连接'; setState(() {});
  }

  Future<void> _syncAll() async {
    _busy = true; _activeLabel = '拉取'; _status = '正在下载备份...'; setState(() {});
    try {
      final svc = ref.read(syncServiceProvider);
      final repo = ref.read(reviewRepositoryProvider) as LocalJsonReviewRepository;
      final hasLocalReviews = (await repo.getAll()).isNotEmpty;
      final latestBackup = await svc.checkLatestBackup();
      if (hasLocalReviews && svc.isSameLatestBackup(latestBackup)) {
        _status = '✅ 已是最新备份';
        _busy = false; _activeLabel = ''; setState(() {});
        return;
      }
      final savePath = p.join(Directory.systemTemp.path, 'pull_${DateTime.now().millisecondsSinceEpoch}.zip');
      final zip = await svc.pullFullBackup(savePath);
      if (zip == null) { _status = '❌ 服务器暂无备份'; _busy = false; _activeLabel = ''; setState(() {}); return; }

      final count = await repo.importBackup(zip.path, replaceExisting: true);
      await ref.read(reviewListProvider.notifier).loadAll();
      await ref.read(templateListProvider.notifier).loadAll();
      await svc.markPulledBackup(latestBackup ?? await svc.checkLatestBackup());
      _status = '✅ 恢复完成，导入 $count 条';
      try { await zip.delete(); } catch (_) {}
    } catch (e) { _status = '❌ $e'; }
    _busy = false; _activeLabel = ''; setState(() {});
  }

  Future<void> _pushToCloud() async {
    _busy = true; _activeLabel = '推送'; _status = '正在打包并推送...'; setState(() {});
    try {
      final repo = ref.read(reviewRepositoryProvider) as LocalJsonReviewRepository;
      final zipPath = p.join(Directory.systemTemp.path, 'push_${DateTime.now().millisecondsSinceEpoch}.zip');
      await repo.exportBackup(zipPath);
      final zipFile = File(zipPath);
      if (!await zipFile.exists()) {
        _status = '❌ 打包失败：文件未生成';
        _busy = false; _activeLabel = ''; setState(() {});
        return;
      }
      final size = await zipFile.length();
      debugPrint('push: ZIP size = $size bytes, path = $zipPath');
      final uploadedBackup =
          await ref.read(syncServiceProvider).pushFullBackup(zipFile);
      final latestAfterPush =
          await ref.read(syncServiceProvider).checkLatestBackup();
      final pushedIsLatest = uploadedBackup != null &&
          uploadedBackup.isNotEmpty &&
          latestAfterPush == uploadedBackup;
      if (pushedIsLatest) {
        await ref.read(syncServiceProvider).markPulledBackup(uploadedBackup);
      } else {
        await ref.read(syncServiceProvider).forgetPulledBackup();
      }
      _status = pushedIsLatest ? '✅ 推送成功' : '❌ 推送失败：服务器未确认最新备份';
      try { await zipFile.delete(); } catch (_) {}
    } catch (e) { _status = '❌ $e'; debugPrint('push error: $e'); }
    _busy = false; _activeLabel = ''; setState(() {});
  }

  Future<void> _uploadFullBackup() async {
    _busy = true; _activeLabel = '上传完整备份'; _status = '正在打包并上传...'; setState(() {});
    try {
      final repo = ref.read(reviewRepositoryProvider) as LocalJsonReviewRepository;
      final zipPath = p.join(Directory.systemTemp.path, 'full_backup_${DateTime.now().millisecondsSinceEpoch}.zip');
      await repo.exportBackup(zipPath);
      final uploadedBackup =
          await ref.read(syncServiceProvider).uploadBackup(File(zipPath));
      final latestAfterUpload =
          await ref.read(syncServiceProvider).checkLatestBackup();
      final uploadedIsLatest = uploadedBackup != null &&
          uploadedBackup.isNotEmpty &&
          latestAfterUpload == uploadedBackup;
      if (uploadedIsLatest) {
        await ref.read(syncServiceProvider).markPulledBackup(uploadedBackup);
      } else {
        await ref.read(syncServiceProvider).forgetPulledBackup();
      }
      _status = uploadedIsLatest ? '✅ 完整备份上传成功' : '❌ 上传失败：服务器未确认最新备份';
      try { await File(zipPath).delete(); } catch (_) {}
    } catch (e) { _status = '❌ $e'; }
    _busy = false; _activeLabel = ''; setState(() {});
  }


  Future<void> _manageBackups() async {
    _busy = true; setState(() {});
    final backups = await ref.read(syncServiceProvider).listBackups();
    var list = backups;
    _busy = false; setState(() {});
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('云端备份管理'),
            content: SizedBox(
              width: double.maxFinite,
              child: list.isEmpty
                  ? const Text('暂无云端备份')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final b = list[i];
                        final name = b['filename'] as String? ?? '';
                        final info = b['createdAt'] as String? ?? '';
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.archive, size: 20),
                          title: Text(name, style: const TextStyle(fontSize: 13)),
                          subtitle: Text(info, style: const TextStyle(fontSize: 11)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            onPressed: () async {
                              final updatedList = await ref
                                  .read(syncServiceProvider)
                                  .deleteBackup(name);
                              if (updatedList != null &&
                                  !updatedList.any(
                                      (b) => b['filename'] == name)) {
                                if (ref
                                    .read(syncServiceProvider)
                                    .isSameLatestBackup(name)) {
                                  await ref
                                      .read(syncServiceProvider)
                                      .forgetPulledBackup();
                                }
                                list = updatedList;
                                setDialogState(() {});
                                _showMsg('已删除');
                              } else {
                                _showMsg('删除失败');
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
          );
        },
      ),
    );
  }

  void _disconnect() {
    ref.read(syncServiceProvider).reset();
    setState(() { _urlCtrl.clear(); _status = '已断开'; });
  }

  void _showMsg(String m) { if (mounted) { _status = m; setState(() {}); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2))); } }
}
