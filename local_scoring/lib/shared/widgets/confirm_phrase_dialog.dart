import 'package:flutter/material.dart';

/// 口令确认弹窗：要求用户逐字输入指定口令才能确认操作
class ConfirmPhraseDialog extends StatefulWidget {
  final String title;
  final String message;
  final String phrase;
  final String confirmLabel;
  final Color? confirmColor;
  final VoidCallback onConfirmed;

  const ConfirmPhraseDialog({
    super.key,
    required this.title,
    required this.message,
    this.phrase = '我确定修改/删除历史评价永不反悔',
    this.confirmLabel = '确认',
    this.confirmColor,
    required this.onConfirmed,
  });

  /// 弹出对话框并返回是否确认
  static Future<bool> show(
    BuildContext context, {
    String title = '确认操作',
    String message = '',
    String phrase = '我确定修改/删除历史评价永不反悔',
    String confirmLabel = '确认',
    Color? confirmColor,
  }) async {
    bool? result = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ConfirmPhraseDialog(
        title: title,
        message: message,
        phrase: phrase,
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
        onConfirmed: () {
          result = true;
          Navigator.pop(ctx);
        },
      ),
    );
    return result == true;
  }

  @override
  State<ConfirmPhraseDialog> createState() => _ConfirmPhraseDialogState();
}

class _ConfirmPhraseDialogState extends State<ConfirmPhraseDialog> {
  final _controller = TextEditingController();
  bool _isMatched = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_checkMatch);
  }

  void _checkMatch() {
    final matched = _controller.text == widget.phrase;
    if (matched != _isMatched) {
      setState(() => _isMatched = matched);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message.isNotEmpty) ...[
            Text(widget.message,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
          ],
          Text(
            '请输入以下文字以确认操作：',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              widget.phrase,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.error,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '逐字输入上方文字...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: _isMatched
                  ? Colors.green.withValues(alpha: 0.05)
                  : null,
              suffixIcon: _isMatched
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isMatched ? widget.onConfirmed : null,
          style: _isMatched && widget.confirmColor != null
              ? FilledButton.styleFrom(
                  backgroundColor: widget.confirmColor)
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
