import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/templates.dart' as tmpl;
import '../../core/theme/app_design_tokens.dart';
import '../../core/utils/category_guesser.dart';
import '../../core/utils/score_utils.dart';
import '../../core/utils/similar_record_detector.dart';
import '../../data/models/draft_item.dart';
import '../../data/models/evaluation.dart';
import '../../data/models/review_item.dart';
import '../../data/models/scoring_template.dart';
import '../../data/repositories/local_json_review_repository.dart';
import '../../providers/draft_provider.dart';
import '../../providers/review_provider.dart';
import '../../shared/widgets/ios_rating_row.dart';
import '../review_detail/review_detail_page.dart';

class ReviewFormPage extends ConsumerStatefulWidget {
  final ReviewItem? existingItem;
  final String? draftId; // 从草稿恢复时传入

  const ReviewFormPage({super.key, this.existingItem, this.draftId});

  @override
  ConsumerState<ReviewFormPage> createState() => _ReviewFormPageState();
}

class _ReviewFormPageState extends ConsumerState<ReviewFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final _picker = ImagePicker();

  late String _category;
  late Map<String, double> _dimensions;
  late List<String> _imagePaths;
  late List<String> _tags;

  final _titleController = TextEditingController();
  final _reviewTextController = TextEditingController();
  final _tagController = TextEditingController();

  String _worth = 'normal';
  bool _revisit = false;
  bool _recommendToFriends = false;
  String? _guessedCategory;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _poppedBySave = false; // 标记是否因保存退出，避免重复弹窗

  // 相似记录检测
  List<SimilarRecordResult> _similarRecords = [];
  Timer? _similarCheckTimer;

  bool get isEditing => widget.existingItem != null;
  bool get isFromDraft => widget.draftId != null;

  @override
  void initState() {
    super.initState();

    if (widget.draftId != null) {
      // 从草稿恢复
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDraft(widget.draftId!);
      });
    } else {
      _initFromExisting();
    }

    _titleController.addListener(_onChanged);
    _reviewTextController.addListener(_onChanged);
  }

  void _initFromExisting() {
    final item = widget.existingItem;
    _category = item?.category ?? 'food';
    _dimensions = item?.dimensions != null && item!.dimensions.isNotEmpty
        ? Map<String, double>.from(item.dimensions)
        : {};
    _imagePaths = item?.imagePaths != null
        ? List<String>.from(item!.imagePaths)
        : [];
    _tags = item?.tags != null ? List<String>.from(item!.tags) : [];
    _worth = item?.worth ?? 'normal';
    _revisit = item?.revisit ?? false;
    _recommendToFriends = item?.recommendToFriends ?? false;

    if (item != null) {
      _titleController.text = item.title;
      _reviewTextController.text = item.reviewText;
    }

    // 延迟加载模板并初始化维度
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDimensions();
    });
  }

  void _loadDraft(String draftId) {
    final draft = ref.read(draftListProvider.notifier).getById(draftId);
    if (draft == null) {
      _initFromExisting();
      return;
    }
    _category = draft.category;
    _dimensions = Map<String, double>.from(draft.dimensions);
    _imagePaths = List<String>.from(draft.imagePaths);
    _tags = List<String>.from(draft.tags);
    _worth = draft.worth;
    _revisit = draft.revisit;
    _recommendToFriends = draft.recommendToFriends;
    _titleController.text = draft.title;
    _reviewTextController.text = draft.reviewText;

    _isDirty = true; // 草稿视为有修改
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDimensions();
      setState(() {});
    });
  }

  void _onChanged() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
    // 同时处理分类猜测
    if (!isEditing && !isFromDraft) {
      final text = '${_titleController.text} ${_reviewTextController.text}';
      final guessed = guessCategory(text);
      if (guessed != _category && _guessedCategory != guessed) {
        setState(() => _guessedCategory = guessed);
      }
    }
    // 相似记录检测（防抖 400ms）
    _similarCheckTimer?.cancel();
    _similarCheckTimer = Timer(const Duration(milliseconds: 400), () {
      _checkSimilarRecords();
    });
  }

  void _checkSimilarRecords() {
    final title = _titleController.text.trim();
    final allItems = ref.read(reviewListProvider).items;
    final templates = ref.read(templateListProvider).templates;

    final results = SimilarRecordDetector.detect(
      currentTitle: title,
      currentCategory: _category,
      currentTags: _tags,
      allItems: allItems,
      templates: templates,
      excludeId: widget.existingItem?.id,
    );

    if (mounted) {
      setState(() => _similarRecords = results);
    }
  }

  void _initDimensions() {
    final templates = ref.read(templateListProvider).templates;
    if (templates.isNotEmpty && _dimensions.isEmpty) {
      final dims = tmpl.getTemplateDefaultDimensions(templates, _category);
      setState(() => _dimensions = dims);
    }
  }



  @override
  void dispose() {
    _titleController.dispose();
    _reviewTextController.dispose();
    _tagController.dispose();
    _similarCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: CupertinoPageScaffold(
        backgroundColor: AppTokens.bg(brightness),
        navigationBar: CupertinoNavigationBar(
          middle: Text(
            isFromDraft
                ? '继续编辑（草稿）'
                : isEditing
                    ? '编辑评分'
                    : '新增评分',
          ),
          backgroundColor: AppTokens.bg(brightness).withValues(alpha: 0.85),
          border: null,
          trailing: GestureDetector(
            onTap: _isSaving ? null : _save,
            child: _isSaving
                ? const CupertinoActivityIndicator()
                : const Text('保存',
                    style: TextStyle(fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.primary,
                    )),
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppTokens.pagePaddingH, 8, AppTokens.pagePaddingH, 32),
            children: [
              // 名称
              CupertinoTextFormFieldRow(
                controller: _titleController,
                placeholder: '比如：楼下那家牛肉面',
                prefix: const Text('名称 *',
                    style: TextStyle(fontSize: 15,
                      color: AppTokens.textSecondary,
                    )),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入名称' : null,
              ),
              const SizedBox(height: 12),

              // 相似记录提示
              _buildSimilarRecordsSection(brightness),

              const SizedBox(height: 4),

              // 分类
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '分类',
                  style: TextStyle(fontSize: AppTokens.fontSizeCaption,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.txt2(brightness),
                  ),
                ),
              ),
              _buildTemplateSelector(),
              if (_guessedCategory != null &&
                  _guessedCategory != _category)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.sparkles,
                          size: 16, color: AppTokens.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '系统猜这是：${tmpl.getTemplateName(ref.watch(templateListProvider).templates, _guessedCategory!)}，可手动修改。',
                          style: const TextStyle(fontSize: AppTokens.fontSizeCaption,
                            color: AppTokens.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // 图片
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '图片（最多 3 张）',
                  style: TextStyle(fontSize: AppTokens.fontSizeCaption,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.txt2(brightness),
                  ),
                ),
              ),
              SizedBox(
                height: 100,
                child: Row(
                  children: [
                    ..._imagePaths.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(entry.value),
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(CupertinoIcons.photo, size: 24),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _imagePaths.removeAt(entry.key);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.xmark,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (_imagePaths.length < 3)
                      _AddImageButton(
                        onTap: () => _pickImage(ImageSource.gallery),
                        icon: CupertinoIcons.photo,
                        label: '相册',
                      ),
                    if (_imagePaths.length < 3)
                      _AddImageButton(
                        onTap: () => _pickImage(ImageSource.camera),
                        icon: CupertinoIcons.camera,
                        label: '拍照',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 评价
              CupertinoTextFormFieldRow(
                controller: _reviewTextController,
                placeholder: '留下一句话，之后翻回来会很有用。',
                prefix: const Text('评价',
                    style: TextStyle(fontSize: 15,
                      color: AppTokens.textSecondary,
                    )),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // 标签
              CupertinoTextField(
                controller: _tagController,
                placeholder: '输入标签后按回车添加',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 12, right: 8),
                  child: Text('标签',
                      style: TextStyle(fontSize: 15,
                        color: AppTokens.textSecondary,
                      )),
                ),
                suffix: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _addTag,
                  child: const Icon(CupertinoIcons.add_circled,
                      size: 20, color: AppTokens.primary),
                ),
                onSubmitted: (_) => _addTag(),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTokens.primary.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tag,
                            style: const TextStyle(fontSize: 13,
                              color: AppTokens.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() => _tags.remove(tag));
                              _checkSimilarRecords();
                            },
                            child: const Icon(CupertinoIcons.xmark_circle_fill,
                                size: 16,
                                color: AppTokens.primary),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),

              // 多维评分
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '多维评分',
                  style: TextStyle(fontSize: AppTokens.fontSizeCaption,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.txt2(brightness),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '总分：${formatScore(calculateScore(_dimensions))}',
                  style: TextStyle(fontSize: AppTokens.fontSizeTitle,
                    fontWeight: FontWeight.w800,
                    color: AppTokens.primary,
                  ),
                ),
              ),
              ..._dimensions.entries.map((entry) {
                return IosRatingRow(
                  label: entry.key,
                  value: entry.value,
                  onChanged: (v) {
                    setState(() {
                      _dimensions[entry.key] =
                          double.parse(v.toStringAsFixed(0));
                    });
                  },
                );
              }),
              const SizedBox(height: 16),

              // 值不值
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '这次体验值不值？',
                  style: TextStyle(fontSize: AppTokens.fontSizeCaption,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.txt2(brightness),
                  ),
                ),
              ),
              CupertinoSlidingSegmentedControl<String>(
                groupValue: _worth,
                onValueChanged: (v) {
                  if (v != null) setState(() => _worth = v);
                },
                children: const {
                  'worth': Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Text('👍 值', style: TextStyle(fontSize: 14)),
                  ),
                  'normal': Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Text('👌 一般', style: TextStyle(fontSize: 14)),
                  ),
                  'not_worth': Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Text('👎 不值', style: TextStyle(fontSize: 14)),
                  ),
                },
              ),
              const SizedBox(height: 16),

              // 再次体验
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '以后还会再来吗？',
                          style: TextStyle(fontSize: AppTokens.fontSizeBody,
                            color: AppTokens.txt(brightness),
                          ),
                        ),
                        Text(
                          '是否再次购买 / 体验',
                          style: TextStyle(fontSize: AppTokens.fontSizeCaption,
                            color: AppTokens.txt2(brightness),
                          ),
                        ),
                      ],
                    ),
                    CupertinoSwitch(
                      value: _revisit,
                      onChanged: (v) =>
                          setState(() => _revisit = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 推荐
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '推荐给朋友吗？',
                          style: TextStyle(fontSize: AppTokens.fontSizeBody,
                            color: AppTokens.txt(brightness),
                          ),
                        ),
                        Text(
                          '是否愿意推荐给身边的人',
                          style: TextStyle(fontSize: AppTokens.fontSizeCaption,
                            color: AppTokens.txt2(brightness),
                          ),
                        ),
                      ],
                    ),
                    CupertinoSwitch(
                      value: _recommendToFriends,
                      onChanged: (v) =>
                          setState(() => _recommendToFriends = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 保存按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CupertinoButton.filled(
                  onPressed: _isSaving ? null : _save,
                  child: Text(isEditing ? '保存修改' : '保存评分'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
      _checkSimilarRecords();
    }
  }

  // ========== 相似记录检测 ==========

  Widget _buildSimilarRecordsSection(Brightness brightness) {
    if (_similarRecords.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(CupertinoIcons.clock, size: 16, color: AppTokens.warning),
            const SizedBox(width: 6),
            const Text(
              '发现相似记录',
              style: TextStyle(fontSize: 13,
                color: AppTokens.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${_similarRecords.length} 条',
              style: const TextStyle(fontSize: 13,
                color: AppTokens.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _similarRecords.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final result = _similarRecords[index];
              final item = result.item;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) =>
                          ReviewDetailPage(reviewId: item.id),
                    ),
                  );
                },
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTokens.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTokens.txt(brightness),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(CupertinoIcons.star,
                              size: 12, color: AppTokens.warning),
                          const SizedBox(width: 2),
                          Text(
                            item.score.toStringAsFixed(1),
                            style: TextStyle(fontSize: 12,
                              color: AppTokens.txt2(brightness),
                            ),
                          ),
                          if (result.matchedTagCount > 0) ...[
                            const SizedBox(width: 8),
                            const Icon(CupertinoIcons.tag,
                                size: 11, color: AppTokens.warning),
                            const SizedBox(width: 2),
                            Text(
                              '${result.matchedTagCount}个匹配标签',
                              style: TextStyle(fontSize: 11,
                                color: AppTokens.txt2(brightness),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ========== 模板选择器 ==========

  Widget _buildTemplateSelector() {
    final templateState = ref.watch(templateListProvider);
    final topLevel = templateState.topLevel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶级模板
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ...topLevel.map((t) {
              final selected = _category == t.id;
              final children = templateState.childrenOf(t.id);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTemplateChip('${t.icon} ${t.name}', selected, () => _onTemplateSelected(t)),
                  // 子模板（缩进显示）
                  if (children.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: children.map((c) {
                          return _buildTemplateChip(
                            '${c.icon} ${c.name}',
                            _category == c.id,
                            () => _onTemplateSelected(c),
                            isSmall: true,
                          );
                        }).toList(),
                      ),
                    ),
                ],
              );
            }),
          ],
        ),
        const SizedBox(height: 8),
        // 新建自定义分类按钮
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.add_circled, size: 18, color: AppTokens.primary),
              SizedBox(width: 4),
              Text('新建自定义分类', style: TextStyle(fontSize: 14, color: AppTokens.primary)),
            ],
          ),
          onPressed: _showCreateTemplateDialog,
        ),
      ],
    );
  }

  Widget _buildTemplateChip(String label, bool selected, VoidCallback onTap, {bool isSmall = false}) {
    final brightness = CupertinoTheme.brightnessOf(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 10 : 12,
          vertical: isSmall ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: selected ? AppTokens.primary : AppTokens.elevated(brightness),
          borderRadius: BorderRadius.circular(AppTokens.radiusFull),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: isSmall ? 12 : 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppTokens.textOnPrimary : AppTokens.txt(brightness),
          ),
        ),
      ),
    );
  }

  void _onTemplateSelected(ScoringTemplate template) {
    final templates = ref.read(templateListProvider).templates;
    setState(() {
      _category = template.id;
      _dimensions = tmpl.getTemplateDefaultDimensions(templates, template.id);
      _guessedCategory = null;
    });
    _checkSimilarRecords();
  }

  void _showCreateTemplateDialog() {
    final nameController = TextEditingController();
    final iconController = TextEditingController(text: '📦');
    String? parentId;
    final dimControllers = <String, TextEditingController>{};

    // 预填 4 个维度输入框
    for (var i = 0; i < 4; i++) {
      dimControllers['dim$i'] = TextEditingController();
    }

    final templateState = ref.read(templateListProvider);
    final topLevel = templateState.topLevel;

    showCupertinoDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: const Text('新建自定义分类'),
          content: Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoTextField(
                    controller: nameController,
                    placeholder: '分类名称 *',
                    padding: const EdgeInsets.all(12),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: iconController,
                    placeholder: '图标 (Emoji)',
                    padding: const EdgeInsets.all(12),
                  ),
                  const SizedBox(height: 12),
                  const Text('评分维度（每个维度用 1-10 分滑块）',
                      style: TextStyle(fontSize: 13, color: AppTokens.textSecondary)),
                  const SizedBox(height: 8),
                  ...List.generate(4, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CupertinoTextField(
                        controller: dimControllers['dim$i'],
                        placeholder: i == 0 ? '例如：体验' : '维度 ${i + 1}',
                        padding: const EdgeInsets.all(12),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  const Text('归属模板（可选）：',
                      style: TextStyle(fontSize: 13, color: AppTokens.textSecondary)),
                  ...topLevel.map((t) => GestureDetector(
                        onTap: () => setDialogState(() => parentId = parentId == t.id ? null : t.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                parentId == t.id
                                    ? CupertinoIcons.checkmark_circle_fill
                                    : CupertinoIcons.circle,
                                size: 18,
                                color: parentId == t.id
                                    ? AppTokens.primary
                                    : AppTokens.textWeak,
                              ),
                              const SizedBox(width: 8),
                              Text('${t.icon} ${t.name} 的子项',
                                  style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消')),
            CupertinoDialogAction(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final icon = iconController.text.trim().isEmpty
                    ? '📦'
                    : iconController.text.trim();
                final dims = List.generate(4, (i) {
                      final t =
                          dimControllers['dim$i']!.text.trim();
                      return t.isEmpty ? '维度${i + 1}' : t;
                    })
                    .where((d) => d.isNotEmpty)
                    .toList();

                final template = ScoringTemplate(
                  id: _uuid.v4(),
                  name: name,
                  icon: icon,
                  dimensions: dims,
                  parentTemplateId: parentId,
                  isBuiltIn: false,
                  createdAt: DateTime.now(),
                );

                final success = await ref
                    .read(templateListProvider.notifier)
                    .add(template);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  if (success) {
                    _onTemplateSelected(template);
                  }
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked != null) {
        final repo =
            ref.read(reviewRepositoryProvider) as LocalJsonReviewRepository;
        final savedPath = await repo.copyImageToLocal(picked.path);
        setState(() {
          _imagePaths.add(savedPath);
        });
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            content: Text('图片选择失败：$e'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_titleController.text.trim().isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          content: const Text('请输入名称'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final score = calculateScore(_dimensions);

    bool success;
    if (isEditing) {
      // 编辑已有条目 → 追加新评价
      final eval = Evaluation(
        id: _uuid.v4(),
        score: score,
        reviewText: _reviewTextController.text.trim(),
        imagePaths: _imagePaths,
        createdAt: now,
      );
      success = await ref
          .read(reviewListProvider.notifier)
          .addEvaluation(widget.existingItem!.id, eval);
      // 同时更新基础信息（分类/标签/维度等）
      final updatedItem = widget.existingItem!.copyWith(
        category: _category,
        worth: _worth,
        revisit: _revisit,
        recommendToFriends: _recommendToFriends,
        tags: _tags,
        dimensions: _dimensions,
        updatedAt: now,
      );
      await ref.read(reviewListProvider.notifier).updateItem(updatedItem);
    } else {
      // 新建条目 → 创建 ReviewItem + 第一条 Evaluation
      final item = ReviewItem(
        id: _uuid.v4(),
        title: _titleController.text.trim(),
        category: _category,
        worth: _worth,
        revisit: _revisit,
        recommendToFriends: _recommendToFriends,
        tags: _tags,
        dimensions: _dimensions,
        evaluations: [
          Evaluation(
            id: _uuid.v4(),
            score: score,
            reviewText: _reviewTextController.text.trim(),
            imagePaths: _imagePaths,
            createdAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      success = await ref.read(reviewListProvider.notifier).add(item);
    }

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        if (isFromDraft) {
          await ref.read(draftListProvider.notifier).delete(widget.draftId!);
        }
        _poppedBySave = true;
        Navigator.of(context).pop();
      } else {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            content: const Text('保存失败，请重试'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    }
  }

  // ========== 草稿相关 ==========

  DraftItem _buildDraftItem({String? existingId}) {
    final now = DateTime.now();
    return DraftItem(
      id: existingId ?? _uuid.v4(),
      title: _titleController.text.trim(),
      category: _category,
      worth: _worth,
      revisit: _revisit,
      recommendToFriends: _recommendToFriends,
      tags: List<String>.from(_tags),
      dimensions: Map<String, double>.from(_dimensions),
      imagePaths: List<String>.from(_imagePaths),
      reviewText: _reviewTextController.text.trim(),
      createdAt: existingId != null ? now : now,
      updatedAt: now,
    );
  }

  Future<void> _saveToDraft() async {
    if (isFromDraft) {
      // 更新已有草稿
      final draft = _buildDraftItem(existingId: widget.draftId);
      await ref.read(draftListProvider.notifier).updateDraft(draft);
    } else {
      // 新建草稿
      final draft = _buildDraftItem();
      await ref.read(draftListProvider.notifier).add(draft);
    }
  }

  /// 返回 true 表示可以退出
  Future<bool> _onWillPop() async {
    if (_poppedBySave) return true;

    // 检查是否有实质内容
    final hasContent = _titleController.text.trim().isNotEmpty ||
        _reviewTextController.text.trim().isNotEmpty ||
        _tags.isNotEmpty ||
        _imagePaths.isNotEmpty;

    if (!hasContent && !_isDirty) return true;

    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('未保存的内容'),
        content: const Text('当前编辑的内容尚未保存，是否存入草稿箱？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            isDestructiveAction: true,
            child: const Text('放弃'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, 'draft'),
            isDefaultAction: true,
            child: const Text('存入草稿箱'),
          ),
        ],
      ),
    );

    switch (result) {
      case 'draft':
        await _saveToDraft();
        return true;
      case 'discard':
        // 如果是来自草稿，抛弃时顺便删除旧草稿
        if (isFromDraft) {
          await ref.read(draftListProvider.notifier).delete(widget.draftId!);
        }
        return true;
      case 'cancel':
        return false;
      default:
        return false;
    }
  }
}

class _AddImageButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;

  const _AddImageButton({
    required this.onTap,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            border: Border.all(
              color: AppTokens.sep(brightness).withValues(alpha: 0.8),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
            color: AppTokens.elevated(brightness),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: AppTokens.primary),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 11,
                  color: AppTokens.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
