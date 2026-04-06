import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'offline_cache_service.dart';

class MapService {
  /// Fetches the shortest driving route using OSRM public API
  Future<List<LatLng>> getRoute(LatLng origin, LatLng destination) async {
    try {
      final String url =
          'http://router.project-osrm.org/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=geojson';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final List<dynamic> coordinates =
              data['routes'][0]['geometry']['coordinates'];
          return coordinates
              .map((coord) => LatLng(
                    (coord[1] as num).toDouble(),
                    (coord[0] as num).toDouble(),
                  ))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('MapService: Failed to get OSRM route — $e');
    }
    return [];
  }

  /// Overpass amenity tags mapped per POI type
  static String _overpassQuery(String amenity, double lat, double lon) {
    // Towing and puncture shops need shop/service tags, not amenity
    String tagFilter;
    switch (amenity) {
      case 'towing':
        tagFilter = '"service"="vehicle_towing"';
        break;
      case 'puncture_shop':
        tagFilter = '"shop"="tyres"';
        break;
      default:
        tagFilter = '"amenity"="$amenity"';
    }

    return '''
[out:json][timeout:25];
(
  node[$tagFilter](around:5000,$lat,$lon);
  way[$tagFilter](around:5000,$lat,$lon);
  relation[$tagFilter](around:5000,$lat,$lon);
);
out center;
''';
  }

  /// Finds nearby places using OSM Overpass API with offline fallback.
  ///
  /// Supported amenity values:
  ///   'hospital', 'police', 'charging_station', 'fuel',
  ///   'towing', 'puncture_shop'   ← NEW for ROADSoS
  Future<List<Map<String, dynamic>>> getNearbyPlaces(
    LatLng location,
    String amenity,
  ) async {
    // ── 1. Try offline cache first ──────────────────────────────────────────
    final cached = await OfflineCacheService.getCachedPois(
      location.latitude,
      location.longitude,
      amenity,
    );
    if (cached != null && cached.isNotEmpty) {
      debugPrint('MapService: Returning ${cached.length} cached POIs for $amenity');
      return cached;
    }

    // ── 2. Try live Overpass API ────────────────────────────────────────────
    try {
      final query = _overpassQuery(amenity, location.latitude, location.longitude);
      final response = await http
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            body: query,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<Map<String, dynamic>> places = [];

        for (var element in data['elements']) {
          final lat = (element['lat'] ?? element['center']?['lat']) as double?;
          final lon = (element['lon'] ?? element['center']?['lon']) as double?;
          if (lat == null || lon == null) continue;

          final tags = element['tags'] as Map<String, dynamic>? ?? {};
          final name = (tags['name'] as String?)?.trim();
          if (name == null || name.isEmpty) continue; // skip unnamed places

          final openingHours =
              (tags['opening_hours'] as String?) ?? 'Hours unavailable';
          final phone = (tags['phone'] as String?) ??
              (tags['contact:phone'] as String?) ??
              '';
          final emergency = tags['emergency'] == 'yes';

          places.add({
            'id': element['id'].toString(),
            'name': name,
            'lat': lat,
            'lon': lon,
            'openingHours': openingHours,
            'phone': phone,
            'isEmergency': emergency,
            'type': amenity,
          });
        }

        // Cache result for offline use
        if (places.isNotEmpty) {
          await OfflineCacheService.cachePois(
            location.latitude,
            location.longitude,
            amenity,
            places,
          );
        }

        debugPrint('MapService: Fetched ${places.length} live POIs for $amenity');
        return places;
      }
    } catch (e) {
      debugPrint('MapService: Overpass failed — $e');
    }

    // ── 3. Stale cache fallback (ignore age) ────────────────────────────────
    debugPrint('MapService: Network failed, trying stale cache for $amenity');
    final stale = await OfflineCacheService.getCachedPois(
      location.latitude,
      location.longitude,
      amenity,
    );
    return stale ?? [];
  }

  /// Fetches hospitals (with emergency=yes) and ambulance stations near [lat],[lon].
  /// Returns a list with name, phone, type ('hospital' | 'ambulance').
  Future<List<Map<String, dynamic>>> getEmergencyServices(
      double lat, double lon) async {
    try {
      final query = '''
[out:json][timeout:25];
(
  node["amenity"="hospital"](around:10000,$lat,$lon);
  way["amenity"="hospital"](around:10000,$lat,$lon);
  node["emergency"="ambulance_station"](around:10000,$lat,$lon);
  way["emergency"="ambulance_station"](around:10000,$lat,$lon);
  node["amenity"="clinic"]["emergency"="yes"](around:10000,$lat,$lon);
  way["amenity"="clinic"]["emergency"="yes"](around:10000,$lat,$lon);
);
out center;
''';

      final response = await http
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            body: query,
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<Map<String, dynamic>> places = [];

        for (var element in data['elements']) {
          final elLat =
              (element['lat'] ?? element['center']?['lat']) as double?;
          final elLon =
              (element['lon'] ?? element['center']?['lon']) as double?;
          if (elLat == null || elLon == null) continue;

          final tags = element['tags'] as Map<String, dynamic>? ?? {};
          final name = (tags['name'] as String?)?.trim();
          if (name == null || name.isEmpty) continue;

          final phone = (tags['phone'] as String?) ??
              (tags['contact:phone'] as String?) ??
              (tags['emergency_telephone'] as String?) ??
              '';

          final isAmbulance = tags['emergency'] == 'ambulance_station';

          places.add({
            'name': name,
            'phone': phone,
            'type': isAmbulance ? 'ambulance' : 'hospital',
            'lat': elLat,
            'lon': elLon,
          });
        }

        debugPrint(
            'MapService: Found ${places.length} emergency services');
        return places;
      }
    } catch (e) {
      debugPrint('MapService: getEmergencyServices failed — $e');
    }
    return [];
  }

  /// Search for places by name using Nominatim (OSM geocoding).
  /// Returns a list of results with name, lat, lon.
  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json&limit=5&addressdetails=1',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'ImpactNodeApp/1.0',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map<Map<String, dynamic>>((item) {
          return {
            'name': item['display_name'] as String,
            'lat': double.parse(item['lat'] as String),
            'lon': double.parse(item['lon'] as String),
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('MapService: searchPlaces failed — $e');
    }
    return [];
  }
}
