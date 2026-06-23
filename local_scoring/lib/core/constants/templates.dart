import '../../data/models/scoring_template.dart';

/// 内置评分模板种子数据
final List<ScoringTemplate> builtInTemplates = [
  ScoringTemplate(
    id: 'food',
    name: '美食',
    icon: '🍜',
    dimensions: ['味道', '价格', '分量', '复吃意愿'],
    isBuiltIn: true,
    createdAt: _epoch,
  ),
  ScoringTemplate(
    id: 'shopping',
    name: '购物',
    icon: '🛍️',
    dimensions: ['颜值', '质感', '实用性', '后悔程度'],
    isBuiltIn: true,
    createdAt: _epoch,
  ),
  ScoringTemplate(
    id: 'movie',
    name: '电影',
    icon: '🎬',
    dimensions: ['剧情', '节奏', '演技', '推荐度'],
    isBuiltIn: true,
    createdAt: _epoch,
  ),
  ScoringTemplate(
    id: 'music',
    name: '音乐',
    icon: '🎵',
    dimensions: ['旋律', '歌词', '编曲', '耐听度'],
    isBuiltIn: true,
    createdAt: _epoch,
  ),
  ScoringTemplate(
    id: 'software',
    name: '软件',
    icon: '💻',
    dimensions: ['易用性', '功能', '稳定性', '性价比'],
    isBuiltIn: true,
    createdAt: _epoch,
  ),
  ScoringTemplate(
    id: 'game',
    name: '游戏',
    icon: '🎮',
    dimensions: ['好玩程度', '耐玩度', '画面', '上手难度'],
    isBuiltIn: true,
    createdAt: _epoch,
  ),
  ScoringTemplate(
    id: 'travel',
    name: '旅游地点',
    icon: '✈️',
    dimensions: ['风景', '便利度', '性价比', '再去意愿'],
    isBuiltIn: true,
    createdAt: _epoch,
  ),
  ScoringTemplate(
    id: 'other',
    name: '其他',
    icon: '📦',
    dimensions: ['体验', '价格', '实用性', '推荐度'],
    isBuiltIn: true,
    createdAt: _epoch,
  ),
];

final DateTime _epoch = DateTime(2024, 1, 1);

/// 从模板列表查找模板
ScoringTemplate getTemplateById(
    List<ScoringTemplate> templates, String id) {
  return templates.firstWhere(
    (t) => t.id == id,
    orElse: () => templates.firstWhere(
      (t) => t.id == 'other',
      orElse: () => builtInTemplates.last,
    ),
  );
}

/// 获取模板名称
String getTemplateName(List<ScoringTemplate> templates, String id) {
  return getTemplateById(templates, id).name;
}

/// 获取模板图标
String getTemplateIcon(List<ScoringTemplate> templates, String id) {
  return getTemplateById(templates, id).icon;
}

/// 获取模板默认维度
Map<String, double> getTemplateDefaultDimensions(
    List<ScoringTemplate> templates, String id) {
  final template = getTemplateById(templates, id);
  return {for (final d in template.dimensions) d: 5.0};
}

/// 获取指定模板的子模板
List<ScoringTemplate> getChildTemplates(
    List<ScoringTemplate> templates, String parentId) {
  return templates.where((t) => t.parentTemplateId == parentId).toList();
}

/// 获取顶级模板（含内置和自定义顶级）
List<ScoringTemplate> getTopLevelTemplates(List<ScoringTemplate> templates) {
  return templates.where((t) => t.parentTemplateId == null).toList();
}
