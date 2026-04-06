import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService {
  static const MethodChannel _channel = MethodChannel('com.impactnode.sms/direct');

  /// Sends an SOS SMS with the rider's location to the emergency contact.
  /// Uses a custom native method channel to send the message invisibly.
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

      // Request SMS permission if not already granted
      if (await Permission.sms.request().isGranted) {
        
        final bool? result = await _channel.invokeMethod<bool>('sendSms', {
          'phone': emergencyPhone,
          'msg': message,
        });

        if (result == true) {
          debugPrint('SmsService: Direct SMS sent successfully to $emergencyPhone');
          return true;
        } else {
          debugPrint('SmsService: Direct SMS failed to send.');
          return false;
        }
      } else {
        debugPrint('SmsService: SMS permission denied by user.');
        return false;
      }
    } catch (e) {
      debugPrint('SmsService: Fatal error sending SMS — $e');
      return false;
    }
  }
}


