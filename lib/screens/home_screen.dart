import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/sensor_service.dart';
import '../services/location_service.dart';
import '../services/ml_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/speed_display.dart';
import '../widgets/sensor_bar.dart';

class HomeScreen extends StatelessWidget {
  final String emergencyContactName;
  final String emergencyContactPhone;
  final VoidCallback onManualSos;

  const HomeScreen({
    super.key,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.onManualSos,
  });

  @override
  Widget build(BuildContext context) {
    final sensorService = context.watch<SensorService>();
    final locationService = context.watch<LocationService>();
    final mlService = context.watch<MLService>();
    final isMonitoring = sensorService.isMonitoring;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IMPACT',
                      style: AppTheme.labelStyle.copyWith(
                        fontSize: 16,
                        letterSpacing: 2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'NODE',
                      style: AppTheme.labelStyle.copyWith(
                        fontSize: 16,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _MonitoringBadge(isActive: isMonitoring),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () {
                        // Open the Right Sidebar
                        Scaffold.of(context).openEndDrawer();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder, width: 0.5),
                        ),
                        child: const Icon(Icons.menu, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Spacer(flex: 1),

            // Hero speed display
            SpeedDisplay(speed: locationService.currentSpeedKmph),

            const Spacer(flex: 1),

            // Sensor bars
            SensorBar(
              label: 'G-Force',
              value: sensorService.gForce,
              maxValue: 6.0,
              color: sensorService.gForce > 3.5
                  ? AppColors.activeRed
                  : AppColors.safeGreenLight,
              unit: 'G',
            ),

            SensorBar(
              label: 'Tilt Angle',
              value: sensorService.tiltAngle,
              maxValue: 180.0,
              color: sensorService.tiltAngle > 60
                  ? AppColors.warningAmber
                  : AppColors.safeGreenLight,
              unit: '°',
            ),

            const SizedBox(height: 12),

            // ML Risk Score
            if (mlService.isLoaded)
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: mlService.crashProbability,
                            color: mlService.riskScore < 30
                                ? AppColors.safeGreenLight
                                : mlService.riskScore < 65
                                    ? AppColors.warningAmber
                                    : AppColors.activeRed,
                            backgroundColor: AppColors.cardBorder,
                            strokeWidth: 5,
                          ),
                          Text(
                            '${mlService.riskScore}',
                            style: TextStyle(
                              color: mlService.riskScore < 30
                                  ? AppColors.safeGreenLight
                                  : mlService.riskScore < 65
                                      ? AppColors.warningAmber
                                      : AppColors.activeRed,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ML RISK SCORE',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.2,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mlService.riskLevel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: mlService.riskScore < 30
                                ? AppColors.safeGreenLight
                                : mlService.riskScore < 65
                                    ? AppColors.warningAmber
                                    : AppColors.activeRed,
                          ),
                        ),
                        const Text(
                          'Based on 800k real sensor readings',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.safeGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.safeGreenLight,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EMERGENCY CONTACT',
                          style: AppTheme.labelStyle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          emergencyContactName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          emergencyContactPhone,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Manual SOS button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onManualSos,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sosBtnBg,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emergency, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'MANUAL SOS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _MonitoringBadge extends StatelessWidget {
  final bool isActive;

  const _MonitoringBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.safeGreen.withValues(alpha: 0.15)
            : AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? AppColors.safeGreen.withValues(alpha: 0.3)
              : AppColors.cardBorder,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppColors.safeGreenLight : AppColors.label,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'MONITORING' : 'OFF',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isActive ? AppColors.safeGreenLight : AppColors.label,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
