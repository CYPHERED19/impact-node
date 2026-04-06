import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/sensor_service.dart';
import 'services/location_service.dart';
import 'services/crash_detection_service.dart';
import 'services/supabase_service.dart';
import 'services/background_service.dart';
import 'services/ml_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D0D0F),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize Supabase
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Main: Supabase init failed — $e');
  }

  // Initialize background service
  try {
    await BackgroundServiceHelper.initialize();
  } catch (e) {
    debugPrint('Main: Background service init failed — $e');
  }

  // Create services
  final sensorService = SensorService();
  final locationService = LocationService();
  final crashDetectionService = CrashDetectionService(
    sensorService: sensorService,
    locationService: locationService,
  );
  final mlService = MLService();
  await mlService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sensorService),
        ChangeNotifierProvider.value(value: locationService),
        ChangeNotifierProvider.value(value: crashDetectionService),
        ChangeNotifierProvider.value(value: mlService),
      ],
      child: const App(),
    ),
  );
}
