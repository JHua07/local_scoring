import 'package:flutter/material.dart';

/// 左划露出操作按钮，纯淡入淡出，按钮用 ClipRRect 消锯齿
class SwipeActionWrapper extends StatefulWidget {
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final Widget child;
  final double buttonWidth;
  const SwipeActionWrapper({super.key, required this.onDelete, this.onEdit, required this.child, this.buttonWidth = 56});
  @override
  State<SwipeActionWrapper> createState() => _SwipeActionWrapperState();
}

class _SwipeActionWrapperState extends State<SwipeActionWrapper> {
  double _dx = 0;

  double get _maxSlide {
    final count = widget.onEdit != null ? 2 : 1;
    return -(count * (widget.buttonWidth + 6) + 14); // +14 给箭头留呼吸空间
  }

  void _onDragUpdate(DragUpdateDetails d) => setState(() => _dx = (d.delta.dx + _dx).clamp(_maxSlide, 0.0));
  void _onDragEnd(DragEndDetails d) => setState(() => _dx = _dx < _maxSlide / 2 ? _maxSlide : 0.0);

  double _opa(int i) {
    final bw = widget.buttonWidth;
    final start = i * (bw + 6);
    final end = (i + 1) * (bw + 6);
    return ((-_dx - start) / (end - start)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final bw = widget.buttonWidth;
    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(right: 0, top: 4, bottom: 4, child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (widget.onEdit != null)
            Opacity(
              opacity: _opa(1), // 编辑在左边 → 后浮现
              child: GestureDetector(
                onTap: () { setState(() => _dx = 0); widget.onEdit!(); },
                child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Container(width: bw, height: double.infinity, color: const Color(0xFF78909C).withValues(alpha: 0.85), alignment: Alignment.center, child: const Icon(Icons.edit, color: Colors.white, size: 22))),
              ),
            ),
          if (widget.onEdit != null) const SizedBox(width: 6),
          Opacity(
            opacity: _opa(0), // 删除在最右侧 → 先浮现
            child: GestureDetector(
              onTap: () { setState(() => _dx = 0); widget.onDelete(); },
              child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Container(width: bw, height: double.infinity, color: const Color(0xFFA1887F).withValues(alpha: 0.85), alignment: Alignment.center, child: const Icon(Icons.delete_outline, color: Colors.white, size: 22))),
            ),
          ),
        ])),
        Transform.translate(offset: Offset(_dx, 0), child: widget.child),
      ]),
    );
  }
}
