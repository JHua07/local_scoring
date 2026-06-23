/// 批注模型：对一条评分的注释/补充
class Annotation {
  final String id;
  final String text;
  final DateTime createdAt;

  const Annotation({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  Annotation copyWith({
    String? id,
    String? text,
    DateTime? createdAt,
  }) {
    return Annotation(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Annotation.fromJson(Map<String, dynamic> json) => Annotation(
        id: json['id'] as String,
        text: json['text'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
