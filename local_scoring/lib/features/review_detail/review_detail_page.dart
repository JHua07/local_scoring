import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/templates.dart' as tmpl;
import '../../core/utils/date_formatters.dart';
import '../../data/models/annotation.dart';
import '../../data/models/evaluation.dart';
import '../../data/models/review_item.dart';
import '../../providers/review_provider.dart';
import '../../shared/widgets/confirm_phrase_dialog.dart';
import '../../shared/widgets/swipe_wrapper.dart';
import '../review_form/review_form_page.dart';

/// 评分详情页
/// 结构：图片轮播 → 标题分类 → 标签行 → 多维评分(先) → 评价(后) → 标签 → 时间线 → 时间戳
/// 时间线支持：左划编辑删除、展开批注(前5条+加载更多)、新增评分(全屏页)
class ReviewDetailPage extends ConsumerStatefulWidget {
  final String reviewId;
  final String? scrollToEvalId; // 跳转后滚动定位到指定评价

  const ReviewDetailPage({
    super.key,
    required this.reviewId,
    this.scrollToEvalId,
  });

  @override
  ConsumerState<ReviewDetailPage> createState() => _ReviewDetailPageState();
}

class _ReviewDetailPageState extends ConsumerState<ReviewDetailPage> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final item = state.items.where((r) => r.id == widget.reviewId).firstOrNull;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('评分不存在或已被删除')),
      );
    }

    final templates = ref.watch(templateListProvider).templates;
    final config = templates.isNotEmpty
        ? tmpl.getTemplateById(templates, item.category)
        : null;

    /// 是否为历史评分（创建超 24 小时）
    final isHistorical =
        DateTime.now().difference(item.createdAt).inHours >= 24;

    return Scaffold(
      appBar: AppBar(
        title: const Text('评分详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑',
            onPressed: () async {
              if (isHistorical) {
                final confirmed = await ConfirmPhraseDialog.show(
                  context,
                  title: '修改历史评价',
                  message: '此评分创建已超过 24 小时，修改需要确认。',
                  confirmLabel: '确认修改',
                );
                if (!confirmed) return;
              }
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReviewFormPage(existingItem: item),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
            onPressed: () => _confirmDelete(context, item, isHistorical),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // 图片轮播
          if (item.imagePaths.isNotEmpty) ...[
            SizedBox(
              height: 280,
              child: PageView.builder(
                itemCount: item.imagePaths.length,
                onPageChanged: (i) => setState(() => _currentImageIndex = i),
                itemBuilder: (_, i) {
                  final path = item.imagePaths[i];
                  final file = File(path);
                  if (!file.existsSync()) {
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: 48,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '图片不存在',
                              style: TextStyle(color: colorScheme.outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(file, fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            ),
            if (item.imagePaths.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    item.imagePaths.length,
                    (i) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _currentImageIndex
                            ? colorScheme.primary
                            : colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
          ],

          // 标题 & 分类
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    config != null
                        ? '${config.icon} ${config.name}'
                        : item.category,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 标签行（值不值 / 推荐 / 再体验）
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                if (item.worth == 'worth')
                  _Badge(
                    icon: Icons.thumb_up_alt,
                    label: '值',
                    color: const Color(0xFF4CAF50),
                  )
                else if (item.worth == 'not_worth')
                  _Badge(
                    icon: Icons.thumb_down_alt,
                    label: '不值',
                    color: const Color(0xFFEF5350),
                  )
                else
                  _Badge(
                    icon: Icons.thumbs_up_down,
                    label: '一般',
                    color: Colors.grey,
                  ),
                const SizedBox(width: 8),
                if (item.recommendToFriends)
                  _Badge(
                    icon: Icons.favorite,
                    label: '推荐给朋友',
                    color: const Color(0xFF7E57C2),
                  ),
                if (item.revisit)
                  _Badge(
                    icon: Icons.replay,
                    label: '会再体验',
                    color: const Color(0xFF26A69A),
                  ),
              ],
            ),
          ),

          // 最新多维评分（先于评价）
          if (item.dimensions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    '最新多维评分',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _LatestBadge(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: item.dimensions.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          _dimIcon(entry.key),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: Text(
                              entry.key,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: entry.value / 10,
                                minHeight: 8,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation(
                                  _getScoreColor(entry.value),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 24,
                            child: Text(
                              entry.value.toStringAsFixed(0),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],

          // 最新评价（后于多维评分）
          if (item.reviewText.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    '最新评价',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _LatestBadge(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  item.reviewText,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ],

          // 标签
          if (item.tags.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '标签',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: item.tags
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide.none,
                        backgroundColor: colorScheme.secondaryContainer,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],

          // ===== 时间线 =====
          const SizedBox(height: 8),
          _TimelineSection(
            item: item,
            scrollToEvalId: widget.scrollToEvalId,
            templateDims: templates.isNotEmpty
                ? tmpl.getTemplateById(templates, item.category).dimensions
                : const [],
            onAddAnnotation: (evalId, text) => ref
                .read(reviewListProvider.notifier)
                .addAnnotation(item.id, evalId, text),
            onAddEvaluation: (score, text, dimensions) {
              final ev = Evaluation(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                score: score,
                reviewText: text,
                dimensions: dimensions,
                createdAt: DateTime.now(),
              );
              return ref
                  .read(reviewListProvider.notifier)
                  .addEvaluation(item.id, ev);
            },
            onDeleteEval: (evalId) async {
              final updatedEvals = item.evaluations
                  .where((e) => e.id != evalId)
                  .toList();
              if (updatedEvals.isEmpty) return;
              await ref
                  .read(reviewListProvider.notifier)
                  .updateItem(
                    item.copyWith(
                      evaluations: updatedEvals,
                      updatedAt: DateTime.now(),
                    ),
                  );
            },
          ),

          // 时间
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(
              '创建时间',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              formatDateTime(item.createdAt),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              '最后更新',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              formatDateTime(item.updatedAt),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 8) return const Color(0xFF4CAF50);
    if (score >= 6) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }

  void _confirmDelete(
    BuildContext context,
    ReviewItem item,
    bool isHistorical,
  ) async {
    if (isHistorical) {
      final confirmed = await ConfirmPhraseDialog.show(
        context,
        title: '删除历史评价',
        message:
            '此评分创建已超过 24 小时，删除需要确认。\n'
            '删除后可在「设置 > 回收站」中恢复，30 天后永久删除。',
        confirmLabel: '确认删除',
        confirmColor: const Color(0xFFEF5350),
      );
      if (!confirmed) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认删除'),
          content: Text(
            '确定要删除「${item.title}」吗？\n'
            '删除后可在「设置 > 回收站」中恢复，30 天后永久删除。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350),
              ),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final success = await ref
        .read(reviewListProvider.notifier)
        .softDeleteItem(item.id);
    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已移入回收站')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除失败')));
      }
    }
  }
}

// ═══════════════════════════════════════════════════
//  时间线整体
// ═══════════════════════════════════════════════════

// ═══ 时间线区域（整体容器）═══
// 管理节点展开/折叠、入场动画、新增评价入口
class _TimelineSection extends StatefulWidget {
  final ReviewItem item;
  final List<String> templateDims;
  final String? scrollToEvalId; // 跳转后定位到指定评价
  final Future<void> Function(String evalId, String text) onAddAnnotation;
  final Future<bool> Function(
    double score,
    String text,
    Map<String, double> dimensions,
  )
  onAddEvaluation;
  final Future<void> Function(String evalId) onDeleteEval;
  const _TimelineSection({
    required this.item,
    required this.templateDims,
    this.scrollToEvalId,
    required this.onAddAnnotation,
    required this.onAddEvaluation,
    required this.onDeleteEval,
  });
  @override
  State<_TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<_TimelineSection>
    with SingleTickerProviderStateMixin {
  String? _expandedId;
  late AnimationController _anim;
  final _rowKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    // 为每个评价预生成 GlobalKey
    for (final e in widget.item.evaluations) {
      _rowKeys[e.id] = GlobalKey();
    }

    // 跳转定位：滚动到指定评价
    if (widget.scrollToEvalId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToEval(widget.scrollToEvalId!);
      });
    }
  }

  void _scrollToEval(String evalId) {
    final key = _rowKeys[evalId];
    if (key?.currentContext != null) {
      _expandedId = evalId; // 自动展开目标评价
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// 弹出全屏新增评价页
  void _addEval() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _EvalFormPage(
          templateDimensions: widget.templateDims,
          onSave: (score, text, dims) =>
              widget.onAddEvaluation(score, text, dims),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final evals = widget.item.evaluations;
    final latestId = widget.item.latestEvaluation?.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '评分时间线',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${evals.length} 次记录',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
          const SizedBox(height: 16),
          // 年份标题（在竖线 Stack 之外）
          ...(() {
            final divs = <Widget>[];
            int? lastYear;
            for (final eval in evals) {
              final year = eval.createdAt.year;
              if (year != lastYear) {
                if (lastYear != null) divs.add(const SizedBox(height: 4));
                divs.add(_YearDivider(year: year));
                lastYear = year;
              }
            }
            return divs;
          })(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              // ══ 一整根竖线（所有节点共用，上下各渐隐 3px）══
              Positioned(
                left: 67,
                top: -3,
                bottom: -3,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final h = constraints.maxHeight;
                    final fadeRatio = h > 6 ? (3.0 / h).clamp(0.0, 0.5) : 0.0;
                    return ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: const [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0.0, fadeRatio, 1.0 - fadeRatio, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: Container(
                        width: 2,
                        color: cs.outlineVariant.withValues(alpha: 0.3),
                      ),
                    );
                  },
                ),
              ),
              // 时间线节点列表
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...(() {
                    final widgets = <Widget>[];
                    for (int i = 0; i < evals.length; i++) {
                      final eval = evals[i];
                      final isLatest = eval.id == latestId;
                      final isExpanded = _expandedId == eval.id;
                      final isFirst = i == 0;
                      final isLast = i == evals.length - 1;
                      widgets.add(
                        _AnimBuilder(
                          key: _rowKeys[eval.id],
                          listenable: _anim,
                          builder: (context, child) {
                            final t = (_anim.value - i * 0.08).clamp(0.0, 1.0);
                            return Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(0, (1 - t) * 30),
                                child: _TimelineItem(
                                  eval: eval,
                                  isLatest: isLatest,
                                  isExpanded: isExpanded,
                                  isFirst: isFirst,
                                  isLast: isLast,
                                  onTap: () => setState(
                                    () => _expandedId = isExpanded
                                        ? null
                                        : eval.id,
                                  ),
                                  onAnnotate: (text) =>
                                      widget.onAddAnnotation(eval.id, text),
                                  onDelete: () => widget.onDeleteEval(eval.id),
                                  onEdit: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => _EvalFormPage(
                                        templateDimensions:
                                            eval.dimensions.keys.toList()
                                              ..addAll(
                                                widget.templateDims.where(
                                                  (d) => !eval.dimensions
                                                      .containsKey(d),
                                                ),
                                              ),
                                        existingEval: eval,
                                        onSave: (score, text, dims) => widget
                                            .onAddEvaluation(score, text, dims),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }
                    return widgets;
                  })(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),
          _AddBtn(onTap: _addEval),
        ],
      ),
    );
  }
}

// ═══ 入场动画辅助（staggered fade+slide up）═══
class _AnimBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  const _AnimBuilder({
    super.key,
    required super.listenable,
    required this.builder,
  });
  @override
  Widget build(BuildContext context) => builder(context, null);
}

// ═══ 年份标识 ═══
class _YearDivider extends StatelessWidget {
  final int year;
  const _YearDivider({required this.year});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: SizedBox(
        width: 72,
        child: Text(
          '$year',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: cs.primary,
          ),
        ),
      ),
    );
  }
}

// ═══ 新增评分按钮 ═══
class _AddBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _AddBtn({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
          color: cs.primary.withValues(alpha: 0.04),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              '新增一次评分',
              style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  TimelineItem：时间线上的单个评分节点
//
//  三列布局：TimeColumn | TrackColumn | ContentColumn
//  展开/收起只影响 ContentColumn 高度，TrackColumn
//  竖线通过 Expanded 自动跟随节点高度伸缩。
// ═══════════════════════════════════════════════════
class _TimelineItem extends StatefulWidget {
  final Evaluation eval;
  final bool isLatest, isExpanded, isFirst, isLast;
  final VoidCallback onTap;
  final Future<void> Function(String) onAnnotate;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  const _TimelineItem({
    required this.eval,
    required this.isLatest,
    required this.isExpanded,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    required this.onAnnotate,
    required this.onDelete,
    this.onEdit,
  });
  @override
  State<_TimelineItem> createState() => _TimelineItemState();
}

class _TimelineItemState extends State<_TimelineItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _expand;
  bool _showInput = false;
  int _showAnnotCount = 3; // 折叠态默认展示最近3条批注
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _expand = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    if (widget.isExpanded) _expand.forward();
  }

  @override
  void didUpdateWidget(_TimelineItem old) {
    super.didUpdateWidget(old);
    if (widget.isExpanded != old.isExpanded) {
      widget.isExpanded ? _expand.forward() : _expand.reverse();
    }
  }

  @override
  void dispose() {
    _expand.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _doAnnotate(String t) async {
    if (t.isEmpty) return;
    await widget.onAnnotate(t);
    if (mounted) {
      _ctrl.clear();
      setState(() => _showInput = false);
    }
  }

  /// 删除前弹出确认对话框
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除评价'),
        content: const Text('确认删除这条评价？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // ── ScoreMainCard 的视觉中心距卡片顶部的偏移（用于对齐圆点）──
  //   padding.top(8) + contentCenter(~14) ≈ 22
  static const double _cardCenterOffset = 22.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = widget.eval;
    final dotC = widget.isLatest ? cs.primary : cs.outlineVariant;
    final scoreC = widget.isLatest
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.6);
    final annots = e.annotations.reversed.toList();
    final hasGallery = e.imagePaths.length > 1;
    final shown = annots.length <= _showAnnotCount
        ? annots
        : annots.take(_showAnnotCount).toList();
    final dotSize = widget.isLatest ? 14.0 : 10.0;
    final dotTopOffset = _cardCenterOffset - dotSize / 2;

    // ═══ 三列布局：TimeColumn | TrackColumn | ContentColumn ══
    return SwipeActionWrapper(
      onDelete: _confirmDelete,
      onEdit: widget.onEdit,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ══ 左列：时间信息（58px 固定宽）══
            SizedBox(
              width: 58,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${e.createdAt.month}月${e.createdAt.day}日',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: dotC,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('HH:mm').format(e.createdAt),
                    style: TextStyle(fontSize: 10, color: cs.outline),
                  ),
                ],
              ),
            ),
            // ══ 中列：时间线轨道（20px 固定宽，整根竖线）══
            SizedBox(
              width: 20,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 圆点锚点
                  Positioned(
                    left: (20 - dotSize) / 2,
                    top: dotTopOffset,
                    child: Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        color: dotC,
                        shape: BoxShape.circle,
                        boxShadow: widget.isLatest
                            ? [
                                BoxShadow(
                                  color: dotC.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // ══ 右列：内容区（占剩余宽度）══
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── 评分主卡片 ──
                    _ScoreMainCard(
                      eval: e,
                      scoreColor: scoreC,
                      hasGallery: hasGallery,
                      isLatest: widget.isLatest,
                      isExpanded: widget.isExpanded,
                      onTap: widget.onTap,
                    ),
                    // ── 展开内容区 ──
                    SizeTransition(
                      sizeFactor: _expand,
                      alignment: Alignment.topCenter,
                      child: _ExpandedSection(
                        eval: e,
                        shown: shown,
                        annotCount: annots.length,
                        showAnnotCount: _showAnnotCount,
                        showInput: _showInput,
                        controller: _ctrl,
                        onLoadMore: () => setState(() => _showAnnotCount += 3),
                        onCollapseAnnotations: () =>
                            setState(() => _showAnnotCount = 3),
                        onToggleInput: () =>
                            setState(() => _showInput = !_showInput),
                        onDismissInput: () => setState(() {
                          _showInput = false;
                          _ctrl.clear();
                        }),
                        onSubmitAnnot: _doAnnotate,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══ 评分主卡片 ═══
class _ScoreMainCard extends StatelessWidget {
  final Evaluation eval;
  final Color scoreColor;
  final bool hasGallery;
  final bool isLatest;
  final bool isExpanded;
  final VoidCallback onTap;

  const _ScoreMainCard({
    required this.eval,
    required this.scoreColor,
    required this.hasGallery,
    required this.isLatest,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 卡片本体
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // 分数
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            eval.score.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: scoreColor,
                              height: 1,
                            ),
                          ),
                          Text(
                            '分',
                            style: TextStyle(
                              fontSize: 10,
                              color: scoreColor.withValues(alpha: 0.6),
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                      // 缩略图
                      if (eval.imagePaths.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: File(eval.imagePaths.first).existsSync()
                                    ? Image.file(
                                        File(eval.imagePaths.first),
                                        fit: BoxFit.cover,
                                      )
                                    : Icon(
                                        Icons.broken_image,
                                        size: 16,
                                        color: cs.outline,
                                      ),
                              ),
                            ),
                            if (hasGallery)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(1),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Icon(
                                    Icons.collections,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      // 评价摘要
                      if (eval.reviewText.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            eval.reviewText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 2),
                // 展开/折叠箭头
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more, size: 18, color: cs.outline),
                ),
              ],
            ),
          ),
        ),
        // "最新"标记（仅最新节点，附于卡片左上角）
        if (isLatest)
          Positioned(
            left: 6,
            top: -16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '最新',
                style: TextStyle(
                  fontSize: 9,
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ═══ 展开内容区（详情 + 图片 + 批注 + 输入）═══
class _ExpandedSection extends StatelessWidget {
  final Evaluation eval;
  final List<Annotation> shown;
  final int annotCount;
  final int showAnnotCount;
  final bool showInput;
  final TextEditingController controller;
  final VoidCallback onLoadMore;
  final VoidCallback onCollapseAnnotations;
  final VoidCallback onToggleInput;
  final VoidCallback onDismissInput;
  final void Function(String) onSubmitAnnot;

  const _ExpandedSection({
    required this.eval,
    required this.shown,
    required this.annotCount,
    required this.showAnnotCount,
    required this.showInput,
    required this.controller,
    required this.onLoadMore,
    required this.onCollapseAnnotations,
    required this.onToggleInput,
    required this.onDismissInput,
    required this.onSubmitAnnot,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 评价正文
          if (eval.reviewText.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                eval.reviewText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          // 多余图片
          if (eval.imagePaths.length > 1) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: eval.imagePaths.skip(1).map((p) {
                final f = File(p);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: f.existsSync()
                        ? Image.file(f, fit: BoxFit.cover)
                        : const Icon(Icons.broken_image, size: 24),
                  ),
                );
              }).toList(),
            ),
          ],
          // 批注列表
          ...shown.map(
            (a) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 13, color: cs.outline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.text,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        Text(
                          DateFormat('MM-dd HH:mm').format(a.createdAt),
                          style: TextStyle(fontSize: 10, color: cs.outline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 加载更多 / 收起批注
          if (showAnnotCount < annotCount)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  TextButton(
                    onPressed: onLoadMore,
                    child: Text(
                      '加载更多 (${annotCount - showAnnotCount} 条)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (showAnnotCount > 3)
                    TextButton(
                      onPressed: onCollapseAnnotations,
                      child: const Text('收起', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          if (showAnnotCount >= annotCount && showAnnotCount > 3)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextButton(
                onPressed: onCollapseAnnotations,
                child: const Text('收起', style: TextStyle(fontSize: 12)),
              ),
            ),
          const SizedBox(height: 6),
          // 批注输入
          if (showInput)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '说点什么...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) onSubmitAnnot(v.trim());
                    },
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  icon: const Icon(Icons.send, size: 14),
                  onPressed: () {
                    final t = controller.text.trim();
                    if (t.isNotEmpty) onSubmitAnnot(t);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  onPressed: onDismissInput,
                ),
              ],
            )
          else
            TextButton.icon(
              onPressed: onToggleInput,
              icon: const Icon(Icons.add_comment_outlined, size: 14),
              label: const Text('批注', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  全屏评价页（替代底部弹窗）
// ═══════════════════════════════════════════════════

// ═══ 全屏新增评价页 ═══
// 流程：图片上传 → 多维评分(滑块+自定义维度) → 综合分自动计算 → 评价文字
// 综合分 = 所有维度平均值，无独立分数滑块
class _EvalFormPage extends StatefulWidget {
  final List<String> templateDimensions;
  final Evaluation? existingEval; // 编辑模式：预填已有评价数据
  final Future<void> Function(
    double score,
    String text,
    Map<String, double> dims,
  )
  onSave;

  const _EvalFormPage({
    required this.templateDimensions,
    this.existingEval,
    required this.onSave,
  });

  @override
  State<_EvalFormPage> createState() => _EvalFormPageState();
}

class _EvalFormPageState extends State<_EvalFormPage> {
  late double _score;
  late Map<String, double> _dims;
  final _textCtrl = TextEditingController();
  final _dimCtrl = TextEditingController();
  final List<String> _imagePaths = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEval;
    if (existing != null) {
      // 编辑模式：预填已有数据
      _score = existing.score;
      _dims = Map.from(existing.dimensions);
      _textCtrl.text = existing.reviewText;
      _imagePaths.addAll(existing.imagePaths);
    } else {
      _score = 5.0;
      _dims = {for (final d in widget.templateDimensions) d: 5.0};
    }
    _recalc();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _dimCtrl.dispose();
    super.dispose();
  }

  /// 根据所有维度平均值重新计算综合分
  void _recalc() {
    if (_dims.isEmpty) return;
    final avg = _dims.values.fold<double>(0, (a, b) => a + b) / _dims.length;
    setState(() => _score = double.parse(avg.toStringAsFixed(1)));
  }

  void _addDim(String n) {
    final name = n.trim();
    if (name.isNotEmpty && !_dims.containsKey(name)) {
      setState(() {
        _dims[name] = 5.0;
        _dimCtrl.clear();
        _recalc();
      });
    }
  }

  /// 图片上传（从相册选择）
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked != null) setState(() => _imagePaths.add(picked.path));
    } catch (_) {}
  }

  /// 拍照（从相机获取）
  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked != null) setState(() => _imagePaths.add(picked.path));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dimEntries = _dims.entries.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('新增评分'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: cs.outline),
              const SizedBox(width: 6),
              Text(
                DateFormat('yyyy年M月d日 HH:mm').format(DateTime.now()),
                style: TextStyle(fontSize: 14, color: cs.outline),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 图片上传
          Text('图片（可选，最多3张）', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: Row(
              children: [
                ..._imagePaths.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 70,
                            height: 70,
                            child: Image.file(File(e.value), fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _imagePaths.removeAt(e.key)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_imagePaths.length < 3) ...[
                  _ImgBtn(
                    icon: Icons.photo_library_outlined,
                    label: '相册',
                    onTap: _pickImage,
                  ),
                  _ImgBtn(
                    icon: Icons.camera_alt_outlined,
                    label: '拍照',
                    onTap: _takePhoto,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 多维评分
          Text(
            '多维评分',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                ...dimEntries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        _dimIcon(e.key),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 56,
                          child: Text(
                            e.key,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: e.value,
                            min: 1,
                            max: 10,
                            divisions: 9,
                            activeColor: cs.primary,
                            onChanged: (v) {
                              _dims[e.key] = v.roundToDouble();
                              _recalc();
                            },
                          ),
                        ),
                        SizedBox(
                          width: 24,
                          child: Text(
                            e.value.toStringAsFixed(0),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                          ),
                        ),
                        if (!widget.templateDimensions.contains(e.key))
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              _dims.remove(e.key);
                              _recalc();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dimCtrl,
                        decoration: InputDecoration(
                          hintText: '自定义维度...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        style: const TextStyle(fontSize: 13),
                        onSubmitted: (v) => _addDim(v),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () => _addDim(_dimCtrl.text),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '综合：${_score.toStringAsFixed(1)} 分',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w300,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 评价文字
          TextField(
            controller: _textCtrl,
            decoration: InputDecoration(
              labelText: '一句话评价',
              hintText: '留下你的真实感受...',
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  void _addCustomDim() {
    showDialog(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('自定义维度'),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(hintText: '维度名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (c.text.trim().isNotEmpty) {
                  _addDim(c.text);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  /// 保存：回调 onSave(综合分, 评价文字, 维度Map)
  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(_score, _textCtrl.text.trim(), Map.from(_dims));
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }
}

class _ImgBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ImgBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            border: Border.all(
              color: cs.outline.withValues(alpha: 0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: cs.primary),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, color: cs.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 微标 / 图标 ──

class _LatestBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: cs.outline.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Latest!',
        style: TextStyle(
          fontSize: 10,
          color: cs.outline,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Icon _dimIcon(String name) {
  final icons = {
    '味道': Icons.restaurant,
    '价格': Icons.attach_money,
    '分量': Icons.scale,
    '复吃意愿': Icons.replay,
    '颜值': Icons.favorite_border,
    '质感': Icons.texture,
    '实用性': Icons.handyman,
    '后悔程度': Icons.sentiment_dissatisfied,
    '剧情': Icons.movie,
    '节奏': Icons.speed,
    '演技': Icons.theater_comedy,
    '推荐度': Icons.recommend,
    '旋律': Icons.music_note,
    '歌词': Icons.lyrics,
    '编曲': Icons.queue_music,
    '耐听度': Icons.headphones,
    '易用性': Icons.touch_app,
    '功能': Icons.grid_view,
    '稳定性': Icons.shield_outlined,
    '性价比': Icons.savings,
    '好玩程度': Icons.sports_esports,
    '耐玩度': Icons.replay_circle_filled,
    '画面': Icons.palette,
    '上手难度': Icons.psychology,
    '风景': Icons.landscape,
    '便利度': Icons.directions_transit,
    '环境': Icons.park,
    '体验': Icons.emoji_emotions,
    '态度': Icons.mood,
    '效率': Icons.bolt,
    '专业度': Icons.workspace_premium,
    '灯光': Icons.lightbulb,
    '舒适度': Icons.chair,
    '场地': Icons.place,
    '配角': Icons.group,
  };
  return Icon(icons[name] ?? Icons.star_outline, size: 16, color: Colors.grey);
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
