import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/crash_event.dart';

class SupabaseService {
  // ============================================================
  // TODO: Replace these with your real Supabase credentials
  // Go to: Supabase Dashboard → Settings → API
  // ============================================================
  static const String _supabaseUrl = 'https://iivdpojkshctndiabbjz.supabase.co';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlpdmRwb2prc2hjdG5kaWFiYmp6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2NTgzNTgsImV4cCI6MjA5MDIzNDM1OH0.FbChJ6q-Mbq3bUerfZsyJXOjovr-7ZaG9JhunhG2n1g';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
    debugPrint('SupabaseService: Initialized');
  }

  /// Insert a crash event into the crash_events table
  static Future<void> insertCrashEvent(CrashEvent event) async {
    try {
      await client.from('crash_events').insert(event.toJson());
      debugPrint('SupabaseService: Crash event inserted');
    } catch (e) {
      debugPrint('SupabaseService: Error inserting crash event — $e');
      // Fail silently — crash event will be logged locally as well
    }
  }

  /// Fetch crash events for a specific rider
  static Future<List<CrashEvent>> getCrashEvents(String riderId) async {
    try {
      final response = await client
          .from('crash_events')
          .select('id, rider_id, timestamp, latitude, longitude, '
              'speed_kmph, sos_sent, sos_cancelled')
          .eq('rider_id', riderId)
          .order('timestamp', ascending: false);

      return (response as List)
          .map((json) => CrashEvent.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('SupabaseService: Error fetching crash events — $e');
      return [];
    }
  }
}
