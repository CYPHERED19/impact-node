import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../models/crash_event.dart';
import '../utils/pdf_export.dart';

class HistoryScreen extends StatelessWidget {
  final List<CrashEvent> events;
  final int totalRides;

  const HistoryScreen({
    super.key,
    required this.events,
    this.totalRides = 0,
  });

  int get _sosSentCount => events.where((e) => e.sosSent).length;
  int get _cancelledCount => events.where((e) => e.sosCancelled).length;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            Text(
              'HISTORY',
              style: AppTheme.labelStyle.copyWith(
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 16),

            // Metric cards row
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'TOTAL RIDES',
                    value: '$totalRides',
                    color: AppColors.safeGreenLight,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: 'SOS SENT',
                    value: '$_sosSentCount',
                    color: AppColors.activeRed,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: 'CANCELLED',
                    value: '$_cancelledCount',
                    color: AppColors.warningAmber,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Text(
              'EVENT LOG',
              style: AppTheme.labelStyle,
            ),

            const SizedBox(height: 8),

            // Event log list
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 48,
                            color: AppColors.label.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No events yet',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Ride safe — your history will appear here',
                            style: TextStyle(
                              color: AppColors.label,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        return _EventLogItem(event: events[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTheme.labelStyle,
          ),
        ],
      ),
    );
  }
}

class _EventLogItem extends StatelessWidget {
  final CrashEvent event;

  const _EventLogItem({required this.event});

  @override
  Widget build(BuildContext context) {
    final String eventType;
    final Color badgeColor;
    final String badgeText;

    if (event.sosSent && !event.sosCancelled) {
      eventType = 'Crash Alert';
      badgeColor = AppColors.activeRed;
      badgeText = 'SOS SENT';
    } else if (event.sosCancelled) {
      eventType = 'Crash Alert';
      badgeColor = AppColors.warningAmber;
      badgeText = 'CANCELLED';
    } else {
      eventType = 'Detection';
      badgeColor = AppColors.safeGreenLight;
      badgeText = 'SAFE';
    }

    final timeStr = _formatTime(event.timestamp);

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              event.sosSent
                  ? Icons.emergency
                  : Icons.check_circle_outline,
              color: badgeColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eventType,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$timeStr · ${event.speedKmph.toStringAsFixed(0)} kmph',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: badgeColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (event.sosSent)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: AppColors.textSecondary, size: 20),
              tooltip: 'Export incident report',
              onPressed: () {
                PdfExport.generateAndPrintCrashReport(event);
              },
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }
}
