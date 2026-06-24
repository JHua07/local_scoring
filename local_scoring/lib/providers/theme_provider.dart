import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 主题模式持久化存储
class ThemeSettingNotifier extends StateNotifier<ThemeMode> {
  ThemeSettingNotifier() : super(ThemeMode.system) {
    _load();
  }

  static const _fileName = 'app_settings.json';

  Future<File> get _file async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, 'private_review_app'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, _fileName));
  }

  Future<void> _load() async {
    try {
      final file = await _file;
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final modeName = json['themeMode'] as String?;
      if (modeName != null) {
        state = ThemeMode.values.firstWhere(
            (m) => m.name == modeName,
            orElse: () => ThemeMode.system);
      }
    } catch (_) {}
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    try {
      final file = await _file;
      await file.writeAsString(jsonEncode({'themeMode': mode.name}));
    } catch (_) {}
  }
}

final themeProvider =
    StateNotifierProvider<ThemeSettingNotifier, ThemeMode>((ref) {
  return ThemeSettingNotifier();
});
