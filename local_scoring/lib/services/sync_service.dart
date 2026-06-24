import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 自动备份间隔
enum BackupInterval {
  oneHour,
  sixHours,
  twelveHours,
  oneDay,
  oneWeek,
}

/// 数据来源
enum DataSource { local, cloud }

/// 同步服务：与自建 sync-server 通信
class SyncService {
  String _baseUrl = '';
  String _token = '';
  String _deviceId = '';
  Completer<void>? _initCompleter;

  // 自动备份
  bool _autoBackup = false;
  BackupInterval _backupInterval = BackupInterval.oneDay;
  Timer? _backupTimer;
  DateTime? _lastBackupTime;

  // 数据来源
  DataSource _dataSource = DataSource.local;

  bool get isConfigured => _baseUrl.isNotEmpty && _token.isNotEmpty;
  bool get autoBackup => _autoBackup;
  BackupInterval get backupInterval => _backupInterval;
  DateTime? get lastBackupTime => _lastBackupTime;
  DataSource get dataSource => _dataSource;

  // ==================== 配置持久化 ====================

  Future<void> loadConfig() async {
    try {
      final dir = await _configDir;
      final f = File(p.join(dir.path, 'sync_config.json'));
      if (await f.exists()) {
        final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        _baseUrl = (m['baseUrl'] as String?) ?? '';
        _token = (m['token'] as String?) ?? '';
        _deviceId = (m['deviceId'] as String?) ?? '';
        _autoBackup = (m['autoBackup'] as bool?) ?? false;
        _backupInterval = BackupInterval.values.firstWhere(
            (e) => e.name == (m['backupInterval'] as String?),
            orElse: () => BackupInterval.oneDay);
        _dataSource = DataSource.values.firstWhere(
            (e) => e.name == (m['dataSource'] as String?),
            orElse: () => DataSource.local);
        final lastStr = m['lastBackupTime'] as String?;
        if (lastStr != null) _lastBackupTime = DateTime.tryParse(lastStr);

        // 自动重连：有配置就尝试健康检查
        if (isConfigured) _scheduleAutoBackup();
      }
    } catch (e) {
      debugPrint('SyncService loadConfig: $e');
    }
  }

  Future<void> saveConfig() async {
    try {
      final dir = await _configDir;
      final f = File(p.join(dir.path, 'sync_config.json'));
      await f.writeAsString(jsonEncode({
        'baseUrl': _baseUrl,
        'token': _token,
        'deviceId': _deviceId,
        'autoBackup': _autoBackup,
        'backupInterval': _backupInterval.name,
        'dataSource': _dataSource.name,
        'lastBackupTime': _lastBackupTime?.toIso8601String(),
      }));
    } catch (e) {
      debugPrint('SyncService saveConfig: $e');
    }
  }

  Future<Directory> get _configDir async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, 'private_review_app'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String get baseUrl => _baseUrl;
  String get deviceId => _deviceId;

  void configure({required String baseUrl, required String token, required String deviceId}) {
    _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    _token = token;
    _deviceId = deviceId;
  }

  void reset() {
    _baseUrl = '';
    _token = '';
    _deviceId = '';
    _autoBackup = false;
    _dataSource = DataSource.local;
    _cancelAutoBackup();
    _deleteConfigFile();
  }

