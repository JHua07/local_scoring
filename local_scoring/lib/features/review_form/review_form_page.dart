import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/templates.dart' as tmpl;
import '../../core/utils/category_guesser.dart';
import '../../core/utils/score_utils.dart';
import '../../data/models/evaluation.dart';
import '../../data/models/review_item.dart';
import '../../data/models/scoring_template.dart';
import '../../data/repositories/local_json_review_repository.dart';
import '../../providers/review_provider.dart';

class ReviewFormPage extends ConsumerStatefulWidget {
  final ReviewItem? existingItem;

  const ReviewFormPage({super.key, this.existingItem});

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

  bool get isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
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

    _titleController.addListener(_onTextChanged);
    _reviewTextController.addListener(_onTextChanged);

    // 延迟加载模板并初始化维度
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDimensions();
    });
  }

  void _initDimensions() {
    final templates = ref.read(templateListProvider).templates;
    if (templates.isNotEmpty && _dimensions.isEmpty) {
      final dims = tmpl.getTemplateDefaultDimensions(templates, _category);
      setState(() => _dimensions = dims);
    }
  }

  void _onTextChanged() {
    if (!isEditing) {
      final text = '${_titleController.text} ${_reviewTextController.text}';
      final guessed = guessCategory(text);
      if (guessed != _category && _guessedCategory != guessed) {
        setState(() => _guessedCategory = guessed);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _reviewTextController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑评分' : '新增评分'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // 名称
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '名称 *',
                hintText: '例如：XX火锅、新买的耳机...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入名称' : null,
            ),
            const SizedBox(height: 16),

            // 分类
            Text('分类', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            _buildTemplateSelector(),
            if (_guessedCategory != null &&
                _guessedCategory != _category)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 16, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '系统猜你这是：${tmpl.getTemplateName(ref.watch(templateListProvider).templates, _guessedCategory!)}，可手动修改。',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // 图片
            Text(
              '图片（最多 3 张）',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
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
                                  const Icon(Icons.broken_image),
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
                                  Icons.close,
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
                      icon: Icons.photo_library_outlined,
                      label: '相册',
                    ),
                  if (_imagePaths.length < 3)
                    _AddImageButton(
                      onTap: () => _pickImage(ImageSource.camera),
                      icon: Icons.camera_alt_outlined,
                      label: '拍照',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 评价
            TextFormField(
              controller: _reviewTextController,
              decoration: InputDecoration(
                labelText: '一句话评价',
                hintText: '留下你的真实感受。',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // 标签
            TextFormField(
              controller: _tagController,
              decoration: InputDecoration(
                labelText: '标签',
                hintText: '输入标签后按回车添加',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _addTag,
                ),
              ),
              onFieldSubmitted: (_) => _addTag(),
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _tags.remove(tag);
                      });
                    },
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),

            // 多维评分
            Text(
              '多维评分',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '总分：${formatScore(calculateScore(_dimensions))}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            ..._dimensions.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: entry.value,
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: entry.value.toStringAsFixed(0),
                        onChanged: (v) {
                          setState(() {
                            _dimensions[entry.key] =
                                double.parse(v.toStringAsFixed(0));
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(
                        entry.value.toStringAsFixed(0),
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),

            // 值不值
            Text(
              '这次体验值不值？',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'worth', label: Text('👍 值')),
                ButtonSegment(value: 'normal', label: Text('👌 一般')),
                ButtonSegment(
                    value: 'not_worth', label: Text('👎 不值')),
              ],
              selected: {_worth},
              onSelectionChanged: (v) =>
                  setState(() => _worth = v.first),
              style: ButtonStyle(
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 再次体验
            SwitchListTile(
              value: _revisit,
              onChanged: (v) => setState(() => _revisit = v),
              title: const Text('什么值得再来一次？'),
              subtitle: const Text('是否会再次购买 / 体验'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            const SizedBox(height: 8),

            // 推荐给朋友
            SwitchListTile(
              value: _recommendToFriends,
              onChanged: (v) =>
                  setState(() => _recommendToFriends = v),
              title: const Text('推荐给朋友'),
              subtitle: const Text('是否愿意推荐给身边的人'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ],
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
    }
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
                  ChoiceChip(
                    label: Text('${t.icon} ${t.name}'),
                    selected: selected,
                    onSelected: (_) => _onTemplateSelected(t),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: BorderSide.none,
                  ),
                  // 子模板（缩进显示）
                  if (children.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: children.map((c) {
                          return ChoiceChip(
                            label: Text('${c.icon} ${c.name}',
                                style: const TextStyle(fontSize: 12)),
                            selected: _category == c.id,
                            onSelected: (_) =>
                                _onTemplateSelected(c),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10)),
                            side: BorderSide.none,
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
        TextButton.icon(
          onPressed: _showCreateTemplateDialog,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('新建自定义分类'),
        ),
      ],
    );
  }

  void _onTemplateSelected(ScoringTemplate template) {
    final templates = ref.read(templateListProvider).templates;
    setState(() {
      _category = template.id;
      _dimensions = tmpl.getTemplateDefaultDimensions(templates, template.id);
      _guessedCategory = null;
    });
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('新建自定义分类'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: '分类名称 *',
                      hintText: '例如：露营、桌游...'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: iconController,
                  decoration: const InputDecoration(
                      labelText: '图标 (Emoji)',
                      hintText: '例如：🏕️'),
                ),
                const SizedBox(height: 12),
                Text('评分维度（每个维度用 1-10 分滑块）',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                ...List.generate(4, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: dimControllers['dim$i'],
                      decoration: InputDecoration(
                          labelText: '维度 ${i + 1}',
                          hintText: i == 0 ? '例如：体验' : ''),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: parentId,
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('顶级分类（不归属任何模板）')),
                    ...topLevel.map((t) => DropdownMenuItem(
                        value: t.id,
                        child: Text('${t.icon} ${t.name} 的子项'))),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => parentId = v),
                  decoration:
                      const InputDecoration(labelText: '归属模板（可选）'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消')),
            FilledButton(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片选择失败：$e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入名称')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEditing ? '已更新' : '已保存')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: colorScheme.primary),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
