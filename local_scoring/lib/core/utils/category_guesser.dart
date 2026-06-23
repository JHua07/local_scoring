/// 离线关键词自动分类（匹配新模板 ID）
String guessCategory(String text) {
  if (text.isEmpty) return 'other';
  final lower = text.toLowerCase();

  // 美食
  const foodKw = [
    '奶茶', '火锅', '外卖', '咖啡', '餐厅', '烧烤', '面', '饭', '甜品',
    '蛋糕', '面包', '小吃', '炸鸡', '汉堡', '披萨', '寿司', '刺身',
    '自助', '早茶', '下午茶', '夜宵', '零食', '饮料', '果汁', '啤酒',
    '酒', '吃', '喝', '味道', '口味', '辣', '酸', '甜', '咸',
    '牛肉', '羊肉', '猪肉', '鸡肉', '海鲜', '虾', '鱼', '蟹',
    '米饭', '面条', '粉', '汤', '锅', '煲', '炒', '蒸', '煮',
  ];
  for (final kw in foodKw) {
    if (lower.contains(kw)) return 'food';
  }

  // 购物
  const shoppingKw = [
    '买', '商品', '衣服', '耳机', '键盘', '手机', '鞋', '包', '数码',
    '鼠标', '显示器', '电脑', '平板', '手表', '眼镜', '香水', '化妆品',
    '护肤品', '裤子', '裙子', '帽子', '围巾', '袜子',
    '淘宝', '京东', '拼多多', '购物', '快递', '开箱', '退货',
    '性价比', '质量', '材质', '尺码', '颜色',
  ];
  for (final kw in shoppingKw) {
    if (lower.contains(kw)) return 'shopping';
  }

  // 游戏
  const gameKw = [
    '游戏', '开黑', '角色', '皮肤', '装备', '段位', '联机',
    '排位', '匹配', '副本', 'boss', '通关', '成就', '奖杯',
    'steam', 'switch', 'ps5', 'xbox', '手游', '端游',
    '王者', '原神', 'lol', '吃鸡', 'fps', 'rpg', 'moba',
    '练级', '打怪', '任务', '画面', '操作',
  ];
  for (final kw in gameKw) {
    if (lower.contains(kw)) return 'game';
  }

  // 电影
  const movieKw = [
    '电影', '电视剧', '综艺', '演员', '追剧', '番剧',
    '动漫', '纪录片', 'netflix', 'b站', 'bilibili', '爱奇艺', '腾讯视频',
    '导演', '演技', '豆瓣', 'imdb', '剧集', '集数', '季',
    '动画', '漫画', '声优', '配乐', 'ost', '剧情', '角色',
    '影院', 'imax', '票房', '上映',
  ];
  for (final kw in movieKw) {
    if (lower.contains(kw)) return 'movie';
  }

  // 音乐
  const musicKw = [
    '音乐', '歌曲', '专辑', '演唱会', 'live', '现场',
    '旋律', '歌词', '编曲', '吉他', '钢琴', '乐队',
    '歌手', '说唱', 'rap', '摇滚', '爵士', '古典', '民谣',
    '网易云', 'qq音乐', 'spotify', 'apple music', '播放列表',
    '翻唱', '原创', 'remix',
  ];
  for (final kw in musicKw) {
    if (lower.contains(kw)) return 'music';
  }

  // 软件
  const softwareKw = [
    '软件', 'app', '应用', '工具', '插件', '扩展',
    'vs code', 'chrome', '浏览器', '编辑器', 'ide',
    '效率', '笔记', '日历', '任务', '项目管理',
    'mac', 'windows', 'linux', 'ios', 'android app',
    '开源', '免费', '付费', '订阅',
  ];
  for (final kw in softwareKw) {
    if (lower.contains(kw)) return 'software';
  }

  // 旅游地点
  const travelKw = [
    '景点', '商场', '店', '球馆', '公园', '酒店', '城市',
    '旅游', '旅行', '出游', '打卡', '拍照', '风景', '景色',
    '海边', '山', '湖', '河', '博物馆', '展览', '美术馆',
    '动物园', '游乐园', '度假', '民宿', '露营',
    '机票', '高铁', '火车', '自驾',
  ];
  for (final kw in travelKw) {
    if (lower.contains(kw)) return 'travel';
  }

  return 'other';
}
