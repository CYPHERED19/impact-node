import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/sensor_service.dart';
import '../services/location_service.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sensorService = context.watch<SensorService>();
    final locationService = context.watch<LocationService>();

    final avgSpeed = locationService.avgSpeedKmph;
    final maxSpeed = locationService.maxSpeedKmph;
    final currentSpeed = locationService.currentSpeedKmph;
    final distance = locationService.totalDistanceKm;
    final duration = locationService.rideDuration;
    final peakG = sensorService.sessionPeakGForce;
    final peakTilt = sensorService.sessionPeakTilt;
    final brakingEvents = sensorService.brakingEvents;

    final durationStr = _formatDuration(duration);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('A N A L Y T I C S',
                      style: AppTheme.labelStyle.copyWith(fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sensorService.isMonitoring
                          ? AppColors.safeGreen.withValues(alpha: 0.15)
                          : AppColors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: sensorService.isMonitoring
                            ? AppColors.safeGreen
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: Text(
                      sensorService.isMonitoring ? 'Live' : 'Paused',
                      style: TextStyle(
                        color: sensorService.isMonitoring
                            ? AppColors.safeGreenLight
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 1. Live Speed Stats ─────────────────────────────────
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SPEED STATS',
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SpeedStat(
                            label: 'CURRENT',
                            value: currentSpeed.toStringAsFixed(1),
                            unit: 'km/h',
                            color: AppColors.safeGreenLight,
                          ),
                        ),
                        Container(
                            width: 1,
                            height: 50,
                            color: AppColors.cardBorder),
                        Expanded(
                          child: _SpeedStat(
                            label: 'AVERAGE',
                            value: avgSpeed.toStringAsFixed(1),
                            unit: 'km/h',
                            color: Colors.blueAccent,
                          ),
                        ),
                        Container(
                            width: 1,
                            height: 50,
                            color: AppColors.cardBorder),
                        Expanded(
                          child: _SpeedStat(
                            label: 'MAX',
                            value: maxSpeed.toStringAsFixed(1),
                            unit: 'km/h',
                            color: AppColors.activeRed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── 2. Ride Session Stats ───────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                        'DURATION', durationStr, Colors.blueAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                        'DISTANCE',
                        '${distance.toStringAsFixed(2)} km',
                        AppColors.safeGreenLight),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('PEAK G-FORCE',
                        '${peakG.toStringAsFixed(2)}G', AppColors.activeRed),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                        'MAX TILT',
                        '${peakTilt.toStringAsFixed(1)}°',
                        AppColors.warningAmber),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── 3. Sudden Braking Log ───────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('SUDDEN BRAKING LOG',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.activeRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${brakingEvents.length} event${brakingEvents.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: AppColors.activeRed,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (brakingEvents.isEmpty)
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color:
                                AppColors.safeGreenLight.withValues(alpha: 0.5),
                            size: 36),
                        const SizedBox(height: 8),
                        const Text('No sudden braking detected',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13)),
                        const SizedBox(height: 4),
                        const Text(
                            'Hard braking events (>2G) will appear here',
                            style: TextStyle(
                                color: AppColors.label, fontSize: 11)),
                      ],
                    ),
                  ),
                )
              else
                ...brakingEvents.take(20).map((event) => _BrakingEventTile(
                      event: event,
                    )),

              const SizedBox(height: 100), // padding for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color valueColor) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.0,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: valueColor)),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }
}

class _SpeedStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _SpeedStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                letterSpacing: 0.8,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(unit,
            style:
                const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _BrakingEventTile extends StatelessWidget {
  final BrakingEvent event;

  const _BrakingEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(event.timestamp);
    final severity = event.gForce > 3.0
        ? 'Hard'
        : event.gForce > 2.5
            ? 'Medium'
            : 'Light';
    final severityColor = event.gForce > 3.0
        ? AppColors.activeRed
        : event.gForce > 2.5
            ? AppColors.warningAmber
            : Colors.blueAccent;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.warning_rounded,
                color: severityColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$severity braking',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                Text(
                    '$timeStr · ${event.speedKmph.toStringAsFixed(0)} km/h',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${event.gForce.toStringAsFixed(1)}G',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: severityColor)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
