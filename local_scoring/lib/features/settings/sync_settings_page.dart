import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/theme/app_design_tokens.dart';
import '../../data/repositories/local_json_review_repository.dart';
import '../../providers/review_provider.dart';
import '../../services/sync_service.dart';

class SyncSettingsPage extends ConsumerStatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  ConsumerState<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends ConsumerState<SyncSettingsPage> {
  final _urlCtrl = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String _activeLabel = '';
  String _status = '';

  // Use AppTokens for colors
  Color get _blue => AppTokens.primary;
  Color get _green => AppTokens.success;
  Color get _orange => AppTokens.warning;
  Color get _red => AppTokens.danger;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = ref.read(syncServiceProvider);
    await svc.loadConfig();
    if (!mounted) return;
    setState(() {
      _urlCtrl.text = svc.baseUrl;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(syncServiceProvider);
    final connected = svc.isConfigured;
    final brightness = CupertinoTheme.brightnessOf(context);

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg(brightness),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('同步设置'),
        backgroundColor: AppTokens.bg(brightness).withValues(alpha: 0.85),
        border: null,
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _connectionHeader(svc, connected),
                  if (connected) ...[
                    const SizedBox(height: 22),
                    _sectionLabel('同步'),
                    _section([
                      _tile(
                        icon: Icons.cloud_download_rounded,
                        tint: _blue,
                        title: '拉取最新备份',
                        subtitle: '用云端最新 ZIP 覆盖本地存档',
                        busyLabel: '拉取',
                        onTap: _syncAll,
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.cloud_upload_rounded,
                        tint: _orange,
                        title: '推送当前存档',
                        subtitle: '上传当前完整数据并生成快照',
                        busyLabel: '推送',
                        onTap: _pushToCloud,
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.archive_rounded,
                        tint: _green,
                        title: '上传完整备份',
                        subtitle: '手动生成并上传一个完整 ZIP',
                        busyLabel: '上传完整备份',
                        onTap: _uploadFullBackup,
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.folder_copy_rounded,
                        tint: _blue,
                        title: '管理云端备份',
                        subtitle: '查看 data/backups 目录中的 ZIP',
                        onTap: _manageBackups,
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.troubleshoot_rounded,
                        tint: _green,
                        title: '同步诊断',
                        subtitle: '检查服务器版本、备份目录和最新快照',
                        busyLabel: '诊断',
                        onTap: _showDiagnostics,
                      ),
                    ]),
                  ],
                  const SizedBox(height: 22),
                  _sectionLabel('自动同步'),
                  _section([
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.fromLTRB(14, 2, 10, 2),
                        secondary: _iconBubble(
                          Icons.schedule_rounded,
                          connected ? _green : Colors.grey,
                        ),
                        title: const Text(
                          '自动同步',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          svc.autoBackup
                              ? '间隔：${svc.backupIntervalLabel}'
                              : (connected ? '关闭' : '请先连接服务器'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTokens.txt2(
                              CupertinoTheme.brightnessOf(context),
                            ),
                          ),
                        ),
                        value: svc.autoBackup,
                        activeThumbColor: _green,
                        onChanged: connected
                            ? (v) {
                                ref
                                    .read(syncServiceProvider)
                                    .setAutoBackup(
                                      v,
                                      interval: svc.backupInterval,
                                    );
                                setState(() {});
                              }
                            : null,
                      ),
                    ),
                    if (svc.autoBackup) ...[
                      _divider(indent: 64),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: Material(
                          color: Colors.transparent,
                          child: DropdownButtonFormField<BackupInterval>(
                            initialValue: svc.backupInterval,
                            decoration: const InputDecoration(
                              labelText: '同步间隔',
                              border: InputBorder.none,
                            ),
                            items: BackupInterval.values
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(_intervalLabel(e)),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              ref
                                  .read(syncServiceProvider)
                                  .setAutoBackup(true, interval: v);
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                    ],
                  ]),
                  if (connected) ...[
                    const SizedBox(height: 22),
                    _sectionLabel('连接'),
                    _section([
                      _tile(
                        icon: Icons.link_off_rounded,
                        tint: _red,
                        title: '断开连接',
                        subtitle: '清除本机保存的服务器配置',
                        showChevron: false,
                        onTap: _disconnect,
                      ),
                    ]),
                  ],
                  if (_status.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _statusPanel(),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _connectionHeader(SyncService svc, bool connected) {
    final brightness = CupertinoTheme.brightnessOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: _groupColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTokens.sep(brightness).withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _iconBubble(
                connected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                connected ? _green : Colors.grey,
                size: 52,
                iconSize: 27,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected ? '已连接到服务器' : '未连接',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connected ? '设备 ${svc.deviceId}' : '输入服务器地址后连接',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTokens.txt2(brightness),
                        fontFamily: connected ? 'monospace' : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _compactUrlField(),
          const SizedBox(height: 10),
          _headerAction(
            icon: Icons.network_check_rounded,
            tint: _blue,
            title: '测试连接',
            onTap: _testConnect,
          ),
          if (!connected) ...[
            const SizedBox(height: 8),
            _headerAction(
              icon: Icons.power_settings_new_rounded,
              tint: _green,
              title: '连接服务器',
              onTap: _connect,
            ),
          ],
        ],
      ),
    );
  }

  Widget _compactUrlField() {
    final brightness = CupertinoTheme.brightnessOf(context);
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTokens.sep(brightness).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _busy
                ? CupertinoIcons.arrow_2_squarepath
                : Icons.network_check_rounded,
            size: 18,
            color: _blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: TextField(
                controller: _urlCtrl,
                style: const TextStyle(fontSize: 14, letterSpacing: 0),
                decoration: const InputDecoration(
                  hintText: 'https://your-server.com',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  filled: false,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                ),
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerAction({
    required IconData icon,
    required Color tint,
    required String title,
    required VoidCallback onTap,
  }) {
    final brightness = CupertinoTheme.brightnessOf(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: tint),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_busy)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: tint),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTokens.txt2(brightness),
                  size: 21,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTokens.txt2(CupertinoTheme.brightnessOf(context)),
        ),
      ),
    );
  }

  Widget _section(List<Widget> children) {
    final brightness = CupertinoTheme.brightnessOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _groupColor(context),
          border: Border.all(
            color: AppTokens.sep(brightness).withValues(alpha: 0.32),
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color tint,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? busyLabel,
    bool showChevron = true,
  }) {
    final busy = _busy && (busyLabel == null || _activeLabel == busyLabel);
    final brightness = CupertinoTheme.brightnessOf(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              _iconBubble(icon, tint),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTokens.txt2(brightness),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: tint),
                )
              else if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTokens.txt2(brightness),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider({double indent = 58}) {
    final brightness = CupertinoTheme.brightnessOf(context);
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Container(
        height: 0.6,
        color: AppTokens.sep(brightness).withValues(alpha: 0.5),
      ),
    );
  }

  Widget _iconBubble(
    IconData icon,
    Color color, {
    double size = 34,
    double iconSize = 19,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }

  Widget _statusPanel() {
    final isOk = _status.startsWith('✅');
    final isError = _status.startsWith('❌');
    final color = isOk ? _green : (isError ? _red : _blue);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(
            isOk
                ? Icons.check_circle_rounded
                : isError
                ? Icons.error_rounded
                : Icons.info_rounded,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _status,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Color _pageBackground(BuildContext context) {
    return AppTokens.bg(CupertinoTheme.brightnessOf(context));
  }

  Color _groupColor(BuildContext context) {
    return AppTokens.card(CupertinoTheme.brightnessOf(context));
  }

  String _intervalLabel(BackupInterval interval) => switch (interval) {
    BackupInterval.oneHour => '每小时',
    BackupInterval.sixHours => '每 6 小时',
    BackupInterval.twelveHours => '每 12 小时',
    BackupInterval.oneDay => '每天',
    BackupInterval.oneWeek => '每周',
  };

  Future<void> _testConnect() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      _showMsg('请输入服务器地址');
      return;
    }
    final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _busy = true;
    _status = '正在测试...';
    setState(() {});
    try {
      final resp = await http
          .get(
            Uri.parse(
              '$base/api/health?_t=${DateTime.now().millisecondsSinceEpoch}',
            ),
            headers: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        _status = '✅ 连接成功，服务器正常';
        final svc = ref.read(syncServiceProvider);
        svc.configure(baseUrl: url, token: svc.token, deviceId: svc.deviceId);
        await svc.saveConfig();
      } else {
        _status = '⚠️ 状态码: ${resp.statusCode}';
      }
    } catch (_) {
      _status = '❌ 无法连接';
    }
    _busy = false;
    setState(() {});
  }

  Future<void> _connect() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      _showMsg('请输入服务器地址');
      return;
    }
    final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _busy = true;
    _status = '正在连接...';
    setState(() {});
    final svc = ref.read(syncServiceProvider);
    svc.configure(baseUrl: url, token: '', deviceId: '');
    try {
      final resp = await http
          .get(
            Uri.parse(
              '$base/api/health?_t=${DateTime.now().millisecondsSinceEpoch}',
            ),
            headers: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        _status = '⚠️ 服务器不可达 (${resp.statusCode})';
        _busy = false;
        setState(() {});
        return;
      }
    } catch (_) {
      _status = '❌ 无法连接';
      _busy = false;
      setState(() {});
      return;
    }
    final result = await svc.register(
      'Flutter-${DateTime.now().millisecondsSinceEpoch}',
    );
    if (result == null) {
      _status = '❌ 注册失败';
      _busy = false;
      setState(() {});
      return;
    }
    svc.configure(baseUrl: url, token: result.token, deviceId: result.deviceId);
    await svc.saveConfig();
    _busy = false;
    _status = '✅ 已连接';
    setState(() {});
  }

  Future<void> _syncAll() async {
    _busy = true;
    _activeLabel = '拉取';
    _status = '正在下载备份...';
    setState(() {});
    try {
      final svc = ref.read(syncServiceProvider);
      final latestBackup = await svc.checkLatestBackup();
      await _restoreBackup(latestBackup);
    } catch (e) {
      _status = '❌ $e';
    }
    _busy = false;
    _activeLabel = '';
    setState(() {});
  }

  Future<void> _restoreBackup(String? backupName) async {
    final svc = ref.read(syncServiceProvider);
    final repo =
        ref.read(reviewRepositoryProvider) as LocalJsonReviewRepository;
    final savePath = p.join(
      Directory.systemTemp.path,
      'pull_${DateTime.now().millisecondsSinceEpoch}.zip',
    );
    final zip = await svc.pullFullBackup(savePath, filename: backupName);
    if (zip == null) {
      _status = '❌ 服务器暂无备份';
      return;
    }

    final count = await repo.importBackup(zip.path, replaceExisting: true);
    await ref.read(reviewListProvider.notifier).loadAll();
    await ref.read(templateListProvider.notifier).loadAll();
    await svc.markPulledBackup(backupName ?? await svc.checkLatestBackup());
    _status = '✅ 恢复完成，导入 $count 条';
    try {
      await zip.delete();
    } catch (_) {}
  }

  Future<void> _pushToCloud() async {
    _busy = true;
    _activeLabel = '推送';
    _status = '正在打包并推送...';
    setState(() {});
    try {
      final repo =
          ref.read(reviewRepositoryProvider) as LocalJsonReviewRepository;
      final zipPath = p.join(
        Directory.systemTemp.path,
        'push_${DateTime.now().millisecondsSinceEpoch}.zip',
      );
      await repo.exportBackup(zipPath);
      final zipFile = File(zipPath);
      if (!await zipFile.exists()) {
        _status = '❌ 打包失败：文件未生成';
        _busy = false;
        _activeLabel = '';
        setState(() {});
        return;
      }
      final uploadedBackup = await ref
          .read(syncServiceProvider)
          .pushFullBackup(zipFile);
      final pushedIsSaved =
          uploadedBackup != null &&
          uploadedBackup.isNotEmpty &&
          await ref
              .read(syncServiceProvider)
              .verifyBackupMatches(uploadedBackup, zipFile);
      if (pushedIsSaved) {
        await ref.read(syncServiceProvider).markPulledBackup(uploadedBackup);
      } else {
        await ref.read(syncServiceProvider).forgetPulledBackup();
      }
      _status = pushedIsSaved ? '✅ 推送成功' : '❌ 推送失败：服务器未保存新备份';
      try {
        await zipFile.delete();
      } catch (_) {}
    } catch (e) {
      _status = '❌ $e';
      debugPrint('push error: $e');
    }
    _busy = false;
    _activeLabel = '';
    setState(() {});
  }

  Future<void> _uploadFullBackup() async {
    _busy = true;
    _activeLabel = '上传完整备份';
    _status = '正在打包并上传...';
    setState(() {});
    try {
      final repo =
          ref.read(reviewRepositoryProvider) as LocalJsonReviewRepository;
      final zipPath = p.join(
        Directory.systemTemp.path,
        'full_backup_${DateTime.now().millisecondsSinceEpoch}.zip',
      );
      await repo.exportBackup(zipPath);
      final zipFile = File(zipPath);
      final uploadedBackup = await ref
          .read(syncServiceProvider)
          .uploadBackup(zipFile);
      final uploadedIsSaved =
          uploadedBackup != null &&
          uploadedBackup.isNotEmpty &&
          await ref
              .read(syncServiceProvider)
              .verifyBackupMatches(uploadedBackup, zipFile);
      if (uploadedIsSaved) {
        await ref.read(syncServiceProvider).markPulledBackup(uploadedBackup);
      } else {
        await ref.read(syncServiceProvider).forgetPulledBackup();
      }
      _status = uploadedIsSaved ? '✅ 完整备份上传成功' : '❌ 上传失败：服务器未保存新备份';
      try {
        await zipFile.delete();
      } catch (_) {}
    } catch (e) {
      _status = '❌ $e';
    }
    _busy = false;
    _activeLabel = '';
    setState(() {});
  }

  Future<void> _showDiagnostics() async {
    _busy = true;
    _activeLabel = '诊断';
    _status = '正在诊断同步接口...';
    setState(() {});
    final diagnostics = await ref.read(syncServiceProvider).runDiagnostics();
    _busy = false;
    _activeLabel = '';
    _status = diagnostics.healthOk ? '✅ 诊断完成' : '❌ 诊断失败';
    setState(() {});
    if (!mounted) return;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        decoration: BoxDecoration(
          color: _groupColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _iconBubble(
                  diagnostics.healthOk
                      ? Icons.check_circle_rounded
                      : Icons.error_rounded,
                  diagnostics.healthOk ? _green : _red,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    diagnostics.healthOk ? '同步接口正常' : '同步接口异常',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _diagnosticLine(
              'HTTP',
              diagnostics.healthStatus?.toString() ?? '-',
            ),
            _diagnosticLine(
              '版本',
              diagnostics.serverVersion.isEmpty
                  ? '-'
                  : diagnostics.serverVersion,
            ),
            _diagnosticLine('备份数量', diagnostics.listCount.toString()),
            _diagnosticLine(
              '最新备份',
              diagnostics.latestBackup.isEmpty ? '-' : diagnostics.latestBackup,
            ),
            _diagnosticLine(
              '数据目录',
              diagnostics.dataDir.isEmpty ? '-' : diagnostics.dataDir,
            ),
            _diagnosticLine(
              '备份目录',
              diagnostics.backupDir.isEmpty ? '-' : diagnostics.backupDir,
            ),
            if (diagnostics.error.isNotEmpty)
              _diagnosticLine('错误', diagnostics.error),
          ],
        ),
      ),
    );
  }

  Widget _diagnosticLine(String label, String value) {
    final brightness = CupertinoTheme.brightnessOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppTokens.txt2(brightness),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _manageBackups() async {
    _busy = true;
    setState(() {});
    final backups = await ref.read(syncServiceProvider).listBackups();
    var list = backups;
    _busy = false;
    setState(() {});
    if (!mounted) return;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> refresh() async {
            list = await ref.read(syncServiceProvider).listBackups();
            setDialogState(() {});
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.78,
            ),
            decoration: BoxDecoration(
              color: _groupColor(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 38,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '云端备份',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'data/backups 目录中的 ${list.length} 个 ZIP',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTokens.txt2(
                                  CupertinoTheme.brightnessOf(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '刷新',
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: list.isEmpty
                      ? _emptyBackups()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                          shrinkWrap: true,
                          itemCount: list.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final b = list[i];
                            final name = b['filename'] as String? ?? '';
                            return _backupRow(
                              b,
                              isLatest: i == 0,
                              onRestore: () async {
                                final confirmed = await _confirmRestoreBackup(
                                  ctx,
                                  name,
                                );
                                if (!confirmed) return;
                                if (!mounted) return;
                                Navigator.pop(context);
                                _busy = true;
                                _activeLabel = '拉取';
                                _status = '正在恢复 $name...';
                                setState(() {});
                                try {
                                  await _restoreBackup(name);
                                } catch (e) {
                                  _status = '❌ $e';
                                }
                                _busy = false;
                                _activeLabel = '';
                                setState(() {});
                              },
                              onDelete: () async {
                                final confirmed = await _confirmDeleteBackup(
                                  ctx,
                                  name,
                                );
                                if (!confirmed) return;
                                final updatedList = await ref
                                    .read(syncServiceProvider)
                                    .deleteBackup(name);
                                if (updatedList != null &&
                                    !updatedList.any(
                                      (b) => b['filename'] == name,
                                    )) {
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
                                  await refresh();
                                  _showMsg('删除失败');
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _emptyBackups() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 42),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconBubble(
            Icons.folder_off_rounded,
            AppTokens.txt2(CupertinoTheme.brightnessOf(context)),
            size: 54,
            iconSize: 28,
          ),
          const SizedBox(height: 14),
          const Text(
            '暂无云端备份',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '推送或上传完整备份后会出现在这里',
            style: TextStyle(
              fontSize: 13,
              color: AppTokens.txt2(CupertinoTheme.brightnessOf(context)),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _backupRow(
    Map<String, dynamic> backup, {
    required bool isLatest,
    required VoidCallback onRestore,
    required VoidCallback onDelete,
  }) {
    final brightness = CupertinoTheme.brightnessOf(context);
    final name = backup['filename']?.toString() ?? '';
    final createdAt = backup['createdAt']?.toString() ?? '';
    final size = _formatBytes(backup['size']);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: _pageBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTokens.sep(brightness).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          _iconBubble(Icons.archive_rounded, _blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isLatest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _green.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          'NEW',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _green,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    if (createdAt.isNotEmpty) createdAt,
                    if (size.isNotEmpty) size,
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTokens.txt2(brightness),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: '恢复',
                onPressed: onRestore,
                icon: Icon(Icons.restore_rounded, color: _blue),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: _red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmRestoreBackup(BuildContext context, String name) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('恢复备份'),
        content: Text('恢复 $name 会覆盖当前本地存档，继续吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<bool> _confirmDeleteBackup(BuildContext context, String name) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除备份'),
        content: Text('确定删除 $name 吗？'),
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
    return result == true;
  }

  String _formatBytes(dynamic value) {
    final bytes = switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  void _disconnect() {
    ref.read(syncServiceProvider).reset();
    setState(() {
      _urlCtrl.clear();
      _status = '已断开';
    });
  }

  void _showMsg(String m) {
    if (!mounted) return;
    _status = m;
    setState(() {});
  }
}
