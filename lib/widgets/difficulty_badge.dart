import 'package:flutter/material.dart';
import '/utils/app_themes.dart';

class DifficultyBadge extends StatelessWidget {
  const DifficultyBadge({
    super.key,
    required this.trudnosc,
    required this.ilosc,
  });
  final double trudnosc;
  final int ilosc;
  static const _kHardThreshold = 50.0;

  @override
  Widget build(BuildContext context) {
    if (ilosc < 5) return const SizedBox.shrink();
    final extras = Theme.of(context).extension<ExtraColors>()!;
    final isHard = trudnosc > _kHardThreshold;
    final color = isHard ? extras.incorrect : extras.correct;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHard ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${isHard ? "TRUDNE" : "ŁATWE"} ${trudnosc.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
