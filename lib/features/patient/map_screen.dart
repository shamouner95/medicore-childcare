import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hospital_app/core/services/triage_service.dart';
import 'package:hospital_app/core/services/gemini_ai_service.dart';
import 'package:hospital_app/core/widgets/ai_processing_overlay.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import 'dart:async';

import '../../providers/country_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  final String? initialSymptoms;
  const MapScreen({super.key, this.initialSymptoms});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late GoogleMapController mapController;
  final GeminiAIService _aiService = GeminiAIService();
  late final TriageService _triageService;
  
  MapTriageResponse? _triageRecommendation;
  EpidemicInsight? _epidemicInsight;
  bool _isDoctorMode = false;

  final LatLng _center = const LatLng(37.7749, -122.4194);

  List<Map<String, dynamic>> _facilities = [];
  bool _isLoadingHospitals = true;

  List<Map<String, dynamic>> _intelligenceReports = [];
  final Set<Marker> _intelligenceMarkers = {};
  bool _showIntelligenceMarkers = true;
  bool _showIntelFeed = false;

  @override
  void initState() {
    super.initState();
    _triageService = TriageService(_aiService);
    _fetchHospitals();
    _fetchIntelligenceMarkers();
  }

  Future<void> _fetchIntelligenceMarkers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('environmental_indicators')
          .orderBy('timestamp', descending: true)
          .get();
      
      if (mounted) {
        setState(() {
          _intelligenceReports = snapshot.docs.map((doc) => {
            'id': doc.id,
            ...doc.data(),
          }).toList();

          _intelligenceMarkers.clear();
          for (var report in _intelligenceReports) {
            final typeId = report['type'] as String;
            
            _intelligenceMarkers.add(
              Marker(
                markerId: MarkerId('intel_${report['id']}'),
                position: LatLng(report['latitude'], report['longitude']),
                icon: BitmapDescriptor.defaultMarkerWithHue(_getIntelligenceHue(typeId)),
                infoWindow: InfoWindow(
                  title: 'Field Report: ${typeId.toUpperCase()}',
                  snippet: report['description'],
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching intelligence: $e');
    }
  }

  double _getIntelligenceHue(String typeId) {
    switch (typeId) {
      case 'heat': return BitmapDescriptor.hueOrange;
      case 'outbreak': return BitmapDescriptor.hueRed;
      case 'disaster': return BitmapDescriptor.hueAzure;
      case 'other': return BitmapDescriptor.hueGreen;
      default: return BitmapDescriptor.hueRed;
    }
  }

  Future<void> _fetchHospitals() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'hospital')
          .get();
      
      setState(() {
        _facilities = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Hospital',
            'lat': data['latitude'] ?? 37.7749, // Default to SF if missing
            'lng': data['longitude'] ?? -122.4194,
            'type': data['speciality'] ?? 'General',
            'waitTime': '15 mins', // Mock wait time for now
            'address': data['address'] ?? '',
            'specialties': [data['speciality'] ?? 'General'],
          };
        }).toList();
        _isLoadingHospitals = false;
      });

      if (widget.initialSymptoms != null) {
        _runSmartTriage();
      }
    } catch (e) {
      setState(() => _isLoadingHospitals = false);
    }
  }

  Future<void> _runSmartTriage() async {
    final selectedCountry = ref.read(countryProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AIProcessingOverlay(message: 'AI is analyzing nearby facilities...'),
    );

    try {
      // Fetch field intelligence to inform triage
      final indicatorSnapshot = await FirebaseFirestore.instance
          .collection('environmental_indicators')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final indicators = indicatorSnapshot.docs.map((doc) => {
        'id': doc.id,
        'type': doc['type'],
        'description': doc['description'],
        'latitude': doc['latitude'],
        'longitude': doc['longitude'],
      }).toList();

      final recommendation = await _triageService.performSmartTriage(
        symptoms: widget.initialSymptoms!,
        facilities: _facilities,
        indicators: indicators,
        country: selectedCountry,
      );

      if (mounted) {
        Navigator.pop(context);
        setState(() => _triageRecommendation = recommendation);
        _focusOnFacility(recommendation.recommendedFacilityId);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      // Fallback is handled inside TriageService, but we should still handle UI errors
    }
  }

  Future<void> _fetchEpidemicInsights() async {
    final selectedCountry = ref.read(countryProvider);
    setState(() {
      _isDoctorMode = true;
      _epidemicInsight = null;
    });

    try {
      // Fetch actual data from health workers
      final indicatorSnapshot = await FirebaseFirestore.instance
          .collection('environmental_indicators')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final indicators = indicatorSnapshot.docs.map((doc) => {
        'type': doc['type'],
        'description': doc['description'],
      }).toList();

      final insight = await _aiService.getEpidemicOutreach(indicators, country: selectedCountry);
      if (mounted) {
        setState(() => _epidemicInsight = insight);
      }
    } catch (e) {
      // Handle error
    }
  }

  void _focusOnFacility(String id) {
    final facility = _facilities.firstWhere((f) => f['id'] == id);
    mapController.animateCamera(CameraUpdate.newLatLngZoom(
      LatLng(facility['lat'], facility['lng']), 15.0
    ));
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_facilities.isNotEmpty && widget.initialSymptoms == null) {
       mapController.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(_facilities.first['lat'], _facilities.first['lng']), 12.0
      ));
    }
  }

  Set<Marker> get _markers {
    final markers = _facilities.map((f) {
      final isRecommended = _triageRecommendation?.recommendedFacilityId == f['id'];
      final focus = _getHospitalFocus(f);
      
      return Marker(
        markerId: MarkerId(f['id']),
        position: LatLng(f['lat'], f['lng']),
        icon: isRecommended 
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange) // Closer to Terracotta
          : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), // Closer to Sage
        infoWindow: InfoWindow(
          title: f['name'], 
          snippet: '${f['type']} - $focus',
          onTap: () => context.push('/hospital/${f['id']}'),
        ),
      );
    }).toSet();

    if (_showIntelligenceMarkers) {
      markers.addAll(_intelligenceMarkers);
    }

    return markers;
  }

  Set<Circle> get _circles {
    if (!_showIntelligenceMarkers) return {};
    return _intelligenceReports.map((report) {
      final typeId = report['type'] as String;
      return Circle(
        circleId: CircleId('circle_${report['id']}'),
        center: LatLng(report['latitude'], report['longitude']),
        radius: 800, // 800m impact radius
        fillColor: _getCircleColor(typeId).withOpacity(0.1),
        strokeColor: _getCircleColor(typeId).withOpacity(0.3),
        strokeWidth: 2,
      );
    }).toSet();
  }

  Color _getCircleColor(String typeId) {
    switch (typeId) {
      case 'heat': return Colors.orange;
      case 'outbreak': return Colors.red;
      case 'disaster': return Colors.blue;
      case 'other': return Colors.green;
      default: return Colors.red;
    }
  }

  String _getHospitalFocus(Map<String, dynamic> hospital) {
    if (_intelligenceReports.isEmpty) return 'General Care';
    
    final hLat = hospital['lat'];
    final hLng = hospital['lng'];
    
    for (var report in _intelligenceReports) {
      final rLat = report['latitude'];
      final rLng = report['longitude'];
      final dist = (hLat - rLat) * (hLat - rLat) + (hLng - rLng) * (hLng - rLng);
      if (dist < 0.005) { // Roughly within 1.5km
        return 'Surge Focus: ${report['type'].toUpperCase()}';
      }
    }
    return 'General Care';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedCountry = ref.watch(countryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          if (_isLoadingHospitals)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(target: _facilities.isNotEmpty 
                ? LatLng(_facilities.first['lat'], _facilities.first['lng']) 
                : _center, zoom: 13.0),
              markers: _markers,
              circles: _circles,
              myLocationEnabled: true,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              style: isDark ? _darkMapStyle : _lightMapStyle,
            ),
          
          // Header Actions
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: GlassCard(
                        borderRadius: 50,
                        padding: const EdgeInsets.all(12),
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDeep, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        borderRadius: 16,
                        child: Text(
                          _isDoctorMode ? 'Epidemic Heatmap' : 'Smart Triage Map',
                          style: GoogleFonts.playfairDisplay(
                            fontWeight: FontWeight.bold, 
                            color: AppColors.textDeep,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(() => _showIntelligenceMarkers = !_showIntelligenceMarkers),
                      child: GlassCard(
                        borderRadius: 50,
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          _showIntelligenceMarkers ? Icons.visibility_rounded : Icons.visibility_off_rounded, 
                          color: _showIntelligenceMarkers ? AppColors.primary : AppColors.secondary, 
                          size: 20
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(() => _showIntelFeed = !_showIntelFeed),
                      child: GlassCard(
                        borderRadius: 50,
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.rss_feed_rounded, 
                          color: _showIntelFeed ? AppColors.primary : AppColors.secondary, 
                          size: 20
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _isDoctorMode ? () => setState(() => _isDoctorMode = false) : _fetchEpidemicInsights,
                      child: GlassCard(
                        borderRadius: 50,
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          _isDoctorMode ? Icons.person_rounded : Icons.medical_services_rounded, 
                          color: AppColors.primary, 
                          size: 20
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCountrySelector(isDark),
              ],
            ),
          ),

          if (_triageRecommendation != null && !_isDoctorMode)
            _buildTriageOverlay(isDark, selectedCountry),

          if (_isDoctorMode)
            _buildEpidemicOverlay(isDark, selectedCountry),

          if (_showIntelFeed)
            _buildFieldIntelligenceFeed(isDark),

          if (_triageRecommendation == null && !_isDoctorMode && !_showIntelFeed)
            _buildDefaultBottomCard(isDark),
        ],
      ),
    );
  }

  Widget _buildFieldIntelligenceFeed(bool isDark) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.45,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  const Icon(Icons.hub_outlined, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text('LIVE FIELD INTELLIGENCE', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  IconButton(onPressed: () => setState(() => _showIntelFeed = false), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _intelligenceReports.length,
                itemBuilder: (context, index) {
                  final report = _intelligenceReports[index];
                  final typeId = report['type'] as String;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getCircleColor(typeId).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getCircleColor(typeId).withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: _getCircleColor(typeId)),
                            const SizedBox(width: 8),
                            Text(typeId.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 10, color: _getCircleColor(typeId), letterSpacing: 1.2)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(report['description'], style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textDeep)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.medical_services_outlined, size: 14, color: AppColors.secondary),
                            const SizedBox(width: 6),
                            Text('Primary Facility: ${_getNearestHospitalName(report)}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.secondary)),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                mapController.animateCamera(CameraUpdate.newLatLngZoom(LatLng(report['latitude'], report['longitude']), 15));
                                setState(() => _showIntelFeed = false);
                              },
                              child: Text('LOCATE', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _getNearestHospital(Map<String, dynamic> report) {
    if (_facilities.isEmpty) return null;
    
    double minDistance = double.infinity;
    Map<String, dynamic>? nearest;
    
    for (var f in _facilities) {
      final dist = (f['lat'] - report['latitude']) * (f['lat'] - report['latitude']) + 
                   (f['lng'] - report['longitude']) * (f['lng'] - report['longitude']);
      if (dist < minDistance) {
        minDistance = dist;
        nearest = f;
      }
    }
    return nearest;
  }

  String _getNearestHospitalName(Map<String, dynamic> report) {
    return _getNearestHospital(report)?['name'] ?? 'Locating...';
  }

  Widget _buildCountrySelector(bool isDark) {
    final selectedCountry = ref.watch(countryProvider);
    final countries = ref.watch(availableCountriesProvider);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      borderRadius: 100,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public_rounded, size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedCountry,
              dropdownColor: AppColors.background,
              items: countries.map((String country) {
                return DropdownMenuItem<String>(
                  value: country,
                  child: Text(country, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDeep)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(countryProvider.notifier).setCountry(value);
                  if (widget.initialSymptoms != null && !_isDoctorMode) {
                    _runSmartTriage();
                  } else if (_isDoctorMode) {
                    _fetchEpidemicInsights();
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriageOverlay(bool isDark, String selectedCountry) {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: GlassCard(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                        Row(
                          children: [
                            Icon(
                              _triageRecommendation!.urgencyContext.contains('Offline') 
                                ? Icons.wifi_off_rounded 
                                : Icons.auto_awesome_rounded, 
                              color: AppColors.primary, 
                              size: 24
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _triageRecommendation!.urgencyContext.contains('Offline') 
                                    ? 'OFFLINE TRIAGE ACTIVE' 
                                    : 'AI MATCHED FACILITY', 
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 10, letterSpacing: 1.2)),
                                Text('Optimized for $selectedCountry',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textDeep.withValues(alpha: 0.6), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                const SizedBox(height: 12),
                Text(_triageRecommendation!.reasoning, 
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textDeep, height: 1.4)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.shelf.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: _triageRecommendation!.travelAdvice.map((advice) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [const Icon(Icons.info_outline, size: 14, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Text(advice, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textDeep)))]),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => context.push('/hospital/${_triageRecommendation!.recommendedFacilityId}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary, 
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                          ),
                          child: Text('VIEW HOSPITAL', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _runSmartTriage,
                      child: Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          color: AppColors.shelf.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEpidemicOverlay(bool isDark, String selectedCountry) {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: GlassCard(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PRACTICE INTELLIGENCE', 
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 10, letterSpacing: 1.2)),
                        Text('Regional Analysis: $selectedCountry',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textDeep.withValues(alpha: 0.6), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Icon(Icons.analytics_rounded, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 12),
                if (_epidemicInsight == null)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ))
                else ...[
                  Text(_epidemicInsight!.status, style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDeep)),
                  const SizedBox(height: 8),
                  Text('Projected Hot Zones: ${_epidemicInsight!.hotZones.join(", ")}', style: GoogleFonts.plusJakartaSans(color: AppColors.textDeep.withValues(alpha: 0.7), fontSize: 13)),
                  const SizedBox(height: 16),
                  const Text('DOCTOR ACTION PLAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  ..._epidemicInsight!.doctorRecommendations.map((tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [const Icon(Icons.check_circle_outline, size: 14, color: AppColors.accent), const SizedBox(width: 8), Expanded(child: Text(tip, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textDeep)))]),
                  )),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/broadcast-alert'),
                      icon: const Icon(Icons.broadcast_on_personal_rounded, size: 18),
                      label: Text('BROADCAST SAFETY ALERTS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultBottomCard(bool isDark) {
    if (_facilities.isEmpty) return const SizedBox.shrink();
    
    Map<String, dynamic> nearest = _facilities.first;
    String label = 'NEAREST FACILITY';
    String? subLabel;

    // Logic: If there is a triage recommendation, it overrides everything.
    if (_triageRecommendation != null) {
      final recommended = _facilities.firstWhere(
        (f) => f['id'] == _triageRecommendation!.recommendedFacilityId,
        orElse: () => _facilities.first,
      );
      nearest = recommended;
      label = 'AI RECOMMENDED FACILITY';
      subLabel = _triageRecommendation!.urgencyContext;
    } 
    // Logic: Prioritize Outbreak/Epidemic reports if they exist
    else if (_intelligenceReports.isNotEmpty) {
      final outbreakReport = _intelligenceReports.firstWhere(
        (r) => r['type'] == 'outbreak',
        orElse: () => _intelligenceReports.first,
      );
      
      final respondingHospital = _getNearestHospital(outbreakReport);
      if (respondingHospital != null) {
        nearest = respondingHospital;
        label = outbreakReport['type'] == 'outbreak' 
            ? 'PRIMARY EPIDEMIC RESPONSE' 
            : 'PRIMARY RESPONSE FACILITY';
        subLabel = 'Supporting ${outbreakReport['type'].toString().toUpperCase()} response';
      }
    }

    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: GestureDetector(
        onTap: () => context.push('/hospital/${nearest['id']}'),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        Text(nearest['name'], style: GoogleFonts.playfairDisplay(color: AppColors.textDeep, fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text('0.8 km', style: GoogleFonts.plusJakartaSans(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              if (subLabel != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.emergency_outlined, size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(subLabel, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.secondaryDark, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => context.push('/hospital/${nearest['id']}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.shelf.withValues(alpha: 0.5), 
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  child: Text('VIEW FACILITY DETAILS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textDeep)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const String _lightMapStyle = '''
  [
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#e9e9e9"}, {"lightness": 17}]},
    {"featureType": "landscape", "elementType": "geometry", "stylers": [{"color": "#f5f5f5"}, {"lightness": 20}]},
    {"featureType": "road.highway", "elementType": "geometry.fill", "stylers": [{"color": "#ffffff"}, {"lightness": 17}]},
    {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#ffffff"}, {"lightness": 29}, {"weight": 0.2}]},
    {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#ffffff"}, {"lightness": 18}]},
    {"featureType": "road.local", "elementType": "geometry", "stylers": [{"color": "#ffffff"}, {"lightness": 16}]},
    {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#f5f5f5"}, {"lightness": 21}]},
    {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#dedede"}, {"lightness": 21}]},
    {"elementType": "labels.text.stroke", "stylers": [{"visibility": "on"}, {"color": "#ffffff"}, {"lightness": 16}]},
    {"elementType": "labels.text.fill", "stylers": [{"saturation": 36}, {"color": "#333333"}, {"lightness": 40}]},
    {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
    {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#f2f2f2"}, {"lightness": 19}]},
    {"featureType": "administrative", "elementType": "geometry.fill", "stylers": [{"color": "#fefefe"}, {"lightness": 20}]},
    {"featureType": "administrative", "elementType": "geometry.stroke", "stylers": [{"color": "#fefefe"}, {"lightness": 17}, {"weight": 1.2}]}
  ]
  ''';

  static const String _darkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#242f3e"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#746855"}]},
    {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
    {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
    {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#263c3f"}]},
    {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#6b9a76"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#38414e"}]},
    {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212a37"}]},
    {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9ca5b3"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#746855"}]},
    {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#1f2835"}]},
    {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#f3d19c"}]},
    {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#2f3948"}]},
    {"featureType": "transit.station", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#17263c"}]},
    {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#515c6d"}]},
    {"featureType": "water", "elementType": "labels.text.stroke", "stylers": [{"color": "#17263c"}]}
  ]
  ''';
}
