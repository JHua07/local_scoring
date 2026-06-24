import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/templates.dart' as tmpl;
import '../data/models/annotation.dart';
import '../data/models/evaluation.dart';
import '../data/models/review_item.dart';
import '../data/models/scoring_template.dart';
import '../data/repositories/local_json_review_repository.dart';
import '../data/repositories/review_repository.dart';

// ==================== Repository ====================

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return LocalJsonReviewRepository();
});

// ==================== 评分列表 ====================

class ReviewListState {
  final List<ReviewItem> items;
  final bool isLoading;
  final String? error;

  const ReviewListState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  ReviewListState copyWith({
    List<ReviewItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return ReviewListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class ReviewListNotifier extends StateNotifier<ReviewListState> {
  final ReviewRepository _repository;
  bool _isLoading = false;

  ReviewListNotifier(this._repository) : super(const ReviewListState());

  // ---- 加载 ----
  Future<void> loadAll() async {
    if (_isLoading) return;
    _isLoading = true;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repository.getAll();
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: '数据加载失败：$e');
    } finally {
      _isLoading = false;
    }
  }

  // ---- 新增 ----
  Future<bool> add(ReviewItem item) async {
    try {
      final currentItems = List<ReviewItem>.from(state.items);
      currentItems.removeWhere((r) => r.id == item.id);
      currentItems.insert(0, item);
      state = state.copyWith(items: currentItems);
      await _repository.add(item);
      return true;
    } catch (e) {
      state = state.copyWith(error: '保存失败：$e');
      await loadAll();
      return false;
    }
  }

  // ---- 更新 ----
  Future<bool> updateItem(ReviewItem item) async {
    try {
      final currentItems = List<ReviewItem>.from(state.items);
      final index = currentItems.indexWhere((r) => r.id == item.id);
      if (index != -1) {
        currentItems[index] = item;
        currentItems.removeAt(index);
        currentItems.insert(0, item);
        state = state.copyWith(items: currentItems);
      }
      await _repository.update(item);
      return true;
    } catch (e) {
      state = state.copyWith(error: '更新失败：$e');
      await loadAll();
      return false;
    }
  }

  // ---- 软删除 ----
  Future<bool> softDeleteItem(String id) async {
    try {
      final currentItems = List<ReviewItem>.from(state.items);
      currentItems.removeWhere((r) => r.id == id);
      state = state.copyWith(items: currentItems);
      await _repository.softDelete(id);
      return true;
    } catch (e) {
      state = state.copyWith(error: '删除失败：$e');
      await loadAll();
      return false;
    }
  }

  // ---- 恢复 ----
  Future<bool> restoreItem(String id) async {
    try {
      await _repository.restore(id);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(error: '恢复失败：$e');
      return false;
    }
  }

  // ---- 永久删除 ----
  Future<bool> permanentDeleteItem(String id) async {
    try {
      await _repository.permanentDelete(id);
      return true;
    } catch (e) {
      state = state.copyWith(error: '永久删除失败：$e');
      return false;
    }
  }

  // ---- 追加评价（多次评分） ----
  Future<bool> addEvaluation(String reviewId, Evaluation evaluation) async {
    try {
      await _repository.addEvaluation(reviewId, evaluation);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(error: '添加评价失败：$e');
      return false;
    }
  }

  // ---- 添加批注（针对特定评价） ----
  Future<bool> addAnnotation(String reviewId, String evaluationId, String text) async {
    try {
      final annotation = Annotation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        createdAt: DateTime.now(),
      );
      await _repository.addAnnotation(reviewId, evaluationId, annotation);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(error: '添加批注失败：$e');
      return false;
    }
  }

  // ---- 清空 ----
  Future<bool> clearAll() async {
    try {
      state = state.copyWith(items: []);
      await _repository.clearAll();
      return true;
    } catch (e) {
      state = state.copyWith(error: '清空失败：$e');
      await loadAll();
      return false;
    }
  }

  // ---- 导出 ----
  Future<String?> exportJson() async {
    try {
      return await _repository.exportJson();
    } catch (e) {
      state = state.copyWith(error: '导出失败：$e');
      return null;
    }
  }
}

final reviewListProvider =
    StateNotifierProvider<ReviewListNotifier, ReviewListState>((ref) {
      final repository = ref.watch(reviewRepositoryProvider);
      return ReviewListNotifier(repository);
    });

// ==================== 回收站 ====================

class DeletedListState {
  final List<ReviewItem> items;
  final bool isLoading;

  const DeletedListState({this.items = const [], this.isLoading = false});

  DeletedListState copyWith({List<ReviewItem>? items, bool? isLoading}) {
    return DeletedListState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading);
  }
}

class DeletedListNotifier extends StateNotifier<DeletedListState> {
  final ReviewRepository _repository;

  DeletedListNotifier(this._repository)
      : super(const DeletedListState());

  Future<void> loadDeleted() async {
    state = state.copyWith(isLoading: true);
    try {
      final items = await _repository.getDeleted();
      items.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> restore(String id) async {
    try {
      await _repository.restore(id);
      await loadDeleted();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> permanentDelete(String id) async {
    try {
      await _repository.permanentDelete(id);
      await loadDeleted();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final deletedListProvider =
    StateNotifierProvider<DeletedListNotifier, DeletedListState>((ref) {
      final repository = ref.watch(reviewRepositoryProvider);
      return DeletedListNotifier(repository);
    });

// ==================== 模板 ====================

class TemplateListState {
  final List<ScoringTemplate> templates;
  final bool isLoading;

  const TemplateListState(
      {this.templates = const [], this.isLoading = false});

  TemplateListState copyWith({
    List<ScoringTemplate>? templates,
    bool? isLoading,
  }) {
    return TemplateListState(
        templates: templates ?? this.templates,
        isLoading: isLoading ?? this.isLoading);
  }

  List<ScoringTemplate> get topLevel =>
      templates.where((t) => t.parentTemplateId == null).toList();

  List<ScoringTemplate> childrenOf(String parentId) =>
      templates.where((t) => t.parentTemplateId == parentId).toList();

  ScoringTemplate getById(String id) {
    return templates.firstWhere(
      (t) => t.id == id,
      orElse: () => tmpl.builtInTemplates.last,
    );
  }
}

class TemplateListNotifier extends StateNotifier<TemplateListState> {
  final ReviewRepository _repository;
  bool _isLoading = false;

  TemplateListNotifier(this._repository) : super(const TemplateListState());

  Future<void> loadAll() async {
    if (_isLoading) return;
    _isLoading = true;
    state = state.copyWith(isLoading: true);
    try {
      final templates = await _repository.getAllTemplates();
      state =
          state.copyWith(templates: templates, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    } finally {
      _isLoading = false;
    }
  }

  Future<bool> add(ScoringTemplate template) async {
    try {
      await _repository.addTemplate(template);
      await loadAll();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> update(ScoringTemplate template) async {
    try {
      await _repository.updateTemplate(template);
      await loadAll();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _repository.deleteTemplate(id);
      await loadAll();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> resetBuiltIn(String id) async {
    try {
      final builtIn = tmpl.builtInTemplates
          .firstWhere((t) => t.id == id, orElse: () => tmpl.builtInTemplates.last);
      await _repository.updateTemplate(builtIn);
      await loadAll();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final templateListProvider =
    StateNotifierProvider<TemplateListNotifier, TemplateListState>((ref) {
      final repository = ref.watch(reviewRepositoryProvider);
      return TemplateListNotifier(repository);
    });
