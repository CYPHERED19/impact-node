import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorData {
  final double ax;
  final double ay;
  final double az;
  final double gx;
  final double gy;
  final double gz;
  final double gForce;
  final double tiltAngle;
  final double gyroscopeMagnitude;
  final DateTime timestamp;

  SensorData({
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.gForce,
    required this.tiltAngle,
    required this.gyroscopeMagnitude,
    required this.timestamp,
  });
}

/// A recorded sudden-braking event for Analytics
class BrakingEvent {
  final DateTime timestamp;
  final double gForce;
  final double speedKmph;

  BrakingEvent({
    required this.timestamp,
    required this.gForce,
    required this.speedKmph,
  });
}

class SensorService extends ChangeNotifier {
  StreamSubscription? _accelSubscription;
  StreamSubscription? _gyroSubscription;

  double _gForce = 0.0;
  double _tiltAngle = 0.0;
  double _gyroscopeMagnitude = 0.0;
  bool _isMonitoring = false;

  // Raw sensors
  double _accelX = 0.0;
  double _accelY = 0.0;
  double _accelZ = 0.0;
  double _gyroX = 0.0;
  double _gyroY = 0.0;
  double _gyroZ = 0.0;

  // ── Session peak values (for Analytics) ──────────────────────────────────
  double _sessionPeakGForce = 0.0;
  double _sessionPeakTilt = 0.0;
  double _sessionPeakGyro = 0.0;

  // ── Sudden braking log (for Analytics) ───────────────────────────────────
  final List<BrakingEvent> _brakingEvents = [];
  static const double _brakingGForceThreshold = 2.0;
  DateTime? _lastBrakingEventTime;

  // Getters
  double get gForce => _gForce;
  double get tiltAngle => _tiltAngle;
  double get gyroscopeMagnitude => _gyroscopeMagnitude;
  bool get isMonitoring => _isMonitoring;

  // Session stats getters
  double get sessionPeakGForce => _sessionPeakGForce;
  double get sessionPeakTilt => _sessionPeakTilt;
  double get sessionPeakGyro => _sessionPeakGyro;
  List<BrakingEvent> get brakingEvents => List.unmodifiable(_brakingEvents);

  SensorData get currentData => SensorData(
        ax: _accelX,
        ay: _accelY,
        az: _accelZ,
        gx: _gyroX,
        gy: _gyroY,
        gz: _gyroZ,
        gForce: _gForce,
        tiltAngle: _tiltAngle,
        gyroscopeMagnitude: _gyroscopeMagnitude,
        timestamp: DateTime.now(),
      );

  // Stream controller for crash detection service to listen to
  final StreamController<SensorData> _sensorDataController =
      StreamController<SensorData>.broadcast();
  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;

  // ── External speed reference (set by app to detect braking) ──────────────
  double _currentSpeedRef = 0.0;
  void updateSpeedReference(double speedKmph) {
    _currentSpeedRef = speedKmph;
  }

  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    // Reset session peaks
    _sessionPeakGForce = 0.0;
    _sessionPeakTilt = 0.0;
    _sessionPeakGyro = 0.0;
    _brakingEvents.clear();
    _lastBrakingEventTime = null;

    _accelSubscription = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen((UserAccelerometerEvent event) {
      _accelX = event.x;
      _accelY = event.y;
      _accelZ = event.z;

      // Calculate resultant acceleration in G
      final double resultant = sqrt(
        _accelX * _accelX + _accelY * _accelY + _accelZ * _accelZ,
      );
      _gForce = resultant / 9.81;

      // Calculate tilt angle (angle from vertical)
      _tiltAngle = acos(_accelZ.clamp(-9.81, 9.81) / 9.81) * (180 / pi);

      // ── Track session peaks ─────────────────────────────────────────────
      if (_gForce > _sessionPeakGForce) _sessionPeakGForce = _gForce;
      if (_tiltAngle > _sessionPeakTilt) _sessionPeakTilt = _tiltAngle;

      // ── Detect sudden braking ───────────────────────────────────────────
      _checkSuddenBraking();

      _emitData();
      notifyListeners();
    });

    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen((GyroscopeEvent event) {
      // Convert from rad/s to deg/s
      _gyroX = event.x * (180 / pi);
      _gyroY = event.y * (180 / pi);
      _gyroZ = event.z * (180 / pi);
      _gyroscopeMagnitude = sqrt(_gyroX * _gyroX + _gyroY * _gyroY + _gyroZ * _gyroZ);

      if (_gyroscopeMagnitude > _sessionPeakGyro) {
        _sessionPeakGyro = _gyroscopeMagnitude;
      }

      _emitData();
      notifyListeners();
    });

    notifyListeners();
  }

  void _checkSuddenBraking() {
    if (_gForce < _brakingGForceThreshold) return;
    if (_currentSpeedRef < 5.0) return; // ignore if nearly stationary

    final now = DateTime.now();
    // Debounce: don't log more than 1 event per 3 seconds
    if (_lastBrakingEventTime != null &&
        now.difference(_lastBrakingEventTime!).inSeconds < 3) {
      return;
    }

    _brakingEvents.insert(
      0,
      BrakingEvent(
        timestamp: now,
        gForce: _gForce,
        speedKmph: _currentSpeedRef,
      ),
    );
    _lastBrakingEventTime = now;

    // Keep max 50 events
    if (_brakingEvents.length > 50) {
      _brakingEvents.removeLast();
    }
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription = null;
    _gForce = 0.0;
    _tiltAngle = 0.0;
    _gyroscopeMagnitude = 0.0;
    notifyListeners();
  }

  void _emitData() {
    if (!_sensorDataController.isClosed) {
      _sensorDataController.add(currentData);
    }
  }

  /// Reset session stats (for a fresh ride)
  void resetSession() {
    _sessionPeakGForce = 0.0;
    _sessionPeakTilt = 0.0;
    _sessionPeakGyro = 0.0;
    _brakingEvents.clear();
    _lastBrakingEventTime = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    _sensorDataController.close();
    super.dispose();
  }
}
