import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/draft_item.dart';

class DraftRepository {
  static const String _dataDir = 'private_review_app';
  static const String _draftsFile = 'drafts.json';

  Future<Directory> get _appDir async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, _dataDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> get _fileRef async {
    final dir = await _appDir;
    return File(p.join(dir.path, _draftsFile));
  }

  Future<List<DraftItem>> getAll() async {
    try {
      final file = await _fileRef;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      return DraftItem.listFromJson(content);
    } catch (e) {
      debugPrint('Failed to load drafts: $e');
      return [];
    }
  }

  Future<void> saveAll(List<DraftItem> items) async {
    final file = await _fileRef;
    await file.writeAsString(DraftItem.listToJson(items));
  }

  Future<void> add(DraftItem item) async {
    final items = await getAll();
    items.add(item);
    await saveAll(items);
  }

  Future<void> update(DraftItem item) async {
    final items = await getAll();
    final index = items.indexWhere((d) => d.id == item.id);
    if (index != -1) {
      items[index] = item;
      await saveAll(items);
    }
  }

  Future<void> delete(String id) async {
    final items = await getAll();
    items.removeWhere((d) => d.id == id);
    await saveAll(items);
  }

  Future<void> clearAll() async {
    final file = await _fileRef;
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 获取草稿数量
  Future<int> get count async {
    final items = await getAll();
    return items.length;
  }
}
