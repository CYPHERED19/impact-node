import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Caches nearby POI results locally in SQLite so the app works in
/// low-network or offline conditions (ROADSoS requirement).
class OfflineCacheService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'impact_node_cache.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Cache table for nearby POIs
        await db.execute('''
          CREATE TABLE poi_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amenity TEXT NOT NULL,
            lat_bucket TEXT NOT NULL,
            lon_bucket TEXT NOT NULL,
            places_json TEXT NOT NULL,
            cached_at INTEGER NOT NULL
          )
        ''');

        // Index for fast lookup
        await db.execute(
          'CREATE INDEX idx_poi_lookup ON poi_cache (amenity, lat_bucket, lon_bucket)',
        );

        // Crash events for heatmap (offline fallback)
        await db.execute('''
          CREATE TABLE crash_events_cache (
            id TEXT PRIMARY KEY,
            rider_id TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            speed_kmph REAL NOT NULL,
            sos_sent INTEGER NOT NULL,
            sos_cancelled INTEGER NOT NULL,
            g_force_peak REAL NOT NULL,
            tilt_angle REAL NOT NULL,
            gyroscope_peak REAL NOT NULL,
            speed_before REAL NOT NULL,
            speed_after REAL NOT NULL,
            impact_duration_ms INTEGER NOT NULL,
            false_positive INTEGER NOT NULL,
            is_near_miss INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // ─── POI Cache ────────────────────────────────────────────────────────────

  /// Bucket coordinates to ~1km grid for cache key
  static String _bucket(double coord) => coord.toStringAsFixed(2);

  /// Returns cached POI list if it exists and is < 24 hours old
  static Future<List<Map<String, dynamic>>?> getCachedPois(
    double lat,
    double lon,
    String amenity,
  ) async {
    try {
      final db = await database;
      final cutoff = DateTime.now()
          .subtract(const Duration(hours: 24))
          .millisecondsSinceEpoch;

      final rows = await db.query(
        'poi_cache',
        where:
            'amenity = ? AND lat_bucket = ? AND lon_bucket = ? AND cached_at > ?',
        whereArgs: [amenity, _bucket(lat), _bucket(lon), cutoff],
        orderBy: 'cached_at DESC',
        limit: 1,
      );

      if (rows.isEmpty) return null;

      final List<dynamic> decoded = jsonDecode(rows.first['places_json'] as String);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('OfflineCacheService: getCachedPois error — $e');
      return null;
    }
  }

  /// Stores a fresh POI result into the local cache
  static Future<void> cachePois(
    double lat,
    double lon,
    String amenity,
    List<Map<String, dynamic>> places,
  ) async {
    try {
      final db = await database;
      await db.insert(
        'poi_cache',
        {
          'amenity': amenity,
          'lat_bucket': _bucket(lat),
          'lon_bucket': _bucket(lon),
          'places_json': jsonEncode(places),
          'cached_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('OfflineCacheService: Cached ${places.length} POIs for $amenity');
    } catch (e) {
      debugPrint('OfflineCacheService: cachePois error — $e');
    }
  }

  // ─── Crash Events Cache ───────────────────────────────────────────────────

  /// Upserts a crash event into local DB so heatmap works offline
  static Future<void> upsertCrashEvent(Map<String, dynamic> event) async {
    try {
      final db = await database;
      await db.insert(
        'crash_events_cache',
        {
          'id': event['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'rider_id': event['rider_id'],
          'timestamp': event['timestamp'],
          'latitude': event['latitude'],
          'longitude': event['longitude'],
          'speed_kmph': event['speed_kmph'],
          'sos_sent': event['sos_sent'] == true ? 1 : 0,
          'sos_cancelled': event['sos_cancelled'] == true ? 1 : 0,
          'g_force_peak': event['g_force_peak'] ?? 0.0,
          'tilt_angle': event['tilt_angle'] ?? 0.0,
          'gyroscope_peak': event['gyroscope_peak'] ?? 0.0,
          'speed_before': event['speed_before'] ?? 0.0,
          'speed_after': event['speed_after'] ?? 0.0,
          'impact_duration_ms': event['impact_duration_ms'] ?? 0,
          'false_positive': event['false_positive'] == true ? 1 : 0,
          'is_near_miss': event['is_near_miss'] == true ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('OfflineCacheService: upsertCrashEvent error — $e');
    }
  }

  /// Fetch all locally cached crash events (for heatmap offline fallback)
  static Future<List<Map<String, dynamic>>> getCachedCrashEvents(
    String riderId,
  ) async {
    try {
      final db = await database;
      return await db.query(
        'crash_events_cache',
        where: 'rider_id = ? AND false_positive = 0',
        whereArgs: [riderId],
        orderBy: 'timestamp DESC',
      );
    } catch (e) {
      debugPrint('OfflineCacheService: getCachedCrashEvents error — $e');
      return [];
    }
  }
}
