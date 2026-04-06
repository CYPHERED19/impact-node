import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SpeedDisplay extends StatelessWidget {
  final double speed;

  const SpeedDisplay({super.key, required this.speed});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SPEED',
          style: AppTheme.labelStyle,
        ),
        const SizedBox(height: 4),
        Text(
          speed.toStringAsFixed(0),
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 80,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1,
              ),
        ),
        Text(
          'KM/H',
          style: AppTheme.labelStyle.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}
