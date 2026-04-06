import 'dart:async';
import 'package:flutter/foundation.dart';
import 'sensor_service.dart';
import 'location_service.dart';

class CrashDetectionService extends ChangeNotifier {
  final SensorService sensorService;
  final LocationService locationService;

  StreamSubscription? _sensorSubscription;
  bool _isDetecting = false;
  bool _crashDetected = false;

  // Threshold constants
  static const double gForceThreshold = 3.5;
  static const int gForceSustainedMs = 150;
  static const double gyroThreshold = 250.0; // deg/s
  static const double minSpeedKmph = 15.0;
  static const double speedDropPercent = 0.70;
  static const int speedDropWindowMs = 2000;
  static const int noRecoveryMs = 4000;

  // Internal state
  DateTime? _highGForceStart;
  bool _gForceSustained = false;
  bool _gyroTriggered = false;
  double _speedAtImpact = 0.0;
  DateTime? _impactTime;
  double _peakGForce = 0.0;
  double _peakGyro = 0.0;
  double _maxTilt = 0.0;

  // Callback when crash is detected
  VoidCallback? onCrashDetected;

  // Getters
  bool get isDetecting => _isDetecting;
  bool get crashDetected => _crashDetected;
  double get peakGForce => _peakGForce;
  double get peakGyro => _peakGyro;
  double get maxTilt => _maxTilt;
  double get speedAtImpact => _speedAtImpact;

  CrashDetectionService({
    required this.sensorService,
    required this.locationService,
  });

  void startDetection() {
    if (_isDetecting) return;
    _isDetecting = true;
    _resetState();

    _sensorSubscription = sensorService.sensorDataStream.listen(_processData);
    notifyListeners();
  }

  void stopDetection() {
    _isDetecting = false;
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _resetState();
    notifyListeners();
  }

  void _resetState() {
    _crashDetected = false;
    _highGForceStart = null;
    _gForceSustained = false;
    _gyroTriggered = false;
    _speedAtImpact = 0.0;
    _impactTime = null;
    _peakGForce = 0.0;
    _peakGyro = 0.0;
    _maxTilt = 0.0;
  }

  void resetAfterCrash() {
    _resetState();
    notifyListeners();
  }

  void _processData(SensorData data) {
    if (_crashDetected) return;

    // Track peaks
    if (data.gForce > _peakGForce) _peakGForce = data.gForce;
    if (data.gyroscopeMagnitude > _peakGyro) {
      _peakGyro = data.gyroscopeMagnitude;
    }
    if (data.tiltAngle > _maxTilt) _maxTilt = data.tiltAngle;

    final now = data.timestamp;

    // --- Condition 1: G-force > 3.5G sustained 150ms+ ---
    if (data.gForce > gForceThreshold) {
      _highGForceStart ??= now;
      final elapsed = now.difference(_highGForceStart!).inMilliseconds;
      if (elapsed >= gForceSustainedMs) {
        _gForceSustained = true;
      }
    } else {
      _highGForceStart = null;
      _gForceSustained = false;
    }

    // --- Condition 2: Gyroscope > 250 deg/s ---
    if (data.gyroscopeMagnitude > gyroThreshold) {
      _gyroTriggered = true;
    }

    // --- Condition 3: Speed before impact > 15 kmph ---
    final currentSpeed = locationService.currentSpeedKmph;

    // If we have high G-force + gyro and were going fast enough
    if (_gForceSustained && _gyroTriggered && _impactTime == null) {
      if (currentSpeed > minSpeedKmph || _speedAtImpact > minSpeedKmph) {
        if (_speedAtImpact == 0.0) {
          _speedAtImpact = currentSpeed;
        }
        _impactTime = now;
      }
    }

    // --- Condition 4: Speed drops 70%+ within 2 seconds ---
    if (_impactTime != null && _speedAtImpact > minSpeedKmph) {
      final timeSinceImpact = now.difference(_impactTime!).inMilliseconds;
      if (timeSinceImpact <= speedDropWindowMs) {
        final speedDrop =
            (_speedAtImpact - currentSpeed) / _speedAtImpact;
        if (speedDrop >= speedDropPercent) {
          // --- Condition 5: No recovery motion for 4 seconds ---
          // Check if device is relatively still (low G-force, low gyro)
          if (data.gForce < 1.5 && data.gyroscopeMagnitude < 50) {
            _triggerCrashAfterDelay(now);
          }
        }
      } else {
        // Window expired without speed drop → reset
        _impactTime = null;
        _speedAtImpact = 0.0;
        _gForceSustained = false;
        _gyroTriggered = false;
      }
    }
  }

  Timer? _noRecoveryTimer;

  void _triggerCrashAfterDelay(DateTime impactTime) {
    if (_noRecoveryTimer != null) return;

    _noRecoveryTimer = Timer(
      Duration(milliseconds: noRecoveryMs),
      () {
        // Final check — still no significant motion?
        final currentGForce = sensorService.gForce;
        final currentGyro = sensorService.gyroscopeMagnitude;

        if (currentGForce < 2.0 && currentGyro < 100) {
          _crashDetected = true;
          notifyListeners();
          onCrashDetected?.call();
        } else {
          // Recovery detected — reset
          _impactTime = null;
          _speedAtImpact = 0.0;
          _gForceSustained = false;
          _gyroTriggered = false;
        }
        _noRecoveryTimer = null;
      },
    );
  }

  @override
  void dispose() {
    _noRecoveryTimer?.cancel();
    stopDetection();
    super.dispose();
  }
}
