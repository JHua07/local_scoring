import 'dart:convert';

/// 草稿：评分表单未保存时的暂存数据
class DraftItem {
  final String id;
  final String title;
  final String category;
  final String worth;
  final bool revisit;
  final bool recommendToFriends;
  final List<String> tags;
  final Map<String, double> dimensions;
  final List<String> imagePaths;
  final String reviewText;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DraftItem({
    required this.id,
    required this.title,
    required this.category,
    this.worth = 'normal',
    this.revisit = false,
    this.recommendToFriends = false,
    this.tags = const [],
    this.dimensions = const {},
    this.imagePaths = const [],
    this.reviewText = '',
    required this.createdAt,
    required this.updatedAt,
  });

  DraftItem copyWith({
    String? id,
    String? title,
    String? category,
    String? worth,
    bool? revisit,
    bool? recommendToFriends,
    List<String>? tags,
    Map<String, double>? dimensions,
    List<String>? imagePaths,
    String? reviewText,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DraftItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      worth: worth ?? this.worth,
      revisit: revisit ?? this.revisit,
      recommendToFriends: recommendToFriends ?? this.recommendToFriends,
      tags: tags ?? this.tags,
      dimensions: dimensions ?? this.dimensions,
      imagePaths: imagePaths ?? this.imagePaths,
      reviewText: reviewText ?? this.reviewText,
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
        'imagePaths': imagePaths,
        'reviewText': reviewText,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory DraftItem.fromJson(Map<String, dynamic> json) => DraftItem(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        category: json['category'] as String? ?? 'food',
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
        imagePaths: (json['imagePaths'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        reviewText: json['reviewText'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  static List<DraftItem> listFromJson(String jsonString) {
    final list = json.decode(jsonString) as List<dynamic>;
    return list
        .map((item) => DraftItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<DraftItem> items) {
    return const JsonEncoder.withIndent('  ')
        .convert(items.map((item) => item.toJson()).toList());
  }

  /// 是否有任何填写内容
  bool get hasContent =>
      title.isNotEmpty ||
      reviewText.isNotEmpty ||
      tags.isNotEmpty ||
      dimensions.isNotEmpty ||
      imagePaths.isNotEmpty;
}
