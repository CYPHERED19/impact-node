import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService extends ChangeNotifier {
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  double _currentSpeedKmph = 0.0;
  bool _isTracking = false;

  // ── Heading for map rotation ──────────────────────────────────────────────
  double _heading = 0.0;

  // ── Ride session stats (live, for Analytics) ──────────────────────────────
  DateTime? _rideStartTime;
  double _maxSpeedKmph = 0.0;
  double _totalSpeed = 0.0;
  int _speedSamples = 0;
  double _totalDistanceKm = 0.0;
  Position? _lastPosition;

  // Getters
  Position? get currentPosition => _currentPosition;
  double get currentSpeedKmph => _currentSpeedKmph;
  double get latitude => _currentPosition?.latitude ?? 0.0;
  double get longitude => _currentPosition?.longitude ?? 0.0;
  bool get isTracking => _isTracking;
  double get heading => _heading;

  // Session stats getters
  double get maxSpeedKmph => _maxSpeedKmph;
  double get avgSpeedKmph =>
      _speedSamples > 0 ? _totalSpeed / _speedSamples : 0.0;
  Duration get rideDuration => _rideStartTime != null
      ? DateTime.now().difference(_rideStartTime!)
      : Duration.zero;
  double get totalDistanceKm => _totalDistanceKm;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await requestPermission();
    if (!hasPermission) return;

    _isTracking = true;
    _rideStartTime = DateTime.now();
    _maxSpeedKmph = 0.0;
    _totalSpeed = 0.0;
    _speedSamples = 0;
    _totalDistanceKm = 0.0;
    _lastPosition = null;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _currentPosition = position;

      // Speed (m/s → kmph)
      if (position.speed >= 0) {
        _currentSpeedKmph = position.speed * 3.6;
      }

      // Heading
      if (position.heading >= 0) {
        _heading = position.heading;
      }

      // ── Session stats ───────────────────────────────────────────────────
      // Max speed
      if (_currentSpeedKmph > _maxSpeedKmph) {
        _maxSpeedKmph = _currentSpeedKmph;
      }

      // Average speed (rolling)
      if (_currentSpeedKmph > 0.5) {
        // ignore idle readings
        _totalSpeed += _currentSpeedKmph;
        _speedSamples++;
      }

      // Distance
      if (_lastPosition != null) {
        final distMeters = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        _totalDistanceKm += distMeters / 1000.0;
      }
      _lastPosition = position;

      notifyListeners();
    });

    // Get initial position
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (_currentPosition != null && _currentPosition!.heading >= 0) {
        _heading = _currentPosition!.heading;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('LocationService: Error getting initial position: $e');
    }

    notifyListeners();
  }

  void stopTracking() {
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _currentSpeedKmph = 0.0;
    notifyListeners();
  }

  /// Reset session stats (called when user wants a fresh ride)
  void resetSession() {
    _rideStartTime = DateTime.now();
    _maxSpeedKmph = 0.0;
    _totalSpeed = 0.0;
    _speedSamples = 0;
    _totalDistanceKm = 0.0;
    _lastPosition = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
