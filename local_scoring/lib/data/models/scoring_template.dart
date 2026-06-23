import 'dart:convert';

/// 评分模板：定义分类及其评分维度，支持层级
class ScoringTemplate {
  final String id;
  final String name;
  final String icon;
  final List<String> dimensions;
  final String? parentTemplateId; // null = 顶级模板
  final bool isBuiltIn; // 内置模板不可删除
  final DateTime createdAt;

  const ScoringTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.dimensions,
    this.parentTemplateId,
    this.isBuiltIn = false,
    required this.createdAt,
  });

  ScoringTemplate copyWith({
    String? id,
    String? name,
    String? icon,
    List<String>? dimensions,
    String? parentTemplateId,
    bool? isBuiltIn,
    DateTime? createdAt,
  }) {
    return ScoringTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      dimensions: dimensions ?? this.dimensions,
      parentTemplateId: parentTemplateId ?? this.parentTemplateId,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'dimensions': dimensions,
        'parentTemplateId': parentTemplateId,
        'isBuiltIn': isBuiltIn,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ScoringTemplate.fromJson(Map<String, dynamic> json) =>
      ScoringTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
        dimensions: (json['dimensions'] as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
        parentTemplateId: json['parentTemplateId'] as String?,
        isBuiltIn: json['isBuiltIn'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  static List<ScoringTemplate> listFromJson(String jsonString) {
    final list = json.decode(jsonString) as List<dynamic>;
    return list
        .map((e) => ScoringTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<ScoringTemplate> items) =>
      const JsonEncoder.withIndent('  ')
          .convert(items.map((e) => e.toJson()).toList());
}
