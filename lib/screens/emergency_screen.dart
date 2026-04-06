import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../services/map_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final MapService _mapService = MapService();

  List<Map<String, dynamic>> _services = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchEmergencyServices();
    });
  }

  Future<void> _fetchEmergencyServices() async {
    final locationService = context.read<LocationService>();
    final position = locationService.currentPosition;

    if (position == null) {
      setState(() {
        _errorMsg = 'Location unavailable — enable GPS and try again';
        _isLoading = false;
        _hasLoaded = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final lat = position.latitude;
      final lon = position.longitude;

      // Fetch hospitals with emergency services + ambulance stations
      final results = await Future.wait([
        _mapService.getEmergencyServices(lat, lon),
      ]);

      final allServices = <Map<String, dynamic>>[];
      for (final list in results) {
        allServices.addAll(list);
      }

      // Sort: services with phone numbers first, then by name
      allServices.sort((a, b) {
        final aHasPhone =
            (a['phone'] as String?)?.isNotEmpty == true ? 0 : 1;
        final bHasPhone =
            (b['phone'] as String?)?.isNotEmpty == true ? 0 : 1;
        if (aHasPhone != bHasPhone) return aHasPhone.compareTo(bHasPhone);
        return (a['name'] as String).compareTo(b['name'] as String);
      });

      setState(() {
        _services = allServices;
        _isLoading = false;
        _hasLoaded = true;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Failed to fetch services — check your connection';
        _isLoading = false;
        _hasLoaded = true;
      });
    }
  }

  Future<void> _callNumber(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('E M E R G E N C Y',
                      style: AppTheme.labelStyle.copyWith(fontSize: 14)),
                  Row(
                    children: [
                      if (_hasLoaded)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color:
                                AppColors.activeRed.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.activeRed),
                          ),
                          child: Text(
                            '${_services.length} found',
                            style: const TextStyle(
                                color: AppColors.activeRed,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      InkWell(
                        onTap: _isLoading ? null : _fetchEmergencyServices,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.cardBorder, width: 0.5),
                          ),
                          child: Icon(
                            Icons.refresh,
                            color: _isLoading
                                ? AppColors.label
                                : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── National emergency numbers ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                margin: EdgeInsets.zero,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:
                            AppColors.activeRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.emergency,
                          color: AppColors.activeRed, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('National Emergency',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          Text('Dial 112 for all emergencies',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    _CallButton(phone: '112', onTap: () => _callNumber('112')),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Service list ──────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: AppColors.safeGreenLight),
                          SizedBox(height: 16),
                          Text('Finding nearby emergency services...',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    )
                  : _errorMsg != null
                      ? Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_off,
                                    color: AppColors.warningAmber, size: 48),
                                const SizedBox(height: 12),
                                Text(_errorMsg!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14)),
                                const SizedBox(height: 16),
                                OutlinedButton(
                                  onPressed: _fetchEmergencyServices,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: AppColors.safeGreenLight),
                                  ),
                                  child: const Text('Retry',
                                      style: TextStyle(
                                          color: AppColors.safeGreenLight)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _services.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_hospital_outlined,
                                      color: AppColors.label
                                          .withValues(alpha: 0.5),
                                      size: 48),
                                  const SizedBox(height: 12),
                                  const Text(
                                      'No emergency services found nearby',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20),
                              itemCount: _services.length,
                              itemBuilder: (context, index) {
                                final svc = _services[index];
                                return _EmergencyServiceTile(
                                  service: svc,
                                  onCall: _callNumber,
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyServiceTile extends StatelessWidget {
  final Map<String, dynamic> service;
  final Function(String) onCall;

  const _EmergencyServiceTile({
    required this.service,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final name = service['name'] as String;
    final phone = service['phone'] as String? ?? '';
    final type = service['type'] as String? ?? 'hospital';
    final hasPhone = phone.isNotEmpty;

    final isAmbulance = type == 'ambulance';
    final color = isAmbulance ? AppColors.activeRed : Colors.blueAccent;
    final icon = isAmbulance
        ? Icons.local_shipping_outlined
        : Icons.local_hospital_outlined;
    final typeLabel = isAmbulance ? 'AMBULANCE' : 'HOSPITAL';

    return GlassCard(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(typeLabel,
                          style: TextStyle(
                              color: color,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  hasPhone ? phone : 'No phone available',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasPhone
                        ? AppColors.safeGreenLight
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (hasPhone)
            _CallButton(phone: phone, onTap: () => onCall(phone)),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final String phone;
  final VoidCallback onTap;

  const _CallButton({required this.phone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.safeGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.safeGreenLight.withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.call,
            color: AppColors.safeGreenLight, size: 20),
      ),
    );
  }
}
