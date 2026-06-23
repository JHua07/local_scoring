import 'package:flutter/material.dart';

import '../../core/constants/categories.dart';

class CategoryChip extends StatelessWidget {
  final String categoryId;
  final bool selected;

  const CategoryChip({
    super.key,
    required this.categoryId,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = getCategoryConfig(categoryId);
    final colorScheme = Theme.of(context).colorScheme;

    return Chip(
      avatar: Text(config.icon, style: const TextStyle(fontSize: 14)),
      label: Text(
        config.name,
        style: TextStyle(
          color: selected ? colorScheme.onPrimaryContainer : null,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      backgroundColor: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
