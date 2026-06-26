import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/draft_item.dart';
import '../data/repositories/draft_repository.dart';

// ==================== Repository ====================

final draftRepositoryProvider = Provider<DraftRepository>((ref) {
  return DraftRepository();
});

// ==================== 草稿列表 ====================

class DraftListState {
  final List<DraftItem> items;
  final bool isLoading;

  const DraftListState({this.items = const [], this.isLoading = false});

  DraftListState copyWith({List<DraftItem>? items, bool? isLoading}) {
    return DraftListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DraftListNotifier extends StateNotifier<DraftListState> {
  final DraftRepository _repository;

  DraftListNotifier(this._repository) : super(const DraftListState());

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    try {
      final items = await _repository.getAll();
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> add(DraftItem item) async {
    await _repository.add(item);
    // 乐观更新
    final items = List<DraftItem>.from(state.items);
    items.insert(0, item);
    state = state.copyWith(items: items);
  }

  Future<void> updateDraft(DraftItem item) async {
    await _repository.update(item);
    await loadAll();
  }

  Future<void> delete(String id) async {
    final items = List<DraftItem>.from(state.items);
    items.removeWhere((d) => d.id == id);
    state = state.copyWith(items: items);
    await _repository.delete(id);
  }

  /// 根据 id 获取草稿
  DraftItem? getById(String id) {
    try {
      return state.items.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
}

final draftListProvider =
    StateNotifierProvider<DraftListNotifier, DraftListState>((ref) {
      final repository = ref.watch(draftRepositoryProvider);
      return DraftListNotifier(repository);
    });