  Future<void> _deleteConfigFile() async {
    try {
      final dir = await _configDir;
      final f = File(p.join(dir.path, 'sync_config.json'));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  // ==================== 自动备份 ====================

  void setAutoBackup(bool enabled, {BackupInterval interval = BackupInterval.oneDay}) {
    _autoBackup = enabled;
    _backupInterval = interval;
    if (enabled) {
      _scheduleAutoBackup();
    } else {
      _cancelAutoBackup();
    }
    saveConfig();
  }

  void setDataSource(DataSource source) {
    _dataSource = source;
    saveConfig();
  }

  void _scheduleAutoBackup() {
    _cancelAutoBackup();
    final dur = switch (_backupInterval) {
      BackupInterval.oneHour => const Duration(hours: 1),
      BackupInterval.sixHours => const Duration(hours: 6),
      BackupInterval.twelveHours => const Duration(hours: 12),
      BackupInterval.oneDay => const Duration(days: 1),
      BackupInterval.oneWeek => const Duration(days: 7),
    };
    _backupTimer = Timer.periodic(dur, (_) => _doAutoBackup());
  }

  void _cancelAutoBackup() {
    _backupTimer?.cancel();
    _backupTimer = null;
  }

  Future<void> _doAutoBackup() async {
    if (!isConfigured) return;
    try {
      // 导出本地备份并上传
      final repo = await _configDir;
      // TODO: 调用仓库 exportBackup 生成临时 zip 并 upload
      debugPrint('Auto-backup triggered at ${DateTime.now()}');
    } catch (e) {
      debugPrint('Auto-backup failed: $e');
    }
  }

  /// 备份间隔持续时间描述
  String get backupIntervalLabel => switch (_backupInterval) {
        BackupInterval.oneHour => '每小时',
        BackupInterval.sixHours => '每 6 小时',
        BackupInterval.twelveHours => '每 12 小时',
        BackupInterval.oneDay => '每天',
        BackupInterval.oneWeek => '每周',
      };

  // ==================== HTTP 封装 ====================

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$path');
    final bytes = utf8.encode(jsonEncode(body));
    return http.post(uri, headers: _headers, body: bytes).timeout(const Duration(seconds: 30));
  }

  Future<http.Response> _get(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    return http.get(uri, headers: _headers).timeout(const Duration(seconds: 30));
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  // ==================== API ====================

  /// 健康检查
  Future<bool> healthCheck() async {
    try {
      final resp = await _get('/api/health');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 注册设备
  Future<({String token, String deviceId})?> register(String deviceName) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/auth/register');
      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'deviceName': deviceName}));
      if (resp.statusCode == 200) {
        final m = jsonDecode(resp.body);
        return (token: m['token'] as String, deviceId: m['deviceId'] as String);
      }
    } catch (_) {}
    return null;
  }

  /// 上传数据到服务器
  Future<SyncResult> push({
    required List<Map<String, dynamic>> reviews,
    required List<Map<String, dynamic>> templates,
  }) async {
    try {
      final resp = await _post('/api/sync/push', {
        'deviceId': _deviceId,
        'reviews': reviews,
        'templates': templates,
      });
      if (resp.statusCode == 200) {
        final m = jsonDecode(resp.body);
        return SyncResult(
          ok: true,
          serverReviews: _parseReviews(m['reviews']),
          serverTemplates: _parseTemplates(m['templates']),
        );
      }
    } catch (e) {
      debugPrint('SyncService push: $e');
    }
    return SyncResult(ok: false, error: '推送失败');
  }

  /// 从服务器拉取数据
  Future<SyncResult> pull({String? since}) async {
    try {
      final resp = await _post('/api/sync/pull', {
        'deviceId': _deviceId,
        'since': since ?? '1970-01-01T00:00:00Z',
      });
      if (resp.statusCode == 200) {
        final m = jsonDecode(resp.body);
        return SyncResult(
          ok: true,
          serverReviews: _parseReviews(m['reviews']),
          serverTemplates: _parseTemplates(m['templates']),
        );
      }
    } catch (e) {
      debugPrint('SyncService pull: $e');
    }
    return SyncResult(ok: false, error: '拉取失败');
  }

  /// 上传备份 zip
  Future<bool> uploadBackup(File zipFile) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/backup/upload');
      final bytes = await zipFile.readAsBytes();
      final resp = await http.post(uri, headers: _headers, body: bytes).timeout(const Duration(minutes: 5));
      return resp.statusCode == 200;
    } catch (_) {}
    return false;
  }

  /// 下载服务器备份 zip
  Future<File?> downloadBackup(String saveDir) async {
    try {
      final resp = await _get('/api/backup/download');
      if (resp.statusCode == 200) {
        final name = 'server_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
        final f = File(p.join(saveDir, name));
        await f.writeAsBytes(resp.bodyBytes);
        return f;
      }
    } catch (_) {}
    return null;
  }

  /// 上传单张图片
  Future<bool> uploadImage(String path, String reviewId, List<int> data) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/images/upload');
      final body = utf8.encode(jsonEncode({
        'path': path,
        'reviewId': reviewId,
        'data': data,
      }));
      final resp = await http.post(uri, headers: _headers, body: body);
      return resp.statusCode == 200;
    } catch (_) {}
    return false;
  }

  // ==================== 解析 ====================

  List<Map<String, dynamic>> _parseReviews(dynamic list) {
    if (list is! List) return [];
    return list.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  List<Map<String, dynamic>> _parseTemplates(dynamic list) {
    if (list is! List) return [];
    return list.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

class SyncResult {
  final bool ok;
  final String? error;
  final List<Map<String, dynamic>> serverReviews;
  final List<Map<String, dynamic>> serverTemplates;

  SyncResult({
    required this.ok,
    this.error,
    this.serverReviews = const [],
    this.serverTemplates = const [],
  });

  int get totalChanges => serverReviews.length + serverTemplates.length;
}

// ==================== Provider ====================

final syncServiceProvider = Provider<SyncService>((ref) {
  final s = SyncService();
  // Fire-and-forget load, page will await its own _load()
  s.loadConfig();
  return s;
});
