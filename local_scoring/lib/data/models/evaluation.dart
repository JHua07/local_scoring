import 'annotation.dart';

/// 单次评价：对同一条目的某次体验评分
class Evaluation {
  final String id;
  final double score;
  final String reviewText;
  final List<String> imagePaths;
  final List<Annotation> annotations;
  final Map<String, double> dimensions; // 本次评价的各维度分数
  final DateTime createdAt;

  const Evaluation({
    required this.id,
    required this.score,
    this.reviewText = '',
    this.imagePaths = const [],
    this.annotations = const [],
    this.dimensions = const {},
    required this.createdAt,
  });

  Evaluation copyWith({
    String? id,
    double? score,
    String? reviewText,
    List<String>? imagePaths,
    List<Annotation>? annotations,
    Map<String, double>? dimensions,
    DateTime? createdAt,
  }) {
    return Evaluation(
      id: id ?? this.id,
      score: score ?? this.score,
      reviewText: reviewText ?? this.reviewText,
      imagePaths: imagePaths ?? this.imagePaths,
      annotations: annotations ?? this.annotations,
      dimensions: dimensions ?? this.dimensions,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'score': score,
        'reviewText': reviewText,
        'imagePaths': imagePaths,
        'annotations': annotations.map((a) => a.toJson()).toList(),
        'dimensions': dimensions,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Evaluation.fromJson(Map<String, dynamic> json) => Evaluation(
        id: json['id'] as String,
        score: (json['score'] as num).toDouble(),
        reviewText: json['reviewText'] as String? ?? '',
        imagePaths: (json['imagePaths'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        annotations: (json['annotations'] as List<dynamic>?)
                ?.map(
                    (e) => Annotation.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        dimensions: (json['dimensions'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
            {},
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
