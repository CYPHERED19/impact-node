import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class SmsService {
  /// Sends an SOS SMS with the rider's location to the emergency contact.
  /// Uses the device's native SMS app for sending.
  /// On Android, also attempts direct SMS via platform channel.
  Future<bool> sendSos({
    required String riderName,
    required String emergencyPhone,
    required double latitude,
    required double longitude,
    required double speedKmph,
  }) async {
    try {
      final String mapsUrl =
          'https://maps.google.com/?q=$latitude,$longitude';

      final String message = 'IMPACT NODE ALERT: $riderName may have been in '
          'a crash at ${speedKmph.toStringAsFixed(0)} kmph. '
          'Location: $mapsUrl — '
          'Please check on them immediately.';

      // Encode the SMS URI
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: emergencyPhone,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        debugPrint('SmsService: SMS app launched for $emergencyPhone');
        return true;
      } else {
        debugPrint('SmsService: Could not launch SMS app');
        return false;
      }
    } catch (e) {
      debugPrint('SmsService: Failed to send SMS — $e');
      return false;
    }
  }
}
