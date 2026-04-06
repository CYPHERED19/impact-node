import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'models/rider.dart';
import 'models/crash_event.dart';
import 'services/sensor_service.dart';
import 'services/location_service.dart';
import 'services/crash_detection_service.dart';
import 'services/sms_service.dart';
import 'services/supabase_service.dart';
import 'services/offline_cache_service.dart';
import 'services/database_service.dart';
import 'services/preferences_service.dart';
import 'services/ml_service.dart';
import 'screens/home_screen.dart';
import 'screens/crash_countdown_screen.dart';
import 'screens/history_screen.dart';
import 'screens/map_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/emergency_screen.dart';

class App extends StatelessWidget {
  final bool isFirstLaunch;
  const App({super.key, this.isFirstLaunch = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Impact Node',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: isFirstLaunch ? const OnboardingScreen() : const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  bool _showCountdown = false;

  /// Set to true after SOS is confirmed — switches map to emergency mode
  bool _emergencyMapMode = false;

  final List<CrashEvent> _events = [];

  late Rider _rider;
  late SmsService _smsService;

  @override
  void initState() {
    super.initState();
    _smsService = SmsService();

    _rider = Rider(
      id: 'a1b2c3d4-e5f6-4a1b-8c2d-9e8f7a6b5c4d',
      name: PreferencesService.riderName,
      phone: '+91 9876543210',
      emergencyContactName: PreferencesService.emergencyContactName,
      emergencyContactPhone: PreferencesService.emergencyContactPhone,
      vehicleType: PreferencesService.bloodType, // repurposed field
      createdAt: DateTime.now(),
    );

    // Dynamic state listener triggers on prefs changes if necessary
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _setupCrashDetection();
      _setupSpeedFeed();
      _setupMLFeed();
    });
  }

  Future<void> _loadInitialData() async {
    // Note: Rider profile is now loaded synchronously via PreferencesService
    // Load historical crashes from SQLite
    try {
      final dbCrashes = await DatabaseService.getAllCrashes();
      if (mounted) {
        setState(() {
          _events.clear();
          _events.addAll(dbCrashes);
        });
      }
    } catch (e) {
      debugPrint('Error loading crash history from SQLite: $e');
    }
  }

  Future<void> _saveRiderProfile(Rider rider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rider_id', rider.id);
    await prefs.setString('rider_name', rider.name);
    await prefs.setString('rider_phone', rider.phone);
    await prefs.setString('emergency_contact_name', rider.emergencyContactName);
    await prefs.setString(
        'emergency_contact_phone', rider.emergencyContactPhone);
    await prefs.setString('vehicle_type', rider.vehicleType);
    setState(() => _rider = rider);
  }

  void _setupCrashDetection() {
    final crashDetection = context.read<CrashDetectionService>();
    crashDetection.onCrashDetected = () {
      setState(() {
        _showCountdown = true;
      });
    };
  }

  /// Feed GPS speed into SensorService so braking detection knows the speed
  void _setupSpeedFeed() {
    final locationService = context.read<LocationService>();
    final sensorService = context.read<SensorService>();

    locationService.addListener(() {
      sensorService.updateSpeedReference(locationService.currentSpeedKmph);
    });
  }

  /// Feed live sensor readings into MLService for real-time risk scoring
  void _setupMLFeed() {
    final sensorService = context.read<SensorService>();
    final mlService = context.read<MLService>();

    sensorService.sensorDataStream.listen((data) {
      mlService.processSensorReading(
        ax: data.ax,
        ay: data.ay,
        az: data.az,
        gx: data.gx,
        gy: data.gy,
        gz: data.gz,
        gForce: data.gForce,
        gyroMagnitude: data.gyroscopeMagnitude,
        tiltAngle: data.tiltAngle,
      );
    });
  }

  void _onManualSos() {
    setState(() {
      _showCountdown = true;
    });
  }

