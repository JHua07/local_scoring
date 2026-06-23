import 'dart:convert';

import 'annotation.dart';
import 'evaluation.dart';

class ReviewItem {
  final String id;
  final String title;
  final String category;
  final String worth; // worth, normal, not_worth
  final bool revisit;
  final bool recommendToFriends;
  final List<String> tags;
  final Map<String, double> dimensions;
  final List<Evaluation> evaluations;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReviewItem({
    required this.id,
    required this.title,
    required this.category,
    this.worth = 'normal',
    this.revisit = false,
    this.recommendToFriends = false,
    this.tags = const [],
    this.dimensions = const {},
    this.evaluations = const [],
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  // ---- 便捷 getter（取最新评价） ----
  Evaluation? get latestEvaluation =>
      evaluations.isNotEmpty ? evaluations.first : null;
  double get score => latestEvaluation?.score ?? 0.0;
  String get reviewText => latestEvaluation?.reviewText ?? '';
  List<String> get imagePaths => latestEvaluation?.imagePaths ?? [];

  ReviewItem copyWith({
    String? id,
    String? title,
    String? category,
    String? worth,
    bool? revisit,
    bool? recommendToFriends,
    List<String>? tags,
    Map<String, double>? dimensions,
    List<Evaluation>? evaluations,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReviewItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      worth: worth ?? this.worth,
      revisit: revisit ?? this.revisit,
      recommendToFriends: recommendToFriends ?? this.recommendToFriends,
      tags: tags ?? this.tags,
      dimensions: dimensions ?? this.dimensions,
      evaluations: evaluations ?? this.evaluations,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'worth': worth,
        'revisit': revisit,
        'recommendToFriends': recommendToFriends,
        'tags': tags,
        'dimensions': dimensions,
        'evaluations': evaluations.map((e) => e.toJson()).toList(),
        'deletedAt': deletedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    // 迁移旧数据：旧版 score/imagePaths/reviewText/annotations 在顶层
    final List<Evaluation> evals;
    if (json['evaluations'] != null) {
      evals = (json['evaluations'] as List<dynamic>)
          .map((e) => Evaluation.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      // 旧版数据：构造一个 Evaluation
      final oldAnnotations = (json['annotations'] as List<dynamic>?)
              ?.map(
                  (e) => Annotation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      oldAnnotations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      evals = [
        Evaluation(
          id: json['id'] as String,
          score: (json['score'] as num?)?.toDouble() ?? 0.0,
          reviewText: json['reviewText'] as String? ?? '',
          imagePaths: (json['imagePaths'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          annotations: oldAnnotations,
          createdAt: DateTime.parse(json['createdAt'] as String),
        ),
      ];
    }
    // 按最新在前排序
    evals.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ReviewItem(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String? ?? 'other',
      worth: json['worth'] as String? ?? 'normal',
      revisit: json['revisit'] as bool? ?? false,
      recommendToFriends: json['recommendToFriends'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      dimensions: (json['dimensions'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      evaluations: evals,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static List<ReviewItem> listFromJson(String jsonString) {
    final list = json.decode(jsonString) as List<dynamic>;
    return list
        .map((item) => ReviewItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<ReviewItem> items) {
    return const JsonEncoder.withIndent(
      '  ',
    ).convert(items.map((item) => item.toJson()).toList());
  }
}
