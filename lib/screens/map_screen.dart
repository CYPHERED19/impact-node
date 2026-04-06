import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../services/map_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'dart:math' as math;

class MapScreen extends StatefulWidget {
  final bool emergencyMode;

  const MapScreen({super.key, this.emergencyMode = false});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final MapService _mapService = MapService();
  final TextEditingController _searchController = TextEditingController();

  bool _isRouteMode = true;
  String _activePoiType = '';
  bool _isLoading = false;
  bool _emergencyMode = false;
  bool _autoFollow = true; // auto-follow user position like Google Maps

  List<LatLng> _routePoints = [];
  List<Map<String, dynamic>> _nearbyPlaces = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchResults = false;
  Timer? _searchDebounce;

  // Route info
  String _routeDestName = '';
  double _routeDistKm = 0;
  int _routeTimeMin = 0;

  final LatLng _defaultLocation = const LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    _emergencyMode = widget.emergencyMode;

    if (_emergencyMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchAllEmergencyServices();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Auto-follow: move map to user location when it changes ──────────────
  void _onLocationUpdate(LatLng location) {
    if (_autoFollow && !_isLoading) {
      try {
        _mapController.move(location, _mapController.camera.zoom);
      } catch (_) {}
    }
  }

  // ── Search destination using Nominatim ──────────────────────────────────
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await _mapService.searchPlaces(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _showSearchResults = results.isNotEmpty;
        });
      }
    });
  }

  void _selectDestination(Map<String, dynamic> place) {
    final destLat = place['lat'] as double;
    final destLon = place['lon'] as double;
    final destName = place['name'] as String;

    setState(() {
      _showSearchResults = false;
      _searchController.text = destName.split(',').first;
    });

    // Route from current location to selected destination
    final locationService = context.read<LocationService>();
    final currentLoc = locationService.currentPosition != null
        ? LatLng(locationService.currentPosition!.latitude,
            locationService.currentPosition!.longitude)
        : null;

    if (currentLoc != null) {
      _routeTo(currentLoc, LatLng(destLat, destLon), destName);
    }
  }

  Future<void> _routeTo(LatLng origin, LatLng dest, String destName) async {
    setState(() {
      _isLoading = true;
      _autoFollow = false;
      _isRouteMode = true;
    });

    final route = await _mapService.getRoute(origin, dest);

    setState(() {
      _isLoading = false;
      if (route.isNotEmpty) {
        _routePoints = route;
        _routeDestName = destName.split(',').first;

        // Calculate distance
        final distance = const Distance();
        double totalDist = 0;
        for (int i = 0; i < route.length - 1; i++) {
          totalDist += distance.as(LengthUnit.Meter, route[i], route[i + 1]);
        }
        _routeDistKm = totalDist / 1000.0;
        // Rough ETA: assume 30 km/h average for two-wheeler in city
        _routeTimeMin = (_routeDistKm / 30 * 60).round();
        if (_routeTimeMin < 1) _routeTimeMin = 1;

        final bounds = LatLngBounds.fromPoints(route);
        _mapController.fitCamera(
          CameraFit.bounds(
              bounds: bounds, padding: const EdgeInsets.all(60)),
        );
      }
    });
  }

  void _clearRoute() {
    setState(() {
      _routePoints = [];
      _routeDestName = '';
      _routeDistKm = 0;
      _routeTimeMin = 0;
      _searchController.clear();
      _autoFollow = true;
    });
  }

  // ── Emergency services fetch ────────────────────────────────────────────
  Future<void> _fetchAllEmergencyServices() async {
    final locationService = context.read<LocationService>();
    final location = locationService.currentPosition != null
        ? LatLng(locationService.currentPosition!.latitude,
            locationService.currentPosition!.longitude)
        : _defaultLocation;

    setState(() {
      _isLoading = true;
      _isRouteMode = false;
      _activePoiType = 'emergency_all';
      _nearbyPlaces = [];
    });

    final results = await Future.wait([
      _mapService.getNearbyPlaces(location, 'hospital'),
      _mapService.getNearbyPlaces(location, 'police'),
    ]);

    final hospitals =
        results[0].map((e) => {...e, 'type': 'hospital'}).toList();
    final police = results[1].map((e) => {...e, 'type': 'police'}).toList();
    final allPlaces = [...hospitals, ...police];

    setState(() {
      _nearbyPlaces = allPlaces;
      _isLoading = false;
      _activePoiType = 'emergency_all';
      _isRouteMode = false;
    });

    if (allPlaces.isNotEmpty) {
      _mapController.move(location, 13.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<LocationService>(
        builder: (context, locationService, child) {
          final currentLocation = locationService.currentPosition != null
              ? LatLng(locationService.currentPosition!.latitude,
                  locationService.currentPosition!.longitude)
              : null;

          // Auto-follow
          if (currentLocation != null && _autoFollow && _routePoints.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _onLocationUpdate(currentLocation);
            });
          }

          final heading = locationService.heading;

          return Stack(
            children: [
              // ── Map Layer ────────────────────────────────────────────
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: currentLocation ?? _defaultLocation,
                  initialZoom: 15.0,
                  backgroundColor: AppColors.background,
                  onPositionChanged: (pos, hasGesture) {
                    // If user drags manually, disable auto-follow
                    if (hasGesture) {
                      _autoFollow = false;
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.impactnode.app',
                  ),

                  // Dashed connector lines to POIs
                  if (!_isRouteMode && currentLocation != null)
                    PolylineLayer(
                      polylines: _nearbyPlaces
                          .map<Polyline>((place) => Polyline(
                                points: [
                                  currentLocation,
                                  LatLng(place['lat'], place['lon'])
                                ],
                                color:
                                    _getPoiColor(place['type'] ?? _activePoiType)
                                        .withOpacity(0.5),
                                strokeWidth: 2.0,
                                pattern: StrokePattern.dashed(
                                    segments: const [6, 6]),
                              ))
                          .toList(),
                    ),

                  // Route line
                  if (_isRouteMode && _routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          color: Colors.blueAccent,
                          strokeWidth: 5.0,
                        ),
                      ],
                    ),

                  // Markers
                  MarkerLayer(
                    markers: [
                      // ── User position cursor (Google Maps style) ──────
                      if (currentLocation != null)
                        Marker(
                          point: currentLocation,
                          width: 48,
                          height: 48,
                          child: Transform.rotate(
                            angle: heading * (math.pi / 180),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer glow
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.blueAccent
                                        .withOpacity(0.15),
                                  ),
                                ),
                                // Direction arrow
                                Positioned(
                                  top: 2,
                                  child: Icon(
                                    Icons.navigation,
                                    color: Colors.blueAccent,
                                    size: 16,
                                  ),
                                ),
                                // Center dot
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blueAccent
                                            .withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Destination marker
                      if (_isRouteMode && _routePoints.isNotEmpty)
                        Marker(
                          point: _routePoints.last,
                          width: 36,
                          height: 36,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.activeRed,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.location_on,
                                color: Colors.white, size: 18),
                          ),
                        ),

                      // POI markers
                      if (!_isRouteMode)
                        ..._nearbyPlaces.map((place) {
                          final type = place['type'] ?? _activePoiType;
                          final color = _getPoiColor(type);
                          final icon = _getPoiIcon(type);
                          return Marker(
                            point: LatLng(place['lat'], place['lon']),
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: color, width: 1.5),
                              ),
                              child: Icon(icon, color: color, size: 20),
                            ),
                          );
                        }),
                    ],
                  ),
                ],
              ),

              // ── Emergency Banner ─────────────────────────────────────
              if (_emergencyMode)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      color: AppColors.activeRed.withOpacity(0.9),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'CRASH DETECTED — Nearest hospitals & police loaded',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Top bar (non-emergency) ──────────────────────────────
              if (!_emergencyMode)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('M A P',
                            style:
                                AppTheme.labelStyle.copyWith(fontSize: 14)),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.cardBorder),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.circle,
                                      color: AppColors.safeGreenLight,
                                      size: 8),
                                  SizedBox(width: 8),
                                  Text('Live',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => setState(() {
                                _isRouteMode = !_isRouteMode;
                                _routePoints.clear();
                                _nearbyPlaces.clear();
                                _activePoiType = '';
                                _searchController.clear();
                                _showSearchResults = false;
                                _routeDestName = '';
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _isRouteMode
                                      ? AppColors.cardBg
                                      : AppColors.sosBtnBg.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _isRouteMode
                                          ? AppColors.cardBorder
                                          : AppColors.activeRed),
                                ),
                                child: Text(
                                  _isRouteMode ? 'Route' : 'Nearby',
                                  style: TextStyle(
                                    color: _isRouteMode
                                        ? Colors.white
                                        : AppColors.activeRed,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Loading indicator ────────────────────────────────────
              if (_isLoading)
                const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.safeGreenLight)),

              // ── Map controls ─────────────────────────────────────────
              Positioned(
                right: 16,
                top: MediaQuery.of(context).size.height * 0.35,
                child: Column(
                  children: [
                    _buildMapControlButton(Icons.add, () {
                      _mapController.move(_mapController.camera.center,
                          _mapController.camera.zoom + 1);
                    }),
                    const SizedBox(height: 8),
                    _buildMapControlButton(Icons.remove, () {
                      _mapController.move(_mapController.camera.center,
                          _mapController.camera.zoom - 1);
                    }),
                    const SizedBox(height: 16),
                    // Re-center / auto-follow button
                    _buildMapControlButton(
                      _autoFollow
                          ? Icons.gps_fixed
                          : Icons.gps_not_fixed,
                      () {
                        if (currentLocation != null) {
                          setState(() => _autoFollow = true);
                          _mapController.move(currentLocation, 15.0);
                        }
                      },
                      color: _autoFollow
                          ? Colors.blueAccent
                          : AppColors.safeGreenLight,
                    ),
                  ],
                ),
              ),

              // ── Bottom panel ─────────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _isRouteMode
                    ? _buildRoutePanel(currentLocation)
                    : _buildNearbyPanel(currentLocation),
              ),

              // ── Search results overlay ────────────────────────────────
              if (_showSearchResults)
                Positioned(
                  bottom: 200,
                  left: 20,
                  right: 20,
                  child: Container(
                    constraints:
                        const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: AppColors.cardBorder),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return InkWell(
                          onTap: () =>
                              _selectDestination(result),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: index < _searchResults.length - 1
                                  ? const Border(
                                      bottom: BorderSide(
                                          color:
                                              AppColors.cardBorder))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                    Icons.location_on_outlined,
                                    color:
                                        AppColors.textSecondary,
                                    size: 18),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    result['name'],
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13),
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMapControlButton(IconData icon, VoidCallback onTap,
      {Color color = Colors.white}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildRoutePanel(LatLng? myLocation) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.95),
        border:
            const Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search bar — functional
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.search,
                    color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search destination...',
                      hintStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  InkWell(
                    onTap: () {
                      _searchController.clear();
                      _clearRoute();
                    },
                    child: const Icon(Icons.close,
                        color: AppColors.textSecondary, size: 18),
                  ),
              ],
            ),
          ),

          // Route info (when route is active)
          if (_routePoints.isNotEmpty) ...[
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(16),
              margin: EdgeInsets.zero,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.circle,
                              color: Colors.blueAccent, size: 10),
                          const SizedBox(width: 10),
                          const Text('Your location',
                              style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ]),
                        Container(
                            margin: const EdgeInsets.only(left: 4),
                            height: 16,
                            width: 2,
                            color: AppColors.cardBorder),
                        Row(children: [
                          const Icon(Icons.circle,
                              color: AppColors.activeRed, size: 10),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_routeDestName,
                                style: const TextStyle(
                                    color: AppColors.activeRed,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${_routeDistKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      Text('~$_routeTimeMin min',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _clearRoute,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: AppColors.textSecondary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Clear Route',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13)),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            _buildFilterCategoryRow(myLocation),
          ],
        ],
      ),
    );
  }

  Widget _buildNearbyPanel(LatLng? myLocation) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.95),
        border:
            const Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Column(
        children: [
          _buildFilterCategoryRow(myLocation),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.safeGreenLight))
                : _nearbyPlaces.isEmpty
                    ? const Center(
                        child: Text(
                            'Select a category above to search.',
                            style: TextStyle(
                                color: AppColors.textSecondary)))
                    : ListView.builder(
                        itemCount: _nearbyPlaces.length,
                        itemBuilder: (context, index) {
                          final place = _nearbyPlaces[index];
                          final type =
                              place['type'] ?? _activePoiType;
                          final color = _getPoiColor(type);
                          final icon = _getPoiIcon(type);

                          return Container(
                            margin:
                                const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius:
                                  BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.cardBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        color.withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                        color: color
                                            .withOpacity(0.3)),
                                  ),
                                  child: Icon(icon,
                                      color: color, size: 20),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        place['name'],
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight:
                                                FontWeight.w600),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        place['openingHours'],
                                        style: const TextStyle(
                                            color: AppColors
                                                .textSecondary,
                                            fontSize: 12),
                                      ),
                                      if ((place['phone']
                                                  as String?)
                                              ?.isNotEmpty ==
                                          true) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          place['phone'],
                                          style: TextStyle(
                                              color: color,
                                              fontSize: 11),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    if (myLocation != null) {
                                      _routeTo(
                                        myLocation,
                                        LatLng(place['lat'],
                                            place['lon']),
                                        place['name'],
                                      );
                                      setState(() =>
                                          _isRouteMode = true);
                                    }
                                  },
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8),
                                    decoration: BoxDecoration(
                                      color:
                                          color.withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color: color
                                              .withOpacity(0.5)),
                                    ),
                                    child: Text('Route',
                                        style: TextStyle(
                                            color: color,
                                            fontSize: 14,
                                            fontWeight:
                                                FontWeight.w600)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCategoryRow(LatLng? myLocation) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCategoryChip('Police', 'police',
              Icons.local_police_outlined, AppColors.activeRed, myLocation),
          const SizedBox(width: 8),
          _buildCategoryChip('Hospital', 'hospital',
              Icons.local_hospital_outlined, Colors.blueAccent, myLocation),
          const SizedBox(width: 8),
          _buildCategoryChip('Towing', 'towing', Icons.car_repair,
              Colors.orange, myLocation),
          const SizedBox(width: 8),
          _buildCategoryChip('Puncture', 'puncture_shop',
              Icons.tire_repair, Colors.amber, myLocation),
          const SizedBox(width: 8),
          _buildCategoryChip('EV', 'charging_station',
              Icons.ev_station_outlined, AppColors.safeGreenLight, myLocation),
          const SizedBox(width: 8),
          _buildCategoryChip(
              'Fuel',
              'fuel',
              Icons.local_gas_station_outlined,
              AppColors.textSecondary,
              myLocation),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
    String label,
    String type,
    IconData icon,
    Color mainColor,
    LatLng? myLocation,
  ) {
    final isSelected = _activePoiType == type;
    return InkWell(
      onTap: () {
        if (myLocation != null) _fetchPoi(type, myLocation);
      },
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? mainColor.withOpacity(0.1)
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? mainColor : AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: mainColor, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected ? mainColor : AppColors.textSecondary,
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPoiColor(String type) {
    switch (type) {
      case 'police':
        return AppColors.activeRed;
      case 'hospital':
        return Colors.blueAccent;
      case 'towing':
        return Colors.orange;
      case 'puncture_shop':
        return Colors.amber;
      case 'charging_station':
        return AppColors.safeGreenLight;
      case 'emergency_all':
        return AppColors.activeRed;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getPoiIcon(String type) {
    switch (type) {
      case 'police':
        return Icons.local_police_outlined;
      case 'hospital':
        return Icons.local_hospital_outlined;
      case 'towing':
        return Icons.car_repair;
      case 'puncture_shop':
        return Icons.tire_repair;
      case 'charging_station':
        return Icons.ev_station_outlined;
      default:
        return Icons.location_on_outlined;
    }
  }

  Future<void> _fetchPoi(String type, LatLng location) async {
    setState(() {
      _isLoading = true;
      _activePoiType = type;
      _isRouteMode = false;
      _routePoints.clear();
    });

    final places = await _mapService.getNearbyPlaces(location, type);

    setState(() {
      _nearbyPlaces = places.map((e) => {...e, 'type': type}).toList();
      _isLoading = false;
    });

    if (places.isNotEmpty) {
      _mapController.move(location, 13.0);
    }
  }
}
