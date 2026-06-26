import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/templates.dart' as tmpl;
import '../../../core/theme/app_design_tokens.dart';
import '../../../data/models/scoring_template.dart';
import '../../../providers/review_provider.dart';
import '../../../shared/widgets/icon_picker.dart';

/// 模板编辑/新建页
class TemplateEditPage extends ConsumerStatefulWidget {
  final ScoringTemplate? template;
  const TemplateEditPage({super.key, this.template});

  bool get isCreate => template == null;

  @override
  ConsumerState<TemplateEditPage> createState() => _TemplateEditPageState();
}

class _TemplateEditPageState extends ConsumerState<TemplateEditPage> {
  late final TextEditingController _nameCtrl;
  late String _icon;
  late final List<TextEditingController> _dimCtrls;
  bool _saving = false;

  bool get _isCreate => widget.isCreate;
  bool get _isBuiltIn => widget.template?.isBuiltIn ?? false;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _nameCtrl = TextEditingController(text: t?.name ?? '');
    _icon = t?.icon ?? '📦';
    _dimCtrls = (t?.dimensions ?? ['', '', '', ''])
        .map((d) => TextEditingController(text: d))
        .toList();
    while (_dimCtrls.length < 4) {
      _dimCtrls.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _dimCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg(brightness),
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isCreate ? '新建分类' : '编辑${widget.template!.name}'),
        backgroundColor: AppTokens.bg(brightness).withValues(alpha: 0.85),
        border: null,
        trailing: GestureDetector(
          onTap: _saving ? null : _save,
          child: _saving
              ? const CupertinoActivityIndicator()
              : const Text('保存',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.primary)),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const _Label(text: '名称'),
            const SizedBox(height: 6),
            Row(
              children: [
                GestureDetector(
                  onTap: () => IconPicker.show(
                    context,
                    currentIcon: _icon,
                    onSelected: (i) => setState(() => _icon = i),
                  ),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTokens.card(brightness),
                      borderRadius: BorderRadius.circular(AppTokens.radiusSM),
                      border: Border.all(
                          color: AppTokens.sep(brightness).withValues(alpha: 0.6)),
                    ),
                    alignment: Alignment.center,
                    child: Text(_icon, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CupertinoTextField(
                    controller: _nameCtrl,
                    placeholder: '分类名称',
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppTokens.card(brightness),
                      borderRadius: BorderRadius.circular(AppTokens.radiusMD),
                      border: Border.all(
                          color: AppTokens.sep(brightness).withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _Label(text: '评分维度（1-10 分）'),
            const SizedBox(height: 8),
            ...List.generate(4, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTokens.elevated(brightness),
                        borderRadius: BorderRadius.circular(AppTokens.radiusXS),
                      ),
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTokens.txt2(brightness))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CupertinoTextField(
                        controller: _dimCtrls[i],
                        placeholder: '维度 ${i + 1}',
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: AppTokens.card(brightness),
                          borderRadius: BorderRadius.circular(AppTokens.radiusSM),
                          border: Border.all(
                              color: AppTokens.sep(brightness).withValues(alpha: 0.6)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
            if (!_isCreate && _isBuiltIn)
              ActionButton(label: '恢复默认维度设置', color: AppTokens.warning, onTap: _resetBuiltIn),
            if (!_isCreate) ...[
              const SizedBox(height: 12),
              ActionButton(label: '删除此模板', color: AppTokens.danger, onTap: _confirmDelete),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);

    final dims = _dimCtrls.map((c) => c.text.trim()).where((d) => d.isNotEmpty).toList();
    final notifier = ref.read(templateListProvider.notifier);
    bool ok;

    if (_isCreate) {
      ok = await notifier.add(ScoringTemplate(
        id: const Uuid().v4(), name: name, icon: _icon,
        dimensions: dims, isBuiltIn: false, createdAt: DateTime.now(),
      ));
    } else {
      ok = await notifier.update(widget.template!.copyWith(name: name, icon: _icon, dimensions: dims));
    }

    if (mounted) { setState(() => _saving = false); if (ok) Navigator.of(context).pop(true); }
  }

  Future<void> _resetBuiltIn() async {
    final seed = tmpl.builtInTemplates.where((t) => t.id == widget.template!.id).firstOrNull;
    if (seed == null) return;
    HapticFeedback.mediumImpact();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('恢复「${widget.template!.name}」'),
        content: const Text('将恢复到默认的评分维度设置，确定吗？'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx, true), child: const Text('恢复默认')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(templateListProvider.notifier).update(seed);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _confirmDelete() async {
    HapticFeedback.mediumImpact();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('删除「${widget.template!.name}」'),
        content: const Text('删除后不可恢复，确定吗？'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(templateListProvider.notifier).delete(widget.template!.id);
    if (mounted) Navigator.of(context).pop(true);
  }
}

class ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const ActionButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTokens.radiusMD),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color))),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTokens.textSecondary));
  }
}
