/// 分类配置：定义所有分类及其评分维度
class CategoryConfig {
  final String id;
  final String name;
  final String icon;
  final List<String> dimensions;

  const CategoryConfig({
    required this.id,
    required this.name,
    required this.icon,
    required this.dimensions,
  });
}

const List<CategoryConfig> categoryConfigs = [
  CategoryConfig(
    id: 'food',
    name: '吃喝',
    icon: '🍜',
    dimensions: ['味道', '价格', '分量', '复吃意愿'],
  ),
  CategoryConfig(
    id: 'shopping',
    name: '购物',
    icon: '🛍️',
    dimensions: ['颜值', '质感', '实用性', '后悔程度'],
  ),
  CategoryConfig(
    id: 'game',
    name: '游戏',
    icon: '🎮',
    dimensions: ['好玩程度', '耐玩度', '朋友体验', '上手难度'],
  ),
  CategoryConfig(
    id: 'badminton',
    name: '羽毛球',
    icon: '🏸',
    dimensions: ['场地', '价格', '灯光', '舒适度'],
  ),
  CategoryConfig(
    id: 'media',
    name: '影视',
    icon: '🎬',
    dimensions: ['剧情', '节奏', '角色', '推荐度'],
  ),
  CategoryConfig(
    id: 'place',
    name: '地点',
    icon: '📍',
    dimensions: ['环境', '便利度', '价格', '再去意愿'],
  ),
  CategoryConfig(
    id: 'service',
    name: '服务',
    icon: '🛠️',
    dimensions: ['态度', '效率', '价格', '专业度'],
  ),
  CategoryConfig(
    id: 'other',
    name: '其他',
    icon: '📦',
    dimensions: ['体验', '价格', '实用性', '推荐度'],
  ),
];

CategoryConfig getCategoryConfig(String categoryId) {
  return categoryConfigs.firstWhere(
    (c) => c.id == categoryId,
    orElse: () => categoryConfigs.last,
  );
}

String getCategoryName(String categoryId) {
  return getCategoryConfig(categoryId).name;
}

String getCategoryIcon(String categoryId) {
  return getCategoryConfig(categoryId).icon;
}
