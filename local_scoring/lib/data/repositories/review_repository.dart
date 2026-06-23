import '../models/annotation.dart';
import '../models/evaluation.dart';
import '../models/review_item.dart';
import '../models/scoring_template.dart';

abstract class ReviewRepository {
  // === 评分 CRUD ===
  Future<List<ReviewItem>> getAll();
  Future<void> saveAll(List<ReviewItem> items);
  Future<void> add(ReviewItem item);
  Future<void> update(ReviewItem item);
  Future<void> delete(String id); // 默认软删除
  Future<void> clearAll();

  // === 软删除 / 回收站 ===
  Future<void> softDelete(String id);
  Future<void> restore(String id);
  Future<void> permanentDelete(String id);
  Future<List<ReviewItem>> getDeleted();

  // === 评价（多次评分） ===
  Future<void> addEvaluation(String reviewId, Evaluation evaluation);
  Future<void> addAnnotation(String reviewId, String evaluationId, Annotation annotation);

  // === 模板 ===
  Future<List<ScoringTemplate>> getAllTemplates();
  Future<void> saveAllTemplates(List<ScoringTemplate> templates);
  Future<void> addTemplate(ScoringTemplate template);
  Future<void> updateTemplate(ScoringTemplate template);
  Future<void> deleteTemplate(String id);

  // === 导出 ===
  Future<String> exportJson();
}
