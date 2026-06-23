import 'package:flutter/material.dart';

class ScoreBadge extends StatelessWidget {
  final double score;
  final double size;

  const ScoreBadge({super.key, required this.score, this.size = 48});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    if (score >= 8.0) {
      badgeColor = const Color(0xFF4CAF50);
    } else if (score >= 6.0) {
      badgeColor = const Color(0xFFFFA726);
    } else if (score > 0) {
      badgeColor = const Color(0xFFEF5350);
    } else {
      badgeColor = Colors.grey;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      alignment: Alignment.center,
      child: Text(
        score > 0 ? score.toStringAsFixed(1) : '-',
        style: TextStyle(
          color: Colors.white,
          fontSize: size / 2.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
