import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/templates.dart' as tmpl;
import '../../core/theme/app_design_tokens.dart';
import '../../data/models/scoring_template.dart';
import '../../providers/review_provider.dart';
import 'template_edit_page.dart';

class TemplateLibraryPage extends ConsumerStatefulWidget {
  const TemplateLibraryPage({super.key});

  @override
  ConsumerState<TemplateLibraryPage> createState() =>
      _TemplateLibraryPageState();
}

class _TemplateLibraryPageState
    extends ConsumerState<TemplateLibraryPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(templateListProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(templateListProvider);
    final brightness = CupertinoTheme.brightnessOf(context);
    final templates = state.templates;

    final builtIn = templates.where((t) => t.isBuiltIn).toList();
    final custom = templates.where((t) => !t.isBuiltIn).toList();

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg(brightness),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('分类模板库'),
        backgroundColor: AppTokens.bg(brightness).withValues(alpha: 0.85),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.question_circle,
              size: 22, color: AppTokens.txt2(brightness)),
          onPressed: _showRestoreAllDialog,
        ),
      ),
      child: SafeArea(
        child: state.isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                children: [
                  const _SectionTitle(text: '默认模板'),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: builtIn.map((t) => _GridCard(
                          template: t,
                          onTap: () => _editTemplate(t),
                        )).toList(),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(text: '自定义模板'),
                  if (custom.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('还没有自定义模板',
                          style: TextStyle(
                              fontSize: AppTokens.fontSizeCaption,
                              color: AppTokens.txt3(brightness)),
                          textAlign: TextAlign.center),
                    )
                  else
                    ...custom.map((t) => _CustomRow(
                          template: t,
                          onTap: () => _editTemplate(t),
                          onDelete: () => _confirmDelete(t),
                        )),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _createTemplate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTokens.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTokens.radiusMD),
                        border: Border.all(
                            color: AppTokens.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.add_circled,
                              size: 20, color: AppTokens.primary),
                          SizedBox(width: 6),
                          Text('新建自定义分类',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTokens.primary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _createTemplate() async {
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => const TemplateEditPage(),
      ),
    );
    if (result == true) ref.read(templateListProvider.notifier).loadAll();
  }

  void _editTemplate(ScoringTemplate template) async {
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => TemplateEditPage(template: template),
      ),
    );
    if (result == true) ref.read(templateListProvider.notifier).loadAll();
  }

  void _confirmDelete(ScoringTemplate template) async {
    HapticFeedback.mediumImpact();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('删除「${template.name}」'),
        content: const Text('删除后不可恢复，确定吗？'),
        actions: [
          CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(templateListProvider.notifier).delete(template.id);
  }

  void _showRestoreAllDialog() async {
    HapticFeedback.mediumImpact();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('恢复默认模板'),
        content: const Text(
          '默认模板不小心删除了？\n所有默认模板将恢复到初始设置。',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认恢复')),
          CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
        ],
      ),
    );
    if (ok != true) return;

    final notifier = ref.read(templateListProvider.notifier);
    for (final seed in tmpl.builtInTemplates) {
      final exists = ref.read(templateListProvider).templates.any((t) => t.id == seed.id);
      if (exists) {
        await notifier.update(seed);
      } else {
        await notifier.add(seed);
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTokens.textSecondary,
              letterSpacing: 0.3)),
    );
  }
}

class _GridCard extends StatelessWidget {
  final ScoringTemplate template;
  final VoidCallback onTap;
  const _GridCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);
    final cardWidth = (MediaQuery.of(context).size.width - 24 - 18) / 4;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: AppTokens.card(brightness),
          borderRadius: BorderRadius.circular(AppTokens.radiusMD),
          border: Border.all(
              color: AppTokens.sep(brightness).withValues(alpha: 0.6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(template.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(template.name,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.txt(brightness)),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _CustomRow extends StatelessWidget {
  final ScoringTemplate template;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _CustomRow({
    required this.template,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTokens.card(brightness),
          borderRadius: BorderRadius.circular(AppTokens.radiusMD),
          border: Border.all(
              color: AppTokens.sep(brightness).withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Text(template.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(template.name,
                  style: TextStyle(
                      fontSize: AppTokens.fontSizeBody,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.txt(brightness))),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: const Icon(CupertinoIcons.trash,
                  size: 18, color: AppTokens.danger),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
