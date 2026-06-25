import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 自动备份间隔
enum BackupInterval { oneHour, sixHours, twelveHours, oneDay, oneWeek }

/// 数据来源
enum DataSource { local, cloud }

/// 同步服务：与自建 sync-server 通信
class SyncService {
  String _baseUrl = '';
  String _token = '';
  String _deviceId = '';
  String _lastPulledBackup = '';

  // 自动备份
  bool _autoBackup = false;
  BackupInterval _backupInterval = BackupInterval.oneDay;
  Timer? _backupTimer;
  DateTime? _lastBackupTime;
  DateTime? _lastSyncTime; // 增量同步：上次拉取时间

  /// 重置拉取时间戳（用于数据清空后强制全量拉取）
  void resetLastSync() {
    _lastSyncTime = null;
    saveConfig();
  }

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
          orElse: () => BackupInterval.oneDay,
        );
        _dataSource = DataSource.values.firstWhere(
          (e) => e.name == (m['dataSource'] as String?),
          orElse: () => DataSource.local,
        );
        _lastPulledBackup = (m['lastPulledBackup'] as String?) ?? '';
        final lastStr = m['lastBackupTime'] as String?;
        if (lastStr != null) _lastBackupTime = DateTime.tryParse(lastStr);
        final syncStr = m['lastSyncTime'] as String?;
        if (syncStr != null) _lastSyncTime = DateTime.tryParse(syncStr);

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
      await f.writeAsString(
        jsonEncode({
          'baseUrl': _baseUrl,
          'token': _token,
          'deviceId': _deviceId,
          'autoBackup': _autoBackup,
          'backupInterval': _backupInterval.name,
          'dataSource': _dataSource.name,
          'lastPulledBackup': _lastPulledBackup,
          'lastBackupTime': _lastBackupTime?.toIso8601String(),
          'lastSyncTime': _lastSyncTime?.toIso8601String(),
        }),
      );
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
  String get token => _token;
  String get deviceId => _deviceId;
  String get lastPulledBackup => _lastPulledBackup;

  void configure({
    required String baseUrl,
    required String token,
    required String deviceId,
  }) {
    _baseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    _token = token;
    _deviceId = deviceId;
  }

  void reset() {
    _baseUrl = '';
    _token = '';
    _deviceId = '';
    _lastPulledBackup = '';
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

  void setAutoBackup(
    bool enabled, {
    BackupInterval interval = BackupInterval.oneDay,
  }) {
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

  Future<http.Response> _get(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    return http
        .get(uri, headers: _jsonHeaders)
        .timeout(const Duration(seconds: 30));
  }

  Map<String, String> get _authHeaders => {
    if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
    if (_deviceId.isNotEmpty) 'X-Device-Id': _deviceId,
  };

  Map<String, String> get _jsonHeaders => {
    ..._authHeaders,
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Map<String, String> get _zipHeaders => {
    ..._authHeaders,
    'Content-Type': 'application/zip',
    'Accept': 'application/json',
  };

  bool isSameLatestBackup(String? latestBackup) {
    return latestBackup != null &&
        latestBackup.isNotEmpty &&
        latestBackup == _lastPulledBackup;
  }

  Future<void> markPulledBackup(String? latestBackup) async {
    if (latestBackup == null || latestBackup.isEmpty) return;
    _lastPulledBackup = latestBackup;
    _lastSyncTime = DateTime.now();
    await saveConfig();
  }

  Future<void> forgetPulledBackup() async {
    _lastPulledBackup = '';
    _lastSyncTime = null;
    await saveConfig();
  }

  bool _isSuccessStatus(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

  bool _looksLikeZip(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4b &&
        (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07);
  }

  String _shortResponseBody(http.Response resp) {
    final contentType = resp.headers['content-type'] ?? '';
    if (!contentType.contains('json') && !contentType.startsWith('text/')) {
      return '<${resp.bodyBytes.length} bytes>';
    }
    final body = resp.body.trim().replaceAll('\n', ' ');
    if (body.length <= 500) return body;
    return '${body.substring(0, 500)}...';
  }

  bool _responseAccepted(http.Response resp) {
    if (!_isSuccessStatus(resp.statusCode)) return false;
    final body = resp.body.trim();
    if (body.isEmpty) return true;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final success = decoded['success'] ?? decoded['ok'];
        if (success is bool) return success;
        if (success is num) return success != 0;
        if (success is String) {
          final normalized = success.toLowerCase().trim();
          if (normalized == 'true' ||
              normalized == '1' ||
              normalized == 'ok' ||
              normalized == 'success') {
            return true;
          }
          if (normalized == 'false' ||
              normalized == '0' ||
              normalized == 'error' ||
              normalized == 'failed') {
            return false;
          }
        }
        if (decoded['error'] != null) return false;
        final message = decoded['message']?.toString().toLowerCase();
        if (message != null &&
            (message.contains('invalid body') ||
                message.contains('not found') ||
                message.contains('failed'))) {
          return false;
        }
      }
    } catch (_) {
      // Non-JSON 2xx responses are accepted.
    }
    return true;
  }

  String? _extractUploadedBackup(http.Response resp) {
    try {
      return _extractLatestBackup(jsonDecode(resp.body));
    } catch (_) {
      return null;
    }
  }

  Future<String?> _uploadZip(String path, File zipFile) async {
    final uri = Uri.parse('$_baseUrl$path');
    final bytes = await zipFile.readAsBytes();
    final resp = await http
        .post(
          uri,
          headers: {..._zipHeaders, 'X-Filename': p.basename(zipFile.path)},
          body: bytes,
        )
        .timeout(const Duration(minutes: 5));
    debugPrint(
      'uploadZip $path: HTTP ${resp.statusCode}, '
      'response=${_shortResponseBody(resp)}',
    );
    if (!_responseAccepted(resp)) return null;
    return _extractUploadedBackup(resp) ?? await checkLatestBackup() ?? '';
  }

  Future<bool> verifyBackupAvailable(String filename) async {
    if (filename.isEmpty) return false;
    try {
      final resp = await http
          .get(
            Uri.parse(
              '$_baseUrl/api/backup/download?file=${Uri.encodeComponent(filename)}',
            ),
            headers: {..._authHeaders, 'Accept': 'application/zip'},
          )
          .timeout(const Duration(minutes: 5));
      final ok =
          _isSuccessStatus(resp.statusCode) && _looksLikeZip(resp.bodyBytes);
      debugPrint(
        'verifyBackupAvailable $filename: HTTP ${resp.statusCode}, '
        'zip=${_looksLikeZip(resp.bodyBytes)}, bytes=${resp.bodyBytes.length}',
      );
      return ok;
    } catch (e) {
      debugPrint('verifyBackupAvailable $filename: $e');
      return false;
    }
  }

  Future<bool> verifyBackupMatches(String filename, File localZip) async {
    if (filename.isEmpty || !await localZip.exists()) return false;
    try {
      final localBytes = await localZip.readAsBytes();
      final resp = await http
          .get(
            Uri.parse(
              '$_baseUrl/api/backup/download?file=${Uri.encodeComponent(filename)}',
            ),
            headers: {..._authHeaders, 'Accept': 'application/zip'},
          )
          .timeout(const Duration(minutes: 5));
      final remoteBytes = resp.bodyBytes;
      final matches =
          _isSuccessStatus(resp.statusCode) &&
          _looksLikeZip(remoteBytes) &&
          localBytes.length == remoteBytes.length &&
          listEquals(localBytes, remoteBytes);
      debugPrint(
        'verifyBackupMatches $filename: HTTP ${resp.statusCode}, '
        'match=$matches, local=${localBytes.length}, '
        'remote=${remoteBytes.length}, zip=${_looksLikeZip(remoteBytes)}',
      );
      if (!matches) {
        await logSyncDebug('verifyBackupMatches mismatch');
      }
      return matches;
    } catch (e) {
      debugPrint('verifyBackupMatches $filename: $e');
      return false;
    }
  }

  Future<bool> backupStillAvailable(String filename) async {
    if (filename.isEmpty) return false;
    try {
      final resp = await http
          .get(
            Uri.parse(
              '$_baseUrl/api/backup/download?file=${Uri.encodeComponent(filename)}',
            ),
            headers: {..._authHeaders, 'Accept': 'application/zip'},
          )
          .timeout(const Duration(seconds: 30));
      final available =
          _isSuccessStatus(resp.statusCode) && _looksLikeZip(resp.bodyBytes);
      debugPrint(
        'backupStillAvailable $filename: HTTP ${resp.statusCode}, '
        'available=$available, bytes=${resp.bodyBytes.length}',
      );
      return available;
    } catch (e) {
      debugPrint('backupStillAvailable $filename: $e');
      return false;
    }
  }

  Future<void> logSyncDebug(String label) async {
    try {
      final resp = await _get('/api/sync/debug');
      debugPrint(
        'sync debug [$label]: HTTP ${resp.statusCode}, '
        'response=${_shortResponseBody(resp)}',
      );
    } catch (e) {
      debugPrint('sync debug [$label]: $e');
    }
  }

  Future<List<Map<String, dynamic>>> debugBackups() async {
    try {
      final resp = await _get('/api/sync/debug');
      debugPrint(
        'debugBackups: HTTP ${resp.statusCode}, '
        'response=${_shortResponseBody(resp)}',
      );
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['files'] is List) {
          return (decoded['files'] as List).map(_normalizeBackupEntry).toList();
        }
        final list = _extractBackupList(decoded);
        if (list != null) {
          return list.map(_normalizeBackupEntry).toList();
        }
      }
    } catch (e) {
      debugPrint('debugBackups error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _filterAvailableBackups(
    List<Map<String, dynamic>> backups,
  ) async {
    final available = <Map<String, dynamic>>[];
    for (final backup in backups) {
      final filename = backup['filename']?.toString() ?? '';
      if (filename.isEmpty) continue;
      if (await backupStillAvailable(filename)) {
        available.add(backup);
      } else {
        debugPrint('listBackups: filtered missing backup $filename');
      }
    }
    return available;
  }

  Future<File?> _downloadZipToPath(
    String path,
    String savePath, {
    required String label,
  }) async {
    final resp = await http
        .get(
          Uri.parse('$_baseUrl$path'),
          headers: {..._authHeaders, 'Accept': 'application/zip'},
        )
        .timeout(const Duration(minutes: 5));
    debugPrint(
      '$label: HTTP ${resp.statusCode}, response=${_shortResponseBody(resp)}',
    );
    if (_isSuccessStatus(resp.statusCode) && _looksLikeZip(resp.bodyBytes)) {
      final f = File(savePath);
      await f.writeAsBytes(resp.bodyBytes);
      return f;
    }
    return null;
  }

  String? _extractLatestBackup(dynamic decoded) {
    if (decoded is Map) {
      final direct =
          decoded['latestBackup'] ??
          decoded['latest'] ??
          decoded['filename'] ??
          decoded['name'];
      if (direct != null && direct.toString().isNotEmpty) {
        return direct.toString();
      }
      final backup = decoded['backup'];
      if (backup != null) return _extractLatestBackup(backup);
      final backups = decoded['backups'] ?? decoded['items'] ?? decoded['data'];
      if (backups is List && backups.isNotEmpty) {
        return _extractLatestBackup(backups.first);
      }
      return null;
    }
    if (decoded is List && decoded.isNotEmpty) {
      return _extractLatestBackup(decoded.first);
    }
    if (decoded is String && decoded.isNotEmpty) return decoded;
    return null;
  }

  List<dynamic>? _extractBackupList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      List<dynamic>? emptyList;
      for (final key in ['backups', 'items', 'data', 'snapshots', 'files']) {
        final value = decoded[key];
        if (value is List) {
          if (value.isNotEmpty) return value;
          emptyList ??= value;
        }
      }
      final result = decoded['result'];
      if (result != null) return _extractBackupList(result);
      if (emptyList != null) return emptyList;
    }
    return null;
  }

  Map<String, dynamic>? _extractBackupEntry(dynamic decoded) {
    final filename = _extractLatestBackup(decoded);
    if (filename == null || filename.isEmpty) return null;
    if (decoded is Map) {
      final createdAt =
          decoded['createdAt'] ?? decoded['updatedAt'] ?? decoded['modifiedAt'];
      final size = decoded['size'];
      final entry = <String, dynamic>{'filename': filename};
      if (createdAt != null) entry['createdAt'] = createdAt.toString();
      if (size != null) entry['size'] = size;
      return entry;
    }
    return {'filename': filename, 'createdAt': filename};
  }

  Map<String, dynamic> _normalizeBackupEntry(dynamic entry) {
    if (entry is String) {
      return {'filename': entry, 'createdAt': entry};
    }
    if (entry is Map) {
      final m = <String, dynamic>{};
      entry.forEach((key, value) => m[key.toString()] = value);
      final filename =
          m['filename'] ?? m['name'] ?? m['file'] ?? m['key'] ?? m['id'];
      final createdAt =
          m['createdAt'] ??
          m['updatedAt'] ??
          m['modifiedAt'] ??
          m['lastModified'] ??
          m['mtime'];
      if (filename != null) m['filename'] = filename.toString();
      if (createdAt != null) m['createdAt'] = createdAt.toString();
      return m;
    }
    return {'filename': entry.toString(), 'createdAt': ''};
  }

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
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceName': deviceName}),
      );
      if (resp.statusCode == 200) {
        final m = jsonDecode(resp.body);
        return (token: m['token'] as String, deviceId: m['deviceId'] as String);
      }
    } catch (_) {}
    return null;
  }

  /// 推送：打包本地完整数据为 ZIP，上传到服务器
  Future<String?> pushFullBackup(File zipFile) async {
    try {
      final syncBackup = await _uploadZip('/api/sync/push', zipFile);
      if (syncBackup != null) return syncBackup;
      debugPrint('pushFullBackup: fallback to /api/backup/upload');
      return await uploadBackup(zipFile);
    } catch (e) {
      debugPrint('pushFullBackup: $e');
      return null;
    }
  }

  Future<File?> pullFullBackup(String savePath, {String? filename}) async {
    try {
      if (filename != null && filename.isNotEmpty) {
        final namedZip = await downloadBackupToPath(
          savePath,
          filename: filename,
        );
        if (namedZip != null) return namedZip;
        debugPrint('pullFullBackup: named backup $filename unavailable');
      }

      final syncZip = await _downloadZipToPath(
        '/api/sync/pull',
        savePath,
        label: 'pullFullBackup /api/sync/pull',
      );
      if (syncZip != null) return syncZip;

      debugPrint('pullFullBackup: fallback to /api/backup/download');
      return await downloadBackupToPath(savePath);
    } catch (e) {
      debugPrint('pullFullBackup: $e');
    }
    return null;
  }

  /// 检查服务器最新备份名（快速判断有无更新）
  Future<String?> checkLatestBackup() async {
    try {
      final resp = await _get('/api/sync/check');
      if (resp.statusCode == 200) {
        debugPrint('checkLatestBackup body: ${_shortResponseBody(resp)}');
        return _extractLatestBackup(jsonDecode(resp.body));
      }
    } catch (_) {}
    return null;
  }

  /// 上传备份 zip（手动备份用）
  Future<String?> uploadBackup(File zipFile) async {
    try {
      return await _uploadZip('/api/backup/upload', zipFile);
    } catch (e) {
      debugPrint('uploadBackup: $e');
    }
    return null;
  }

  String? preferredRestoreBackup(String? serverLatest) {
    final local = _lastPulledBackup;
    if (local.isEmpty) return serverLatest;
    if (serverLatest == null || serverLatest.isEmpty) return local;
    return local.compareTo(serverLatest) > 0 ? local : serverLatest;
  }

  /// 下载服务器备份 zip（指定文件名，空则最新）
  Future<File?> downloadBackup(String saveDir, {String? filename}) async {
    final name =
        filename ??
        'server_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
    return downloadBackupToPath(p.join(saveDir, name), filename: filename);
  }

  Future<File?> downloadBackupToPath(
    String savePath, {
    String? filename,
  }) async {
    try {
      final qs = filename != null
          ? '?file=${Uri.encodeComponent(filename)}'
          : '';
      return await _downloadZipToPath(
        '/api/backup/download$qs',
        savePath,
        label: 'downloadBackup',
      );
    } catch (e) {
      debugPrint('downloadBackup error: $e');
    }
    return null;
  }

  /// 列出服务器上所有备份
  Future<List<Map<String, dynamic>>> listBackups() async {
    var shouldTryDebug = false;
    try {
      final resp = await _get('/api/backup/list');
      if (resp.statusCode == 200) {
        final body = resp.body;
        debugPrint(
          'listBackups body: ${body.length} chars '
          '${_shortResponseBody(resp)}',
        );
        final decoded = jsonDecode(body);
        final list = _extractBackupList(decoded);
        if (list != null) {
          debugPrint('listBackups: got ${list.length} entries');
          final normalized = list.map(_normalizeBackupEntry).toList();
          if (normalized.isNotEmpty) {
            return _filterAvailableBackups(normalized);
          }

          final fallback = _extractBackupEntry(decoded);
          if (fallback != null) {
            debugPrint('listBackups: fallback to latest backup from list body');
            return _filterAvailableBackups([_normalizeBackupEntry(fallback)]);
          }
          shouldTryDebug = true;
        }
        debugPrint('listBackups: unexpected type ${decoded.runtimeType}');
      }
      debugPrint('listBackups: HTTP ${resp.statusCode}');
      shouldTryDebug = true;
    } catch (e) {
      debugPrint('listBackups error: $e');
      shouldTryDebug = true;
    }
    if (shouldTryDebug) {
      final debugList = await debugBackups();
      if (debugList.isNotEmpty) {
        debugPrint('listBackups: fallback to /api/sync/debug');
        return _filterAvailableBackups(debugList);
      }
    }
    return [];
  }

  /// 删除服务器上指定备份
  Future<List<Map<String, dynamic>>?> deleteBackup(String filename) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/api/backup/delete'),
            headers: _jsonHeaders,
            body: jsonEncode({'filename': filename}),
          )
          .timeout(const Duration(seconds: 30));
      debugPrint(
        'deleteBackup $filename: HTTP ${resp.statusCode} ${resp.body}',
      );
      if (!_responseAccepted(resp)) return null;

      try {
        final decoded = jsonDecode(resp.body);
        final list = _extractBackupList(decoded);
        if (list != null) {
          return list.map(_normalizeBackupEntry).toList();
        }
      } catch (_) {}
      return await listBackups();
    } catch (e) {
      debugPrint('deleteBackup error: $e');
    }
    return null;
  }

  /// 上传单张图片
  Future<bool> uploadImage(String path, String reviewId, List<int> data) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/images/upload');
      final body = utf8.encode(
        jsonEncode({'path': path, 'reviewId': reviewId, 'data': data}),
      );
      final resp = await http.post(uri, headers: _jsonHeaders, body: body);
      return resp.statusCode == 200;
    } catch (_) {}
    return false;
  }
}

// ==================== Provider ====================

final syncServiceProvider = Provider<SyncService>((ref) {
  final s = SyncService();
  // Fire-and-forget load, page will await its own _load()
  s.loadConfig();
  return s;
});
