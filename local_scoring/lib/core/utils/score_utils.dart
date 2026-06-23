import '../constants/categories.dart';

/// 根据各维度分数计算总分（平均值，保留1位小数）
double calculateScore(Map<String, double> dimensions) {
  if (dimensions.isEmpty) return 0.0;
  final sum = dimensions.values.fold<double>(0, (a, b) => a + b);
  return double.parse((sum / dimensions.length).toStringAsFixed(1));
}

/// 获取分类的默认维度（全部为 5 分）
Map<String, double> getDefaultDimensions(String categoryId) {
  final config = getCategoryConfig(categoryId);
  return {for (final d in config.dimensions) d: 5.0};
}

/// 格式化分数显示
String formatScore(double score) {
  if (score == 0) return '-';
  return score.toStringAsFixed(1);
}
