import 'package:flutter/material.dart';

import 'review_item.dart';
import 'scoring_template.dart';

/// 筛选状态：用于评分库列表过滤
class FilterState {
  final double? minScore;
  final double? maxScore;
  final int? minEvalCount;
  final int? maxEvalCount;
  final DateTime? startDate;
  final DateTime? endDate;
  /// 各维度分数范围，key = 维度名称
  final Map<String, RangeValues> dimensionRanges;

  const FilterState({
    this.minScore,
    this.maxScore,
    this.minEvalCount,
    this.maxEvalCount,
    this.startDate,
    this.endDate,
    this.dimensionRanges = const {},
  });

  /// 空筛选（所有条件未激活）
  static const FilterState empty = FilterState();

  /// 是否有任何筛选条件生效
  bool get isActive =>
      minScore != null ||
      maxScore != null ||
      minEvalCount != null ||
      maxEvalCount != null ||
      startDate != null ||
      endDate != null ||
      dimensionRanges.isNotEmpty;

  FilterState copyWith({
    double? minScore,
    double? maxScore,
    int? minEvalCount,
    int? maxEvalCount,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, RangeValues>? dimensionRanges,
    bool clearMinScore = false,
    bool clearMaxScore = false,
    bool clearMinEvalCount = false,
    bool clearMaxEvalCount = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearDimensionRanges = false,
  }) {
    return FilterState(
      minScore: clearMinScore ? null : (minScore ?? this.minScore),
      maxScore: clearMaxScore ? null : (maxScore ?? this.maxScore),
      minEvalCount:
          clearMinEvalCount ? null : (minEvalCount ?? this.minEvalCount),
      maxEvalCount:
          clearMaxEvalCount ? null : (maxEvalCount ?? this.maxEvalCount),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      dimensionRanges: clearDimensionRanges
          ? const {}
          : (dimensionRanges ?? this.dimensionRanges),
    );
  }

  /// 判断条目是否满足所有筛选条件

  // ignore: unused_element
  bool matches(ReviewItem item, List<ScoringTemplate> templates) {
    final score = item.score;

    // 1) 分数范围
    if (minScore != null && score < minScore!) return false;
    if (maxScore != null && score > maxScore!) return false;

    // 2) 评价次数范围
    final evalCount = item.evaluations.length;
    if (minEvalCount != null && evalCount < minEvalCount!) return false;
    if (maxEvalCount != null && evalCount > maxEvalCount!) return false;

    // 3) 首次添加时间范围（使用 createdAt）
    final created = item.createdAt;
    if (startDate != null) {
      // 比较日期粒度（只比较年月日）
      final d = DateTime(created.year, created.month, created.day);
      final s = DateTime(
          startDate!.year, startDate!.month, startDate!.day);
      if (d.isBefore(s)) return false;
    }
    if (endDate != null) {
      final d = DateTime(created.year, created.month, created.day);
      final e =
          DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (d.isAfter(e)) return false;
    }

    // 4) 维度评分范围（取 latestEvaluation 的 dimensions）
    if (dimensionRanges.isNotEmpty) {
      final dims =
          item.latestEvaluation?.dimensions ?? item.dimensions;
      for (final entry in dimensionRanges.entries) {
        final val = dims[entry.key];
        if (val == null) return false; // 条目没有该维度，不匹配
        if (val < entry.value.start || val > entry.value.end) return false;
      }
    }

    return true;
  }
}