  void _onSendSosNow() async {
    final locationService = context.read<LocationService>();
    final crashDetection = context.read<CrashDetectionService>();

    // ── 1. Build crash event ─────────────────────────────────────────────
    final event = CrashEvent(
      riderId: _rider.id,
      timestamp: DateTime.now(),
      latitude: locationService.latitude,
      longitude: locationService.longitude,
      speedKmph: locationService.currentSpeedKmph,
      sosSent: true,
      sosCancelled: false,
      gForcePeak: crashDetection.peakGForce,
      tiltAngle: crashDetection.maxTilt,
      gyroscopePeak: crashDetection.peakGyro,
      speedBefore: crashDetection.speedAtImpact,
      speedAfter: locationService.currentSpeedKmph,
      impactDurationMs: 0,
      falsePositive: false,
    );

    // ── 2. Log to Supabase FIRST to prevent focus death ─────────
    await SupabaseService.insertCrashEvent(event);
    await OfflineCacheService.upsertCrashEvent({
      ...event.toJson(),
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'rider_id': _rider.id,
    });
    
    await DatabaseService.insertCrash(event);

    // ── 3. Fire SMS SOS via url_launcher ───────────────────────
    final bool smsSent = await _smsService.sendSos(
      riderName: _rider.name,
      emergencyPhone: _rider.emergencyContactPhone,
      latitude: locationService.latitude,
      longitude: locationService.longitude,
      speedKmph: locationService.currentSpeedKmph,
    );


    if (mounted) {
      if (smsSent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 SOS DISPATCHED SUCCESSFULLY IN BACKGROUND!'),
            backgroundColor: AppColors.safeGreen,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ SMS FAILED: Check Android Permissions!'),
            backgroundColor: AppColors.warningAmber,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }


    setState(() {
      _events.insert(0, event);
      _showCountdown = false;

      // ── 4. Auto-switch to Emergency Map mode ─────────────────────────
      _emergencyMapMode = true;
      _currentIndex = 3; // Map tab
    });

    crashDetection.resetAfterCrash();
  }

  void _onCancelSos() async {
    final locationService = context.read<LocationService>();
    final crashDetection = context.read<CrashDetectionService>();

    final event = CrashEvent(
      riderId: _rider.id,
      timestamp: DateTime.now(),
      latitude: locationService.latitude,
      longitude: locationService.longitude,
      speedKmph: locationService.currentSpeedKmph,
      sosSent: false,
      sosCancelled: true,
      gForcePeak: crashDetection.peakGForce,
      tiltAngle: crashDetection.maxTilt,
      gyroscopePeak: crashDetection.peakGyro,
      speedBefore: crashDetection.speedAtImpact,
      speedAfter: locationService.currentSpeedKmph,
      impactDurationMs: 0,
      falsePositive: true,
    );

    await SupabaseService.insertCrashEvent(event);

    setState(() {
      _events.insert(0, event);
      _showCountdown = false;
    });

    crashDetection.resetAfterCrash();
  }

  @override
  Widget build(BuildContext context) {
    if (_showCountdown) {
      return CrashCountdownScreen(
        emergencyContactName: _rider.emergencyContactName,
        emergencyContactPhone: _rider.emergencyContactPhone,
        onSendSosNow: _onSendSosNow,
        onCancelSos: _onCancelSos,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      endDrawer: _buildRightSidebar(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            emergencyContactName: _rider.emergencyContactName,
            emergencyContactPhone: _rider.emergencyContactPhone,
            onManualSos: _onManualSos,
          ),
          const AnalyticsScreen(),
          const EmergencyScreen(),
          MapScreen(emergencyMode: _emergencyMapMode),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            if (index != 3) _emergencyMapMode = false;
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.activeRed,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_outlined),
            activeIcon: Icon(Icons.show_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emergency_outlined),
            activeIcon: Icon(Icons.emergency),
            label: 'Emergency',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.public_outlined),
            activeIcon: Icon(Icons.public),
            label: 'Map',
          ),
        ],
      ),
    );
  }

  Widget _buildRightSidebar() {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.activeRed.withOpacity(0.2),
                    child: Text(
                      _rider.name.isNotEmpty
                          ? _rider.name[0].toUpperCase()
                          : 'A',
                      style: const TextStyle(
                          color: AppColors.activeRed,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_rider.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        Text(_rider.phone,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.cardBorder),
            ListTile(
              leading: const Icon(Icons.person_outline,
                  color: AppColors.textSecondary),
              title: const Text('Profile',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        backgroundColor: AppColors.background,
                        appBar: AppBar(
                          title: const Text('Profile',
                              style: TextStyle(fontSize: 16)),
                          backgroundColor: AppColors.background,
                        ),
                        body: ProfileScreen(
                            rider: _rider, onSave: _saveRiderProfile),
                      ),
                    ));
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.history, color: AppColors.textSecondary),
              title: const Text('History',
                  style: TextStyle(color: Colors.white)),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.activeRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                    '${_events.length} event${_events.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: AppColors.activeRed, fontSize: 10)),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        backgroundColor: AppColors.background,
                        appBar: AppBar(
                            title: const Text('History',
                                style: TextStyle(fontSize: 16)),
                            backgroundColor: AppColors.background),
                        body: HistoryScreen(events: _events),
                      ),
                    ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.call_outlined,
                  color: AppColors.textSecondary),
              title: const Text('Emergency SOS',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _onManualSos();
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_hospital_outlined,
                  color: AppColors.textSecondary),
              title: const Text('Nearby Help',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Hospital · Police · Towing',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined,
                  color: AppColors.textSecondary),
              title: const Text('Settings',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        backgroundColor: AppColors.background,
                        appBar: AppBar(
                            title: const Text('Settings',
                                style: TextStyle(fontSize: 16)),
                            backgroundColor: AppColors.background),
                        body: const _SettingsScreen(),
                      ),
                    ));
              },
            ),
            const Divider(color: AppColors.cardBorder),
            const Spacer(),
            ListTile(
              leading:
                  const Icon(Icons.logout, color: AppColors.textSecondary),
              title: const Text('Sign out',
                  style: TextStyle(color: AppColors.textSecondary)),
              onTap: () => Navigator.pop(context),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 24.0, left: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Impact Node v1.2.0',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    final sensorService = context.watch<SensorService>();
    final locationService = context.watch<LocationService>();
    final crashDetection = context.watch<CrashDetectionService>();
    final isMonitoring = sensorService.isMonitoring;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text('SETTINGS',
                style: AppTheme.labelStyle
                    .copyWith(fontSize: 12, letterSpacing: 2)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder, width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Crash Monitoring',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                          isMonitoring
                              ? 'Active — sensors running'
                              : 'Paused — tap to enable',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                  Switch(
                    value: isMonitoring,
                    activeTrackColor: AppColors.safeGreenLight,
                    onChanged: (value) {
                      if (value) {
                        sensorService.startMonitoring();
                        locationService.startTracking();
                        crashDetection.startDetection();
                      } else {
                        sensorService.stopMonitoring();
                        locationService.stopTracking();
                        crashDetection.stopDetection();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder, width: 0.5),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Impact Node',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                  SizedBox(height: 2),
                  Text('Version 1.2.0 · ROADSoS — Crash detection for riders',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
