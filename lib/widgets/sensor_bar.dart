import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class SensorBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final String unit;

  const SensorBar({
    super.key,
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    this.unit = '',
  });

  @override
  Widget build(BuildContext context) {
    final double fraction = (value / maxValue).clamp(0.0, 1.0);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTheme.labelStyle,
              ),
              Text(
                '${value.toStringAsFixed(1)}$unit',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: AppColors.cardBorder,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
