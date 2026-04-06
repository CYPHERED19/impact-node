import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool get isFirstLaunch => _prefs.getBool('isFirstLaunch') ?? true;
  static Future<void> setFirstLaunchComplete() async {
    await _prefs.setBool('isFirstLaunch', false);
  }

  static String get riderName => _prefs.getString('riderName') ?? "Alex Mitchell";
  static Future<void> setRiderName(String value) async => await _prefs.setString('riderName', value);

  static String get bloodType => _prefs.getString('bloodType') ?? "O+";
  static Future<void> setBloodType(String value) async => await _prefs.setString('bloodType', value);

  static String get emergencyContactName => _prefs.getString('emergencyContactName') ?? "Sarah Mitchell";
  static Future<void> setEmergencyContactName(String value) async => await _prefs.setString('emergencyContactName', value);

  static String get emergencyContactPhone => _prefs.getString('emergencyContactPhone') ?? "555-0199";
  static Future<void> setEmergencyContactPhone(String value) async => await _prefs.setString('emergencyContactPhone', value);
}
