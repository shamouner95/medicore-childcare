import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MapContributionScreen extends ConsumerStatefulWidget {
  const MapContributionScreen({super.key});

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
    {"featureType": "road.highway", "labels.text.fill", "stylers": [{"color": "#f3d19c"}]},
    {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#2f3948"}]},
    {"featureType": "transit.station", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#17263c"}]},
    {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#515c6d"}]},
    {"featureType": "water", "elementType": "labels.text.stroke", "stylers": [{"color": "#17263c"}]}
  ]
  ''';

  @override
  ConsumerState<MapContributionScreen> createState() => _MapContributionScreenState();
}

class _MapContributionScreenState extends ConsumerState<MapContributionScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  LatLng _currentTapPosition = const LatLng(6.5244, 3.3792); // Lagos default
  bool _isAddingPoint = false;
  final _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isSelectorExpanded = false;

  final List<Map<String, dynamic>> _indicatorTypes = [
    {'id': 'heat', 'label': 'Heat Signature', 'icon': Icons.wb_sunny, 'color': Colors.orange},
    {'id': 'outbreak', 'label': 'Disease Outbreak', 'icon': Icons.coronavirus, 'color': Colors.red},
    {'id': 'disaster', 'label': 'Env. Disaster', 'icon': Icons.flood, 'color': Colors.blue},
    {'id': 'other', 'label': 'Env. Factor', 'icon': Icons.eco, 'color': Colors.green},
  ];

  String _selectedIndicatorId = 'outbreak';

  @override
  void initState() {
    super.initState();
    _loadExistingIndicators();
  }

  Future<void> _loadExistingIndicators() async {
    final snapshot = await FirebaseFirestore.instance.collection('environmental_indicators').get();
    if (!mounted) return;
    setState(() {
      _markers.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final typeId = data['type'] as String;
        final typeInfo = _indicatorTypes.firstWhere((t) => t['id'] == typeId, orElse: () => _indicatorTypes.last);
        
        _markers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(data['latitude'], data['longitude']),
            icon: BitmapDescriptor.defaultMarkerWithHue(_getHue(typeId)),
            onTap: () => _showMarkerOptions(doc.id, data, typeInfo),
            infoWindow: InfoWindow(
              title: typeInfo['label'],
              snippet: data['description'],
            ),
          ),
        );
      }
    });
  }

  void _showMarkerOptions(String markerId, Map<String, dynamic> data, Map<String, dynamic> typeInfo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.3), 
                borderRadius: BorderRadius.circular(2)
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(typeInfo['icon'], color: typeInfo['color'], size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(typeInfo['label'], style: GoogleFonts.plusJakartaSans(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textLight : AppColors.textDeep,
                      )),
                      Text(data['description'] ?? 'No description', style: GoogleFonts.plusJakartaSans(
                        color: isDark ? Colors.white70 : AppColors.secondary,
                      )),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (data['contributorId'] == FirebaseAuth.instance.currentUser?.uid)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _deleteMarker(markerId);
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Delete Observation', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMarker(String markerId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        title: Text('Delete Observation?', style: TextStyle(color: isDark ? AppColors.textLight : AppColors.textDeep)),
        content: Text('This will remove this intelligence marker from the global map.', style: TextStyle(color: isDark ? Colors.white70 : AppColors.secondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('environmental_indicators').doc(markerId).delete();
      _loadExistingIndicators();
    }
  }

  double _getHue(String typeId) {
    switch (typeId) {
      case 'heat': return BitmapDescriptor.hueOrange;
      case 'outbreak': return BitmapDescriptor.hueRed;
      case 'disaster': return BitmapDescriptor.hueAzure;
      case 'other': return BitmapDescriptor.hueGreen;
      default: return BitmapDescriptor.hueRed;
    }
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _currentTapPosition = position;
      _isAddingPoint = true;
    });
  }

  Future<void> _handleSearch(String query) async {
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    
    try {
      // Using Google Geocoding API
      const apiKey = 'AIzaSyDy9P5mt0Hpjdet5Tw03PmxNHNmh8HBJsM';
      final response = await http.get(
        Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['results'][0]['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];
          final target = LatLng(lat, lng);

          if (mounted) {
            _mapController.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: target, zoom: 15),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Location "$query" not found: ${data['status']}')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _saveIndicator(String description) async {
    if (description.isEmpty) return;
    
    final docRef = await FirebaseFirestore.instance.collection('environmental_indicators').add({
      'type': _selectedIndicatorId,
      'latitude': _currentTapPosition.latitude,
      'longitude': _currentTapPosition.longitude,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
      'contributorId': FirebaseAuth.instance.currentUser?.uid,
    });

    // Trigger Regional Notifications
    await _triggerRegionalAlerts(_selectedIndicatorId, description, _currentTapPosition, docRef.id);
    
    if (!mounted) return;
    setState(() => _isAddingPoint = false);
    _loadExistingIndicators();
  }

  Future<void> _triggerRegionalAlerts(String type, String description, LatLng location, String indicatorId) async {
    final typeInfo = _indicatorTypes.firstWhere((t) => t['id'] == type);
    
    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final batch = FirebaseFirestore.instance.batch();
      
      for (var userDoc in usersSnapshot.docs) {
        if (type == 'outbreak' || type == 'disaster') {
          final notifRef = FirebaseFirestore.instance.collection('notifications').doc();
          batch.set(notifRef, {
            'userId': userDoc.id,
            'title': '🌍 REGIONAL ALERT: ${typeInfo['label']}',
            'body': 'A new health risk has been reported: $description',
            'type': 'climate_alert',
            'riskLevel': 'High',
            'relatedId': indicatorId,
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error triggering alerts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: LatLng(6.5244, 3.3792), zoom: 12),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            onTap: _onMapTapped,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            style: isDark ? MapContributionScreen._darkMapStyle : MapContributionScreen._lightMapStyle,
          ),
          
          // Header & Search
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Column(
              children: [
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  borderRadius: 20,
                  child: Row(
                    children: [
                      const Icon(Icons.public, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('UNICEF Frontier Tech', 
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold, 
                                fontSize: 16, 
                                color: isDark ? AppColors.textLight : AppColors.textDeep
                              )),
                            Text('Field Intelligence & Early Warning', 
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, 
                                color: isDark ? Colors.white70 : AppColors.secondary
                              )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: isDark ? Colors.white : AppColors.textDeep),
                    decoration: InputDecoration(
                      hintText: 'Search location...',
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : AppColors.secondary),
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: _isSearching 
                        ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)))
                        : IconButton(
                            icon: const Icon(Icons.send, color: AppColors.primary),
                            onPressed: () => _handleSearch(_searchController.text),
                          ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onSubmitted: _handleSearch,
                  ),
                ).animate().fadeIn(delay: 400.ms).slideY(begin: -0.2),
              ],
            ),
          ),

          if (_isAddingPoint)
            _buildAddIndicatorPanel(isDark),
          
          // Floating Action Legend - Only show when clicked/selected
          Positioned(
            bottom: 120,
            right: 20,
            child: AnimatedOpacity(
              duration: 300.ms,
              opacity: _isAddingPoint ? 0.0 : 1.0,
              child: IgnorePointer(
                ignoring: _isAddingPoint,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_isSelectorExpanded)
                      ..._indicatorTypes.map((type) {
                        final isSelected = _selectedIndicatorId == type['id'];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.surfaceDark : Colors.white,
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(color: type['color'], width: 1),
                                  ),
                                  child: Text(
                                    type['label'],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: type['color'],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.2),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: FloatingActionButton(
                                  heroTag: 'fab_${type['id']}',
                                  onPressed: () {
                                    setState(() {
                                      _selectedIndicatorId = type['id'];
                                    });
                                  },
                                  backgroundColor: isSelected ? type['color'] : (isDark ? AppColors.surfaceDark : Colors.white),
                                  elevation: isSelected ? 4 : 2,
                                  shape: const CircleBorder(),
                                  child: Icon(
                                    type['icon'], 
                                    color: isSelected ? Colors.white : type['color'],
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.2);
                      }),
                    
                    const SizedBox(height: 8),
                    
                    // Toggle Button
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: FloatingActionButton(
                        heroTag: 'fab_main_expand',
                        onPressed: () => setState(() => _isSelectorExpanded = !_isSelectorExpanded),
                        backgroundColor: _isSelectorExpanded ? Colors.redAccent : AppColors.primary,
                        elevation: 4,
                        shape: const CircleBorder(),
                        child: Icon(
                          _isSelectorExpanded ? Icons.close : Icons.layers_outlined, 
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddIndicatorPanel(bool isDark) {
    final descriptionController = TextEditingController();

    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        borderRadius: 32,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.add_location_alt, color: AppColors.primary),
                const SizedBox(width: 12),
                Text('New Intelligence Report', style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textLight : AppColors.textDeep
                )),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _isAddingPoint = false), 
                  icon: Icon(Icons.close, color: isDark ? Colors.white70 : AppColors.textDeep)
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('SELECT TYPE', style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: isDark ? Colors.white38 : AppColors.secondary,
            )),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _indicatorTypes.map((type) {
                  final isSelected = _selectedIndicatorId == type['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      onTap: () => setState(() => _selectedIndicatorId = type['id']),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: 200.ms,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? type['color'].withOpacity(0.2) : (isDark ? Colors.white10 : AppColors.background),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? type['color'] : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(type['icon'], size: 18, color: isSelected ? type['color'] : (isDark ? Colors.white38 : AppColors.secondary)),
                            const SizedBox(width: 8),
                            Text(type['label'], style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? (isDark ? Colors.white : type['color']) : (isDark ? Colors.white38 : AppColors.secondary),
                            )),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: descriptionController,
              maxLines: 2,
              style: TextStyle(color: isDark ? AppColors.textLight : AppColors.textDeep),
              decoration: InputDecoration(
                hintText: 'Describe the observation...',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : AppColors.secondary),
                filled: true,
                fillColor: isDark ? Colors.white10 : AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => _saveIndicator(descriptionController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('SUBMIT REPORT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ).animate().slideY(begin: 1, end: 0, curve: Curves.easeOutExpo),
    );
  }
}
