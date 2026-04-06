class CrashEvent {
  final String? id;
  final String riderId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double speedKmph;
  final bool sosSent;
  final bool sosCancelled;
  final double gForcePeak;
  final double tiltAngle;
  final double gyroscopePeak;
  final double speedBefore;
  final double speedAfter;
  final int impactDurationMs;
  final bool falsePositive;
  final bool isNearMiss; // New for Analytics

  CrashEvent({
    this.id,
    required this.riderId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.speedKmph,
    required this.sosSent,
    required this.sosCancelled,
    required this.gForcePeak,
    required this.tiltAngle,
    required this.gyroscopePeak,
    required this.speedBefore,
    required this.speedAfter,
    required this.impactDurationMs,
    required this.falsePositive,
    this.isNearMiss = false,
  });

  factory CrashEvent.fromJson(Map<String, dynamic> json) {
    return CrashEvent(
      id: json['id'] as String?,
      riderId: json['rider_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      speedKmph: (json['speed_kmph'] as num).toDouble(),
      sosSent: json['sos_sent'] as bool,
      sosCancelled: json['sos_cancelled'] as bool,
      gForcePeak: (json['g_force_peak'] as num).toDouble(),
      tiltAngle: (json['tilt_angle'] as num).toDouble(),
      gyroscopePeak: (json['gyroscope_peak'] as num).toDouble(),
      speedBefore: (json['speed_before'] as num).toDouble(),
      speedAfter: (json['speed_after'] as num).toDouble(),
      impactDurationMs: json['impact_duration_ms'] as int,
      falsePositive: json['false_positive'] as bool,
      isNearMiss: json['is_near_miss'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rider_id': riderId,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'speed_kmph': speedKmph,
      'sos_sent': sosSent,
      'sos_cancelled': sosCancelled,
      'g_force_peak': gForcePeak,
      'tilt_angle': tiltAngle,
      'gyroscope_peak': gyroscopePeak,
      'speed_before': speedBefore,
      'speed_after': speedAfter,
      'impact_duration_ms': impactDurationMs,
      'false_positive': falsePositive,
      'is_near_miss': isNearMiss,
    };
  }
}
