import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/sync_service.dart';

/// 同步设置页：配置服务器地址、注册设备、手动同步
class SyncSettingsPage extends ConsumerStatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  ConsumerState<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends ConsumerState<SyncSettingsPage> {
  final _urlCtrl = TextEditingController();
  bool _connecting = false;
  bool _syncing = false;
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
      setState(() => _urlCtrl.text = svc.baseUrl);
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
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // 服务器地址
        Text('服务器地址', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _urlCtrl,
          decoration: InputDecoration(
            hintText: 'https://sync.yourdomain.com',
            prefixIcon: const Icon(Icons.dns_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          keyboardType: TextInputType.url,
        ),

        const SizedBox(height: 20),

        // 连接/断开
        if (!connected)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _connecting ? null : _connect,
              icon: _connecting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.link),
              label: const Text('连接服务器'),
            ),
          )
        else ...[
          // 已连接状态
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('已连接', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500))),
              Text(svc.deviceId, style: TextStyle(fontSize: 11, color: cs.outline)),
            ]),
          ),
          const SizedBox(height: 16),

          // 同步按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _syncing ? null : _syncAll,
              icon: _syncing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync),
              label: const Text('立即同步'),
              style: FilledButton.styleFrom(backgroundColor: cs.primary),
            ),
          ),

          const SizedBox(height: 12),

          // 断开
          OutlinedButton.icon(
            onPressed: _disconnect,
            icon: const Icon(Icons.link_off),
            label: const Text('断开连接'),
          ),
        ],

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

        const SizedBox(height: 32),

        // 说明
        Text('说明', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          '同步功能需要部署 private-review-sync 服务端。\n'
          '请在服务器上运行 Docker Compose 启动服务，\n'
          '并使用 Caddy 配置 HTTPS 反向代理。\n\n'
          '首次连接将自动注册设备。',
          style: TextStyle(fontSize: 13, color: cs.outline),
        ),
      ]),
    );
  }

  Future<void> _connect() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      _showMsg('请输入服务器地址');
      return;
    }
    setState(() {
      _connecting = true;
      _status = '';
    });

    final svc = ref.read(syncServiceProvider);
    svc.configure(baseUrl: url, token: '', deviceId: '');

    final healthy = await svc.healthCheck();
    if (!healthy) {
      setState(() => _connecting = false);
      _showMsg('无法连接到服务器，请检查地址');
      return;
    }

    // 注册设备
    final result = await svc.register('Flutter-${DateTime.now().millisecondsSinceEpoch}');
    if (result == null) {
      setState(() => _connecting = false);
      _showMsg('设备注册失败');
      return;
    }

    svc.configure(baseUrl: url, token: result.token, deviceId: result.deviceId);
    await svc.saveConfig();

    if (mounted) {
      setState(() {
        _connecting = false;
        _status = '注册成功，设备 ID: ${result.deviceId}';
      });
    }
  }

  Future<void> _syncAll() async {
    setState(() {
      _syncing = true;
      _status = '正在同步...';
    });

    final svc = ref.read(syncServiceProvider);

    try {
      // TODO: 实际同步逻辑 — 从本地仓库读取数据并推送
      final pullResult = await svc.pull();

      if (pullResult.ok) {
        final count = pullResult.totalChanges;
        setState(() => _status = count > 0 ? '同步完成，拉取到 $count 条服务器更新' : '同步完成，无新数据');
      } else {
        setState(() => _status = '同步失败：${pullResult.error}');
      }
    } catch (e) {
      setState(() => _status = '同步出错：$e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _disconnect() {
    final svc = ref.read(syncServiceProvider);
    svc.reset();
    svc.saveConfig();
    setState(() {
      _urlCtrl.clear();
      _status = '已断开';
    });
  }

  void _showMsg(String msg) {
    if (mounted) {
      setState(() => _status = msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
    }
  }
}
