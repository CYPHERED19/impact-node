import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class SmsService {
  /// Sends an SOS SMS with the rider's location to the emergency contact.
  /// Uses url_launcher to pop open the Phone's messaging app for prototype visibility.
  Future<bool> sendSos({
    required String riderName,
    required String emergencyPhone,
    required double latitude,
    required double longitude,
    required double speedKmph,
  }) async {
    try {
      final String mapsUrl = 'https://maps.google.com/?q=$latitude,$longitude';

      final String message = 'IMPACT NODE ALERT: $riderName may have been in '
          'a crash at ${speedKmph.toStringAsFixed(0)} kmph. '
          'Location: $mapsUrl — Please check on them immediately.';

      // Fallback clean phone number standard
      final cleanedPhone = emergencyPhone.replaceAll(RegExp(r'[^\d+]'), '');
      
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: cleanedPhone,
        queryParameters: <String, String>{
          'body': message,
        },
      );

      debugPrint('SmsService: Launching native SMS application...');
      
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        debugPrint('SmsService: Could not launch SMS intent.');
        return false;
      }
    } catch (e) {
      debugPrint('SmsService: Fatal error launching SMS intent — $e');
      return false;
    }
  }
}


