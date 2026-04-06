import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class MLService extends ChangeNotifier {
  Interpreter? _interpreter;
  Map<String, dynamic>? _scalerConfig;

  double _crashProbability = 0.0;
  int _riskScore = 0; // 0–100
  String _riskLevel = 'Unknown';
  bool _isLoaded = false;

  // Sliding window: last 50 readings × 9 features
  final List<List<double>> _windowBuffer = [];
  static const int _windowSize = 50;

  double get crashProbability => _crashProbability;
  int get riskScore => _riskScore;
  String get riskLevel => _riskLevel;
  bool get isLoaded => _isLoaded;

  Future<void> initialize() async {
    try {
      // Load TFLite model from assets
      final modelData = await rootBundle.load('assets/crash_model.tflite');
      final modelBytes = modelData.buffer.asUint8List();
      _interpreter = Interpreter.fromBuffer(modelBytes);

      // Load scaler config
      final scalerJson =
          await rootBundle.loadString('assets/scaler_config.json');
      _scalerConfig = json.decode(scalerJson);

      _isLoaded = true;
      debugPrint('MLService: Model loaded (window=${_scalerConfig!['window_size']})');
      notifyListeners();
    } catch (e) {
      debugPrint('MLService: Failed to load model — $e');
    }
  }

  /// Called every time the sensor emits a new reading.
  void processSensorReading({
    required double ax,
    required double ay,
    required double az,
    required double gx,
    required double gy,
    required double gz,
    required double gForce,
    required double gyroMagnitude,
    required double tiltAngle,
  }) {
    if (!_isLoaded || _scalerConfig == null) return;

    final mins = List<double>.from(_scalerConfig!['mins']);
    final maxes = List<double>.from(_scalerConfig!['maxes']);

    // Normalize each feature to [0, 1]
    final rawFeatures = [ax, ay, az, gx, gy, gz, gForce, gyroMagnitude, tiltAngle];
    final normalized = List<double>.generate(rawFeatures.length, (i) {
      final range = maxes[i] - mins[i];
      if (range == 0) return 0.0;
      return ((rawFeatures[i] - mins[i]) / range).clamp(0.0, 1.0);
    });

    // Add to sliding window
    _windowBuffer.add(normalized);
    if (_windowBuffer.length > _windowSize) {
      _windowBuffer.removeAt(0);
    }

    // Run inference only when window is full
    if (_windowBuffer.length == _windowSize) {
      _runInference();
    }
  }

  void _runInference() {
    try {
      // Input shape: [1, 50, 9]
      final input = [List<List<double>>.from(_windowBuffer)];
      final output = [List<double>.filled(1, 0.0)];

      _interpreter!.run(input, output);

      final prob = (output[0][0]).clamp(0.0, 1.0);
      _crashProbability = prob;
      _riskScore = (prob * 100).round();

      if (prob < 0.30) {
        _riskLevel = 'Safe';
      } else if (prob < 0.65) {
        _riskLevel = 'Moderate';
      } else {
        _riskLevel = 'High Risk';
      }

      notifyListeners();
    } catch (e) {
      debugPrint('MLService: Inference error — $e');
    }
  }

  void reset() {
    _windowBuffer.clear();
    _crashProbability = 0.0;
    _riskScore = 0;
    _riskLevel = 'Unknown';
    notifyListeners();
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }
}
