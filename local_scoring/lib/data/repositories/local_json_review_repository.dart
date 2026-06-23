import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/annotation.dart';
import '../models/evaluation.dart';
import '../models/review_item.dart';
import '../models/scoring_template.dart';
import '../../core/constants/templates.dart' as tmpl;
import 'review_repository.dart';

class LocalJsonReviewRepository implements ReviewRepository {
  static const String _dataDir = 'private_review_app';
  static const String _reviewsFile = 'reviews.json';
  static const String _templatesFile = 'templates.json';
  static const String _imagesDir = 'images';
  static const int _recycleBinDays = 30;

  // ========== 目录 / 文件引用 ==========

  Future<Directory> get _appDir async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, _dataDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> get _reviewsFileRef async {
    final dir = await _appDir;
    return File(p.join(dir.path, _reviewsFile));
  }

  Future<File> get _templatesFileRef async {
    final dir = await _appDir;
    return File(p.join(dir.path, _templatesFile));
  }

  Future<Directory> get _imagesDirRef async {
    final dir = await _appDir;
    final imgDir = Directory(p.join(dir.path, _imagesDir));
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }
    return imgDir;
  }

  // ========== 评分 CRUD ==========

  @override
  Future<List<ReviewItem>> getAll() async {
    await _cleanExpiredDeleted();
    try {
      final file = await _reviewsFileRef;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final all = ReviewItem.listFromJson(content);
      // 过滤已删除的
      return all.where((r) => r.deletedAt == null).toList();
    } catch (e) {
      debugPrint('Failed to load reviews: $e');
      rethrow;
    }
  }

  /// 获取所有评分（含已删除），内部使用
  Future<List<ReviewItem>> _getAllRaw() async {
    try {
      final file = await _reviewsFileRef;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      return ReviewItem.listFromJson(content);
    } catch (e) {
      debugPrint('Failed to load raw reviews: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveAll(List<ReviewItem> items) async {
    final file = await _reviewsFileRef;
    final jsonString = ReviewItem.listToJson(items);
    await file.writeAsString(jsonString);
  }

  @override
  Future<void> add(ReviewItem item) async {
    final items = await _getAllRaw();
    items.add(item);
    await saveAll(items);
  }

  @override
  Future<void> update(ReviewItem item) async {
    final items = await _getAllRaw();
    final index = items.indexWhere((r) => r.id == item.id);
    if (index != -1) {
      items[index] = item;
      await saveAll(items);
    }
  }

  @override
  Future<void> delete(String id) async {
    await softDelete(id);
  }

  // ========== 软删除 / 回收站 ==========

  @override
  Future<void> softDelete(String id) async {
    final items = await _getAllRaw();
    final index = items.indexWhere((r) => r.id == id);
    if (index != -1) {
      items[index] = items[index].copyWith(deletedAt: DateTime.now());
      await saveAll(items);
    }
  }

  @override
  Future<void> restore(String id) async {
    final items = await _getAllRaw();
    final index = items.indexWhere((r) => r.id == id);
    if (index != -1) {
      items[index] = items[index].copyWith(deletedAt: null);
      await saveAll(items);
    }
  }

  @override
  Future<void> permanentDelete(String id) async {
    final items = await _getAllRaw();
    items.removeWhere((r) => r.id == id);
    await saveAll(items);
    // TODO: 同步删除关联图片
  }

  @override
  Future<List<ReviewItem>> getDeleted() async {
    final items = await _getAllRaw();
    return items.where((r) => r.deletedAt != null).toList();
  }

  Future<void> _cleanExpiredDeleted() async {
    final items = await _getAllRaw();
    final cutoff = DateTime.now().subtract(Duration(days: _recycleBinDays));
    final expired = items
        .where((r) => r.deletedAt != null && r.deletedAt!.isBefore(cutoff))
        .toList();
    if (expired.isNotEmpty) {
      items.removeWhere(
          (r) => r.deletedAt != null && r.deletedAt!.isBefore(cutoff));
      await saveAll(items);
    }
  }

  // ========== 评价 & 批注 ==========

  @override
  Future<void> addEvaluation(String reviewId, Evaluation evaluation) async {
    final items = await _getAllRaw();
    final index = items.indexWhere((r) => r.id == reviewId);
    if (index != -1) {
      final updatedEvals = List<Evaluation>.from(items[index].evaluations)
        ..add(evaluation)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      items[index] = items[index].copyWith(
        evaluations: updatedEvals,
        updatedAt: DateTime.now(),
      );
      await saveAll(items);
    }
  }

  @override
  Future<void> addAnnotation(
      String reviewId, String evaluationId, Annotation annotation) async {
    final items = await _getAllRaw();
    final index = items.indexWhere((r) => r.id == reviewId);
    if (index != -1) {
      final evals = List<Evaluation>.from(items[index].evaluations);
      final evalIndex = evals.indexWhere((e) => e.id == evaluationId);
      if (evalIndex != -1) {
        final updatedAnnots =
            List<Annotation>.from(evals[evalIndex].annotations)
              ..add(annotation);
        evals[evalIndex] = evals[evalIndex].copyWith(annotations: updatedAnnots);
        items[index] = items[index].copyWith(
          evaluations: evals,
          updatedAt: DateTime.now(),
        );
        await saveAll(items);
      }
    }
  }

  // ========== 模板 CRUD ==========

  Future<void> _ensureTemplatesSeeded() async {
    final file = await _templatesFileRef;
    if (!await file.exists()) {
      await saveAllTemplates(tmpl.builtInTemplates.toList());
    }
  }

  @override
  Future<List<ScoringTemplate>> getAllTemplates() async {
    await _ensureTemplatesSeeded();
    try {
      final file = await _templatesFileRef;
      if (!await file.exists()) return tmpl.builtInTemplates.toList();
      final content = await file.readAsString();
      if (content.trim().isEmpty) return tmpl.builtInTemplates.toList();
      return ScoringTemplate.listFromJson(content);
    } catch (e) {
      debugPrint('Failed to load templates: $e');
      return tmpl.builtInTemplates.toList();
    }
  }

  @override
  Future<void> saveAllTemplates(List<ScoringTemplate> templates) async {
    final file = await _templatesFileRef;
    final jsonString = ScoringTemplate.listToJson(templates);
    await file.writeAsString(jsonString);
  }

  @override
  Future<void> addTemplate(ScoringTemplate template) async {
    final templates = await getAllTemplates();
    templates.add(template);
    await saveAllTemplates(templates);
  }

  @override
  Future<void> updateTemplate(ScoringTemplate template) async {
    final templates = await getAllTemplates();
    final index = templates.indexWhere((t) => t.id == template.id);
    if (index != -1) {
      templates[index] = template;
      await saveAllTemplates(templates);
    }
  }

  @override
  Future<void> deleteTemplate(String id) async {
    final templates = await getAllTemplates();
    templates.removeWhere((t) => t.id == id);
    // 同时删除子模板
    templates.removeWhere((t) => t.parentTemplateId == id);
    await saveAllTemplates(templates);
  }

  // ========== 图片 ==========

  Future<String> copyImageToLocal(String sourcePath) async {
    final imgDir = await _imagesDirRef;
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
    final destPath = p.join(imgDir.path, fileName);
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  Future<void> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Failed to delete image: $e');
    }
  }

  Future<int> getImageCount() async {
    try {
      final imgDir = await _imagesDirRef;
      final files = await imgDir.list().toList();
      return files.whereType<File>().length;
    } catch (e) {
      return 0;
    }
  }

  // ========== 清空 & 导出 ==========

  @override
  Future<void> clearAll() async {
    // 清空 JSON（含已删除评分）
    final file = await _reviewsFileRef;
    if (await file.exists()) await file.delete();
    // 清空图片
    final imgDir = await _imagesDirRef;
    if (await imgDir.exists()) await imgDir.delete(recursive: true);
  }

  @override
  Future<String> exportJson() async {
    final file = await _reviewsFileRef;
    if (!await file.exists()) return '';
    return file.path;
  }
}
