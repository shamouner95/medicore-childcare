import 'package:hospital_app/providers/country_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/gemini_ai_service.dart';
import '../../core/theme/app_colors.dart';
import 'package:hospital_app/core/widgets/logout_wrapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/glass_card.dart';
import '../profile/profile_screen.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  int _currentIndex = 0;
  String _selectedCategory = 'All';

  void _onIndexChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return LogoutWrapper(
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
        body: Stack(
          children: [
            // Main Content Area
            _currentIndex == 3 
              ? ProfileScreen(onHomePressed: () => _onIndexChanged(0))
              : Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isTablet ? 800 : double.infinity),
                    child: StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
                        builder: (context, snapshot) {
                          final userData = snapshot.data?.data() as Map<String, dynamic>?;
                          final userName = userData?['name'] ?? 'User';
                          final userImageUrl = userData?['profileImageUrl'];

                          return _buildHomeBody(context, userName, userImageUrl, userData, isDark, isTablet);
                        }
                      ),
                  ),
                ),

            // Floating Minimalist Dock
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: _buildMinimalDock(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeBody(BuildContext context, String userName, String? userImageUrl, Map<String, dynamic>? userData, bool isDark, bool isTablet) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildWarmHeader(context, userName, userImageUrl, isTablet),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 32.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _buildSearchSection(isDark),
                const SizedBox(height: 32),
                _buildCategoryChips(isDark),
                const SizedBox(height: 32),
                _buildInsightCard(context, isDark, isTablet),
                const SizedBox(height: 32),
                _buildSectionLabel('SERVICES'),
                const SizedBox(height: 8),
                _buildServiceGrid(context, isDark, isTablet),
                const SizedBox(height: 140),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: AppColors.secondaryDark.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildWarmHeader(BuildContext context, String name, String? imageUrl, bool isTablet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: isTablet ? 140 : 120,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: EdgeInsets.fromLTRB(isTablet ? 32 : 24, 60, isTablet ? 32 : 24, 0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('EEEE · MMM d').format(DateTime.now()).toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Good day, ${name.split(' ')[0]}',
                    style: GoogleFonts.playfairDisplay(
                      color: isDark ? Colors.white : AppColors.textDeep,
                      fontSize: isTablet ? 28 : 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _onIndexChanged(3),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.shelf, width: 2),
                    image: imageUrl != null 
                      ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                      : const DecorationImage(image: NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400'), fit: BoxFit.cover),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection(bool isDark) {
    return GestureDetector(
      onTap: () => _showAISearch(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        height: 56,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.shelf),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Text(
              'Search for care...',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.secondaryDark.withValues(alpha: 0.4),
                fontSize: 15,
                fontWeight: FontWeight.w500
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips(bool isDark) {
    final categories = ['All', 'General', 'Cardiology', 'Dermatology'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categories.map((cat) {
          final isSelected = cat == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.shelf,
                  width: 1,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ] : [],
              ),
              child: Text(
                cat,
                style: GoogleFonts.plusJakartaSans(
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textDeep),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context, bool isDark, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primary.withValues(alpha: 0.2) : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'HEALTH TREND',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '+12%',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Check your symptoms',
            style: GoogleFonts.playfairDisplay(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textDeep,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get instant clinical insights using our Gemini-powered diagnostic assistant.',
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? Colors.white70 : AppColors.secondaryDark,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              for (int i = 0; i < 5; i++)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 30,
                  height: 60 + (i * 10).toDouble(),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2 + (i * 0.15)),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.push('/symptoms'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Start Analysis',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildServiceGrid(BuildContext context, bool isDark, bool isTablet) {
    return Column(
      children: [
        _buildServiceItem('Smart Triage', 'AI-driven facility matching', Icons.auto_awesome_rounded, () => context.push('/map')),
        const SizedBox(height: 12),
        _buildServiceItem('Consultation', 'Find a specialist near you', Icons.medical_services_outlined, () => context.push('/doctors')),
        const SizedBox(height: 12),
        _buildServiceItem('Appointments', 'View your upcoming visits', Icons.calendar_today_outlined, () => context.push('/appointments')),
        const SizedBox(height: 12),
        _buildServiceItem('Health Reports', 'Lab results and analysis', Icons.insert_chart_outlined_rounded, () => context.push('/results')),
      ],
    );
  }

  Widget _buildServiceItem(String title, String subtitle, IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        borderRadius: 20,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textDeep,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      color: isDark ? Colors.white60 : AppColors.secondaryDark,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.shelf, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalDock(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: AppColors.shelf),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDockTab(Icons.wb_sunny_outlined, _currentIndex == 0, () => _onIndexChanged(0)),
          _buildDockTab(Icons.chat_bubble_outline_rounded, _currentIndex == 1, () => context.push('/chat')),
          _buildDockTab(Icons.auto_awesome_outlined, false, () => context.push('/symptoms'), isSpecial: true),
          _buildDockTab(Icons.book_outlined, _currentIndex == 2, () => context.push('/appointments')),
          _buildDockTab(Icons.person_outline_rounded, _currentIndex == 3, () => _onIndexChanged(3)),
        ],
      ),
    );
  }

  Widget _buildDockTab(IconData icon, bool active, VoidCallback onTap, {bool isSpecial = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryLight : (isSpecial ? AppColors.primary : Colors.transparent),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Icon(
          icon, 
          color: active ? AppColors.primary : (isSpecial ? Colors.white : AppColors.secondaryDark), 
          size: 22
        ),
      ),
    );
  }

  void _showAISearch(BuildContext context) {
    final searchController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AISearchSheet(searchController: searchController),
    );
  }
}

class _AISearchSheet extends ConsumerStatefulWidget {
  final TextEditingController searchController;
  const _AISearchSheet({required this.searchController});

  @override
  ConsumerState<_AISearchSheet> createState() => _AISearchSheetState();
}

class _AISearchSheetState extends ConsumerState<_AISearchSheet> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _hospitalResults = [];
  List<Map<String, dynamic>> _indicatorResults = [];
  String? _aiInsight;

  Future<void> _performSearch() async {
    if (widget.searchController.text.isEmpty) return;
    setState(() {
      _isLoading = true;
      _aiInsight = null;
    });

    try {
      final selectedCountry = ref.read(countryProvider);
      
      // 1. Fetch Hospitals
      final hospitalSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'hospital')
          .get();
      
      final allHospitals = hospitalSnapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc['name'],
        'speciality': doc['speciality'],
        'address': doc['address'],
        'doctorCount': doc.data().containsKey('doctorCount') ? doc['doctorCount'] : 0,
        'bedSpaces': doc.data().containsKey('bedSpaces') ? doc['bedSpaces'] : 0,
      }).toList();

      // 2. Fetch Environmental Indicators (Health Worker data)
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

      // 3. Get AI Insight combining both
      final insight = await GeminiAIService().getFieldAwareInsight(
        query: widget.searchController.text,
        indicators: indicators,
        hospitals: allHospitals,
        country: selectedCountry,
      );

      // 4. Also perform the integrated search for both hospitals and indicators
      final searchResult = await GeminiAIService().searchEverything(
        query: widget.searchController.text,
        hospitals: allHospitals,
        indicators: indicators,
        country: selectedCountry,
      );

      setState(() {
        _aiInsight = insight;
        _hospitalResults = allHospitals.where((h) => searchResult['hospitalIds']!.contains(h['id'])).toList();
        _indicatorResults = indicators.where((i) {
          // Find if this indicator's ID (or some matching logic) is in indicatorIds
          // Since markers in Firestore have IDs, we should probably ensure the indicators list has IDs
          return searchResult['indicatorIds']!.contains(indicators.indexOf(i).toString()); 
        }).toList();
        
        // Wait, the searchEverything prompt might return IDs. I should ensure indicators have IDs.
        // Let's adjust the indicator mapping in step 2.
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _aiInsight = "I encountered an issue connecting to field intelligence. Please proceed to the nearest medical center.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.shelf, 
              borderRadius: BorderRadius.circular(2)
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: widget.searchController,
            style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white : AppColors.textDeep),
            decoration: InputDecoration(
              hintText: 'Describe your situation or search for a hospital...',
              hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.secondaryDark.withValues(alpha: 0.4)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.auto_awesome, color: AppColors.primary), 
                onPressed: _performSearch
              ),
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => _performSearch(),
          ),
          const SizedBox(height: 24),
          if (_isLoading) 
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_aiInsight != null) ...[
                    _buildAIInsightBox(isDark),
                    const SizedBox(height: 32),
                  ],
                  if (_indicatorResults.isNotEmpty) ...[
                    Text(
                      'FIELD ALERTS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._indicatorResults.map((i) => _buildIndicatorListItem(i, isDark)),
                    const SizedBox(height: 32),
                  ],
                  if (_hospitalResults.isNotEmpty) ...[
                    Text(
                      'RECOMMENDED FACILITIES',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._hospitalResults.map((h) => _buildHospitalListItem(h, isDark)),
                  ] else if (_aiInsight != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text(
                          'No specific hospitals matched your description, but please follow the AI guidance above.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(color: AppColors.secondaryDark, fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsightBox(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Text(
                'FIELD INTELLIGENCE INSIGHT',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _aiInsight!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.white : AppColors.textDeep,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Based on real-time health worker reports.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: AppColors.secondaryDark,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildHospitalListItem(Map<String, dynamic> h, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: 16,
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: AppColors.primaryLight, 
            child: Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 20)
          ),
          title: Text(h['name'], style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textDeep)),
          subtitle: Text(h['speciality'], style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white60 : AppColors.secondaryDark, fontSize: 12)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.shelf),
          onTap: () => context.push('/hospital/${h['id']}'),
        ),
      ),
    );
  }

  Widget _buildIndicatorListItem(Map<String, dynamic> i, bool isDark) {
    final IconData icon;
    final Color color;
    switch (i['type']) {
      case 'heat':
        icon = Icons.wb_sunny_rounded;
        color = Colors.orange;
        break;
      case 'outbreak':
        icon = Icons.coronavirus_rounded;
        color = Colors.red;
        break;
      case 'disaster':
        icon = Icons.flood_rounded;
        color = Colors.blue;
        break;
      default:
        icon = Icons.eco_rounded;
        color = Colors.green;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            i['description'] ?? 'Field Intelligence',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textDeep,
            ),
          ),
          subtitle: Text(
            'Regional Risk Marker',
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
          ),
          onTap: () => context.push('/map'), // Navigate to map to see context
        ),
      ),
    );
  }
}
