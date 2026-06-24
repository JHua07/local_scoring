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
        // ── 服务器连接 ──
        _sectionTitle('服务器连接'),
        TextField(
          controller: _urlCtrl,
          decoration: InputDecoration(
            hintText: 'https://sync.yourdomain.com',
            prefixIcon: const Icon(Icons.dns_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          keyboardType: TextInputType.url,
        ),
        if (connected)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF4CAF50).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: const Text('已连接', style: TextStyle(fontSize: 11, color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text('设备: ${svc.deviceId}', style: TextStyle(fontSize: 12, color: cs.outline)),
            ]),
          ),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _chip('测试连接', Icons.wifi_find, cs.primary, () => _testConnect()),
          if (!connected) _chip('连接', Icons.link, cs.primary, () => _connect()),
          if (connected) _chip('拉取', Icons.cloud_download, cs.primary, () => _syncAll()),
          if (connected) _chip('推送', Icons.cloud_upload, cs.secondary, () => _pushToCloud()),
          if (connected) _chip('管理备份', Icons.manage_search, cs.outline, () => _manageBackups()),
          if (connected) _chip('断开', Icons.link_off, cs.outline, () => _disconnect()),
        ]),

        const SizedBox(height: 28),

        // ── 自动同步 ──
        _sectionTitle('自动同步'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('自动同步到服务器'),
          subtitle: Text(svc.autoBackup ? svc.backupIntervalLabel : (connected ? '已关闭' : '请先连接服务器')),
          value: svc.autoBackup,
          onChanged: connected
              ? (v) { ref.read(syncServiceProvider).setAutoBackup(v, interval: svc.backupInterval); setState(() {}); }
              : null,
        ),
        if (svc.autoBackup)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: DropdownButtonFormField<BackupInterval>(
              initialValue: svc.backupInterval,
              decoration: const InputDecoration(labelText: '同步间隔', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: BackupInterval.values.map((e) => DropdownMenuItem(value: e, child: Text(switch (e) {
                    BackupInterval.oneHour => '每小时', BackupInterval.sixHours => '每 6 小时',
                    BackupInterval.twelveHours => '每 12 小时', BackupInterval.oneDay => '每天',
                    BackupInterval.oneWeek => '每周',
                  }))).toList(),
              onChanged: (v) { if (v != null) { ref.read(syncServiceProvider).setAutoBackup(true, interval: v); setState(() {}); } },
            ),
          ),

        const SizedBox(height: 8),

        // 状态信息

        const SizedBox(height: 8),

        // 状态信息
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_status, style: TextStyle(fontSize: 13, color: cs.outline)),
          ),
        ],
      ]),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)));
  }

  Widget _chip(String label, IconData icon, Color color, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: _busy ? color.withValues(alpha: 0.3) : color),
      label: Text(label, style: TextStyle(fontSize: 13, color: _busy ? color.withValues(alpha: 0.3) : color)),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
      backgroundColor: color.withValues(alpha: 0.05),
      onPressed: _busy ? null : onTap,
    );
  }

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
    _busy = true; _status = '正在同步...'; setState(() {});
    try {
      final r = await ref.read(syncServiceProvider).pull();
      _status = r.ok ? (r.totalChanges > 0 ? '✅ 同步完成，+${r.totalChanges} 条' : '✅ 无新数据') : '❌ ${r.error}';
    } catch (e) { _status = '❌ $e'; }
    _busy = false; setState(() {});
  }

  Future<void> _pushToCloud() async {
    _busy = true; _status = '正在推送...'; setState(() {});
    try {
      final repo = ref.read(reviewRepositoryProvider) as LocalJsonReviewRepository;
      final zipPath = p.join(Directory.systemTemp.path, 'push_${DateTime.now().millisecondsSinceEpoch}.zip');
      await repo.exportBackup(zipPath);
      final ok = await ref.read(syncServiceProvider).uploadBackup(File(zipPath));
      _status = ok ? '✅ 推送成功' : '❌ 推送失败';
      try { await File(zipPath).delete(); } catch (_) {}
    } catch (e) { _status = '❌ $e'; }
    _busy = false; setState(() {});
  }

  Future<void> _manageBackups() async {
    _busy = true; setState(() {});
    final backups = await ref.read(syncServiceProvider).listBackups();
    _busy = false; setState(() {});
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('云端备份管理'),
        content: SizedBox(
          width: double.maxFinite,
          child: backups.isEmpty
              ? const Text('暂无云端备份')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: backups.length,
                  itemBuilder: (_, i) {
                    final b = backups[i];
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
                          final ok = await ref.read(syncServiceProvider).deleteBackup(name);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) _showMsg(ok ? '已删除 $name' : '删除失败');
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
      ),
    );
  }

  void _disconnect() {
    ref.read(syncServiceProvider).reset();
    setState(() { _urlCtrl.clear(); _status = '已断开'; });
  }

  void _showMsg(String m) { if (mounted) { _status = m; setState(() {}); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2))); } }
}
