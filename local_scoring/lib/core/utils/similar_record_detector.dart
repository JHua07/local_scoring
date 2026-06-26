import '../../data/models/review_item.dart';
import '../../data/models/scoring_template.dart';

/// 相似记录检测结果
class SimilarRecordResult {
  final ReviewItem item;
  final double similarityScore; // 0.0 ~ 1.0
  final int matchedTagCount;
  final List<String> matchedTags;

  const SimilarRecordResult({
    required this.item,
    required this.similarityScore,
    required this.matchedTagCount,
    required this.matchedTags,
  });
}

/// 相似记录检测器
///
/// 检测依据：
/// 1. 分类相同（硬过滤条件）
/// 2. 标签相似度（Jaccard 系数）
/// 3. 标题文本匹配（辅助加分）
class SimilarRecordDetector {
  /// 检测与当前输入相似的已有记录
  ///
  /// [currentTitle] 当前输入的标题
  /// [currentCategory] 当前选中的分类
  /// [currentTags] 当前已输入的标签（可能为空）
  /// [allItems] 所有已有评分记录
  /// [templates] 模板列表（用于显示分类名）
  /// [excludeId] 排除的记录 ID（编辑模式下排除自身）
  ///
  /// 返回按相似度降序排列的结果列表，最多返回 5 条
  static List<SimilarRecordResult> detect({
    required String currentTitle,
    required String currentCategory,
    required List<String> currentTags,
    required List<ReviewItem> allItems,
    List<ScoringTemplate> templates = const [],
    String? excludeId,
    int maxResults = 5,
  }) {
    if (currentTitle.trim().isEmpty && currentTags.isEmpty) {
      return [];
    }

    final titleLower = currentTitle.trim().toLowerCase();

    // 候选集：同分类 + 未删除 + 排除自身
    final candidates = allItems.where((item) {
      if (item.deletedAt != null) return false;
      if (item.id == excludeId) return false;
      if (item.category != currentCategory) return false;
      return true;
    }).toList();

    if (candidates.isEmpty) return [];

    final results = <SimilarRecordResult>[];

    for (final item in candidates) {
      double score = 0.0;
      int matchedTagCount = 0;
      final matchedTags = <String>[];

      // 1. 标签相似度（Jaccard 系数）—— 主要权重
      if (currentTags.isNotEmpty && item.tags.isNotEmpty) {
        final currentSet = currentTags.map((t) => t.toLowerCase()).toSet();
        final itemSet = item.tags.map((t) => t.toLowerCase()).toSet();
        final intersection = currentSet.intersection(itemSet);
        matchedTagCount = intersection.length;
        matchedTags.addAll(intersection);

        final union = currentSet.union(itemSet);
        if (union.isNotEmpty) {
          final jaccard = intersection.length / union.length;
          score += jaccard * 0.7; // 标签相似度占 70%
        }
      }

      // 2. 标题文本匹配 —— 辅助权重
      final itemTitleLower = item.title.toLowerCase();
      if (titleLower.isNotEmpty) {
        // 完全包含
        if (itemTitleLower.contains(titleLower) ||
            titleLower.contains(itemTitleLower)) {
          score += 0.3;
        } else {
          // 分词匹配（按空格/标点简单分词）
          final titleWords =
              titleLower.split(RegExp(r'[\s,，、。；;]+')).where((w) => w.isNotEmpty).toSet();
          final itemWords =
              itemTitleLower.split(RegExp(r'[\s,，、。；;]+')).where((w) => w.isNotEmpty).toSet();

          if (titleWords.isNotEmpty && itemWords.isNotEmpty) {
            final wordIntersection = titleWords.intersection(itemWords);
            if (wordIntersection.isNotEmpty) {
              final wordJaccard =
                  wordIntersection.length / titleWords.union(itemWords).length;
              score += wordJaccard * 0.3;
            }
          }
        }
      }

      // 如果没有任何标签但有标题匹配，给一个基础分
      if (currentTags.isEmpty && score > 0) {
        // 仅有标题匹配时，归一化到合理范围
        score = (score / 0.3) * 0.5; // 最高 0.5
      }

      // 过滤低相似度结果
      if (score >= 0.1 || (currentTags.isEmpty && score > 0)) {
        results.add(SimilarRecordResult(
          item: item,
          similarityScore: score,
          matchedTagCount: matchedTagCount,
          matchedTags: matchedTags,
        ));
      }
    }

    // 按相似度降序排列
    results.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));

    return results.take(maxResults).toList();
  }
}
