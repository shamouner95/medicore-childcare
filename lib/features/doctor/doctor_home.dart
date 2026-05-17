import 'package:hospital_app/providers/country_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_app/auth_repository.dart';
import 'package:hospital_app/core/theme/app_colors.dart';
import 'package:hospital_app/core/widgets/logout_wrapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hospital_app/models/appointment_model.dart';
import 'package:hospital_app/features/doctor/appointment_detail_screen.dart';
import 'package:hospital_app/features/doctor/prescription_screen.dart';
import 'package:hospital_app/features/doctor/medical_records_screen.dart';
import 'package:hospital_app/features/doctor/manage_schedule_screen.dart';
import 'package:hospital_app/features/doctor/clinical_forecast_screen.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:hospital_app/core/widgets/glass_card.dart';

import 'package:hospital_app/core/theme/theme_provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/gemini_ai_service.dart';
import '../../providers/notification_provider.dart';
import '../hospital/notifications_screen.dart';
import '../profile/profile_screen.dart';

class DoctorHomeScreen extends ConsumerStatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  ConsumerState<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends ConsumerState<DoctorHomeScreen> {
  int _currentIndex = 0;

  void _onIndexChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return LogoutWrapper(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            // Main Content Area
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isTablet ? 900 : double.infinity),
                child: _buildBodyContent(user, isTablet),
              ),
            ),

            // Floating Bottom Dock
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: _buildPremiumDock(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent(User? user, bool isTablet) {
    switch (_currentIndex) {
      case 0:
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
          builder: (context, userSnapshot) {
            final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return _buildHomeBody(context, userData, isDark, isTablet);
          }
        );
      case 1:
        return const ManageScheduleScreen();
      case 2:
        return const _HospitalRequestsScreen();
      case 3:
        return ProfileScreen(onHomePressed: () => _onIndexChanged(0));
      default:
        return const Center(child: Text('Home'));
    }
  }

  Widget _buildHomeBody(BuildContext context, Map<String, dynamic>? userData, bool isDark, bool isTablet) {
    final doctorName = userData?['name'] ?? 'Doctor';
    final doctorImageUrl = userData?['profileImageUrl'];
    return Stack(
      children: [
        // Background Gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isDark ? AppColors.backgroundDark : AppColors.background,
                  isDark ? AppColors.surfaceDark : AppColors.primaryLight.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: isTablet ? 500 : 350,
            height: isTablet ? 500 : 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.03),
            ),
          ).animate().scale(duration: 4.seconds, curve: Curves.easeInOut).fadeIn(),
        ),
        Positioned(
          bottom: -50,
          left: -50,
          child: Container(
            width: isTablet ? 400 : 250,
            height: isTablet ? 400 : 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.03),
            ),
          ).animate().scale(duration: 3.seconds, curve: Curves.easeInOut).fadeIn(),
        ),

        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildPremiumSliverHeader(context, doctorName, doctorImageUrl, isTablet),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 32.0 : 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildAISearchBar(isDark),
                    const SizedBox(height: 32),
                    _buildDoctorStatsCards(context, isTablet, userData),
                    const SizedBox(height: 32),
              _buildAIInsightsDashboard(context, isTablet),
              const SizedBox(height: 32),
              _buildSectionHeader(context, 'Practice Intelligence', '', isTablet),
                    const SizedBox(height: 16),
                    _buildPracticeManagementCard(context, isTablet),
                    const SizedBox(height: 32),
                    _buildSectionHeader(context, 'Pending Consultations', 'View All', isTablet),
                    const SizedBox(height: 16),
                    _buildDoctorAppointmentsList(context, isTablet),
                    const SizedBox(height: 32),
                    _buildSectionHeader(context, 'Management Tools', '', isTablet),
                    const SizedBox(height: 16),
                    _buildDoctorActionGrid(context, isTablet),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPremiumSliverHeader(BuildContext context, String name, String? imageUrl, bool isTablet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedCountry = ref.watch(countryProvider);
    final countries = ref.watch(availableCountriesProvider);

    return SliverAppBar(
      expandedHeight: isTablet ? 260 : 220,
      collapsedHeight: isTablet ? 120 : 100,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: EdgeInsets.fromLTRB(isTablet ? 32 : 24, 60, isTablet ? 32 : 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Text(
                                'Practice Dashboard',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.secondary, 
                                  fontSize: isTablet ? 18 : 16, 
                                  fontWeight: FontWeight.w500
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedCountry,
                                    isDense: true,
                                    dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                                    style: GoogleFonts.plusJakartaSans(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
                                    items: countries.map((String country) {
                                      return DropdownMenuItem<String>(
                                        value: country,
                                        child: Text(country),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        ref.read(countryProvider.notifier).setCountry(value);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            'Dr. $name',
                            style: GoogleFonts.playfairDisplay(
                              color: isDark ? AppColors.textLight : AppColors.textDeep,
                              fontSize: isTablet ? 44 : 36,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _buildNotificationIcon(context),
                      const SizedBox(width: 12),
                      _buildGlassIconButton(
                        context,
                        ref.watch(themeProvider) == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        () => ref.read(themeProvider.notifier).toggleTheme(),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => ref.read(authRepositoryProvider).signOut(),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : AppColors.surface,
                            shape: BoxShape.circle,
                            boxShadow: isDark ? null : AppColors.softShadow,
                            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.shelf),
                          ),
                          child: Icon(Icons.logout_rounded, color: isDark ? AppColors.textLight : AppColors.textDeep, size: 24),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: isTablet ? 32.0 : 24.0),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
              ),
              child: CircleAvatar(
                radius: isTablet ? 28 : 22,
                backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
                backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                    ? NetworkImage(imageUrl)
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAISearchBar(bool isDark) {
    return GestureDetector(
      onTap: () => _showAISearch(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        height: 60,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.shelf),
          boxShadow: isDark ? null : AppColors.softShadow,
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.primary, size: 24),
            const SizedBox(width: 12),
            Text('Search specialist hospitals...', style: GoogleFonts.plusJakartaSans(color: AppColors.textDeep.withValues(alpha: 0.5), fontSize: 16, fontWeight: FontWeight.w500)),
          ],
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

  Widget _buildDoctorStatsCards(BuildContext context, bool isTablet, Map<String, dynamic>? userData) {
    final user = FirebaseAuth.instance.currentUser;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterday = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        int patientCount = 0;
        int todayCount = 0;
        int yesterdayCount = 0;
        
        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          final appointmentData = docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
          
          patientCount = appointmentData.map((data) => data['patientId']).toSet().length;
          todayCount = appointmentData.where((data) => data['appointmentDate'] == today).length;
          yesterdayCount = appointmentData.where((data) => data['appointmentDate'] == yesterday).length;
        }

        final fee = (userData?['consultationFee'] ?? 50).toDouble();
        final revenue = todayCount * fee;
        final rating = userData?['rating'] ?? 4.9;
        
        // Calculate dynamic trend for consults
        String consultsTrend = "";
        bool isConsultsPositive = true;
        if (yesterdayCount > 0) {
          final diff = ((todayCount - yesterdayCount) / yesterdayCount * 100).toInt();
          consultsTrend = "${diff >= 0 ? '+' : ''}$diff%";
          isConsultsPositive = diff >= 0;
        } else if (todayCount > 0) {
          consultsTrend = "New";
          isConsultsPositive = true;
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildStatCard(context, 
                title: 'Active Patients', 
                value: patientCount.toString(), 
                icon: Icons.group_rounded, 
                color: AppColors.primary, 
                isTablet: isTablet, 
                trend: 'Lifetime', 
                isPositive: true
              ),
              const SizedBox(width: 16),
              _buildStatCard(context, 
                title: 'Revenue Today', 
                value: '\$${revenue.toInt()}', 
                icon: Icons.payments_rounded, 
                color: AppColors.secondary, 
                isTablet: isTablet, 
                trend: '+12%', 
                isPositive: true
              ),
              const SizedBox(width: 16),
              _buildStatCard(context, 
                title: 'Avg Rating', 
                value: rating.toString(), 
                icon: Icons.star_rounded, 
                color: AppColors.accentSecondary, 
                isTablet: isTablet, 
                trend: 'Top 5%', 
                isPositive: true
              ),
              const SizedBox(width: 16),
              _buildStatCard(context, 
                title: 'Today\'s Consults', 
                value: todayCount.toString(), 
                icon: Icons.event_available_rounded, 
                color: AppColors.accent, 
                isTablet: isTablet, 
                trend: consultsTrend, 
                isPositive: isConsultsPositive
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms).slideX(begin: 0.1);
      },
    );
  }

  Widget _buildStatCard(BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isTablet,
    required String trend,
    required bool isPositive,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 32,
      child: Container(
        width: isTablet ? 200 : 180,
        height: isTablet ? 180 : 160,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (trend.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isPositive ? Colors.green : Colors.red).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: isPositive ? Colors.green : Colors.red,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trend,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isTablet ? 36 : 32,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textDeep,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white38 : AppColors.secondary,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorAppointmentsList(BuildContext context, bool isTablet) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: user?.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return _buildEmptyState(context);

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final patientId = data['patientId'];

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(patientId).snapshots(),
              builder: (context, patientSnapshot) {
                final patientData = patientSnapshot.data?.data() as Map<String, dynamic>?;
                final patientName = patientData?['name'] ?? 'Patient';
                final patientImage = patientData?['profileImageUrl'];

                final isDark = Theme.of(context).brightness == Brightness.dark;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GlassCard(
                    padding: const EdgeInsets.all(20),
                    borderRadius: 28,
                    child: Row(
                      children: [
                        Container(
                          width: isTablet ? 80 : 65,
                          height: isTablet ? 80 : 65,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            image: patientImage != null && patientImage.isNotEmpty
                                ? DecorationImage(image: NetworkImage(patientImage), fit: BoxFit.cover)
                                : const DecorationImage(image: NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400'), fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(patientName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: isTablet ? 20 : 18, color: isDark ? Colors.white : AppColors.textDeep)),
                              const SizedBox(height: 4),
                              Text(
                                data['symptoms'] ?? 'No symptoms reported',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white60 : AppColors.secondary, fontSize: isTablet ? 14 : 13),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentDetailScreen(appointment: Appointment.fromMap(docs[index].id, data)))),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.arrow_forward_ios_rounded, color: AppColors.accent, size: isTablet ? 22 : 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1);
              }
            );
          },
        );
      },
    );
  }

  Widget _buildAIInsightsDashboard(BuildContext context, bool isTablet) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        int highPriorityCount = 0;
        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final urgency = data['urgency'] ?? 'Low';
            if (urgency == 'High' || urgency == 'Emergency') {
              highPriorityCount++;
            }
          }
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isTablet ? 32 : 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'MEDICORE AI INSIGHTS',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                highPriorityCount > 0 
                  ? '$highPriorityCount high-priority cases detected.' 
                  : 'Practice is stable. No critical flags.',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: isTablet ? 26 : 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                highPriorityCount > 0
                  ? 'Gemini analyzed symptoms for your upcoming consultations and flagged $highPriorityCount cases for immediate attention.'
                  : 'AI has analyzed recent patient check-ins. All metrics are within expected ranges.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: isTablet ? 15 : 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ClinicalForecastScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        highPriorityCount > 0 ? 'Review Clinical Forecast' : 'View Practice Trends',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ).animate().shimmer(duration: 3.seconds, color: Colors.white.withValues(alpha: 0.1)).slideX(begin: 0.1, curve: Curves.easeOutQuart);
      }
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(40),
      borderRadius: 32,
      child: Column(
        children: [
          Icon(Icons.calendar_today_rounded, size: 48, color: AppColors.textDeep.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No pending requests', style: GoogleFonts.plusJakartaSans(color: AppColors.textDeep.withValues(alpha: 0.5), fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildDoctorActionGrid(BuildContext context, bool isTablet) {
    final crossAxisCount = isTablet ? 4 : 2;
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isTablet ? 1.5 : 1.25,
      children: [
        _buildActionCard(context, Icons.edit_note_rounded, 'Prescribe', AppColors.accent, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const PrescriptionScreen()));
        }),
        _buildActionCard(context, Icons.history_edu_rounded, 'Records', Colors.blueAccent, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const MedicalRecordsScreen()));
        }),
        _buildActionCard(context, Icons.share_location_rounded, 'Referral', AppColors.secondary, () {
          context.push('/referral');
        }),
        _buildActionCard(context, Icons.chat_bubble_rounded, 'Chat', Colors.blueAccent, () {
          context.push('/doctor-chats');
        }),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildActionCard(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: 32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : AppColors.textDeep)),
          ],
        ),
      ),
    );
  }

  Widget _buildPracticeManagementCard(BuildContext context, bool isTablet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: user?.uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        return FutureBuilder<PracticeInsights>(
          future: _getInsights(snapshot.data?.docs),
          builder: (context, insightSnapshot) {
            final insights = insightSnapshot.data;
            final isLoading = insightSnapshot.connectionState == ConnectionState.waiting;

            return GlassCard(
              padding: EdgeInsets.all(isTablet ? 32 : 24),
              borderRadius: 32,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.analytics_outlined, color: AppColors.accent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'PRACTICE PERFORMANCE',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white70 : AppColors.secondary,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      if (isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPracticeMetric('Efficiency', insights?.efficiencyScore ?? '--', AppColors.primary, isTablet),
                      _buildPracticeMetric('Satisfaction', '98%', Colors.blue, isTablet),
                      _buildPracticeMetric('Wait Time', '12m', AppColors.secondary, isTablet),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lightbulb_outline_rounded, color: AppColors.accent, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  insights?.optimizationTips.isNotEmpty == true 
                                      ? insights!.optimizationTips.first 
                                      : 'AI is analyzing your practice data to provide optimization tips.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isTablet ? 14 : 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : AppColors.textDeep,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => context.push('/map'),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(Icons.map_rounded, color: AppColors.secondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Future<PracticeInsights> _getInsights(List<QueryDocumentSnapshot>? docs) async {
    if (docs == null || docs.isEmpty) {
      return PracticeInsights(
        efficiencyScore: "N/A",
        optimizationTips: ["Start booking appointments to see insights."],
        patientSatisfactionForecast: "",
        busyHourPredictions: [],
      );
    }
    final selectedCountry = ref.read(countryProvider);
    final logs = docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    return GeminiAIService().getPracticeManagementInsights(logs, country: selectedCountry);
  }

  Widget _buildPracticeMetric(String label, String value, Color color, bool isTablet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: isTablet ? 24 : 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: isTablet ? 12 : 10, fontWeight: FontWeight.w700, color: isDark ? Colors.white30 : AppColors.secondary)),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String action, bool isTablet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.playfairDisplay(fontSize: isTablet ? 26 : 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textDeep)),
        if (action.isNotEmpty)
          Text(action, style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: isTablet ? 16 : 14)),
      ],
    );
  }

  Widget _buildNotificationIcon(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surface,
              shape: BoxShape.circle,
              boxShadow: isDark ? [] : AppColors.softShadow,
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.shelf),
            ),
            child: Icon(Icons.notifications_outlined, color: isDark ? Colors.white : AppColors.textDeep, size: 24),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton(BuildContext context, IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: isDark ? [] : AppColors.softShadow,
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.shelf),
        ),
        child: Icon(icon, color: isDark ? Colors.white : AppColors.textDeep, size: 24),
      ),
    );
  }

  Widget _buildPremiumDock(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.surfaceDark : Colors.white).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 20)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDockItem(context, Icons.dashboard_rounded, _currentIndex == 0, 0),
              _buildDockItem(context, Icons.calendar_month_rounded, _currentIndex == 1, 1),
              _buildDockItem(context, Icons.business_rounded, _currentIndex == 2, 2),
              _buildDockItem(context, Icons.person_outline_rounded, _currentIndex == 3, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDockItem(BuildContext context, IconData icon, bool isSelected, int index) {
    return GestureDetector(
      onTap: () => _onIndexChanged(index),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          shape: BoxShape.circle,
          boxShadow: isSelected ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))] : null,
        ),
        child: Icon(icon, color: isSelected ? Colors.white : AppColors.secondary, size: 28),
      ),
    );
  }
}

class _AISearchSheet extends ConsumerStatefulWidget {
  final TextEditingController searchController;
  const _AISearchSheet({required this.searchController});

  @override
  ConsumerState<_AISearchSheet> createState() => _AISearchSheetState();
}

class _HospitalRequestsScreen extends StatelessWidget {
  const _HospitalRequestsScreen();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Text('Hospital Invitations', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('hospital_requests')
            .where('toId', isEqualTo: user?.uid)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final requests = snapshot.data!.docs;

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business_rounded, size: 64, color: AppColors.textDeep.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                  Text('No pending hospital invitations', style: GoogleFonts.plusJakartaSans(color: AppColors.textDeep.withValues(alpha: 0.5))),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index].data() as Map<String, dynamic>;
              return GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 24,
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_hospital, color: AppColors.primary),
                      ),
                      title: Text(req['fromName'], style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textDeep)),
                      subtitle: Text('Wants you to join their medical staff', style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white60 : AppColors.textDeep.withValues(alpha: 0.6))),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _handleRequest(requests[index].id, 'rejected'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text('Reject', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleRequest(requests[index].id, 'accepted', hospitalId: req['fromId'], doctorId: user?.uid),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            child: Text('Accept', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleRequest(String requestId, String status, {String? hospitalId, String? doctorId}) async {
    await FirebaseFirestore.instance.collection('hospital_requests').doc(requestId).update({
      'status': status,
    });

    if (status == 'accepted' && hospitalId != null && doctorId != null) {
      await FirebaseFirestore.instance.collection('users').doc(doctorId).update({
        'hospitalId': hospitalId,
      });
    }
  }
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

      // 4. Perform integrated search
      final searchResult = await GeminiAIService().searchEverything(
        query: widget.searchController.text,
        hospitals: allHospitals,
        indicators: indicators,
        country: selectedCountry,
      );

      setState(() {
        _aiInsight = insight;
        _hospitalResults = allHospitals.where((h) => searchResult['hospitalIds']!.contains(h['id'])).toList();
        _indicatorResults = indicators.where((i) => searchResult['indicatorIds']!.contains(i['id'])).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _aiInsight = "Error connecting to field intelligence. Please proceed with standard clinical protocols.";
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
            decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: widget.searchController,
            style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white : AppColors.textDeep),
            decoration: InputDecoration(
              hintText: 'Search hospitals or field alerts...',
              hintStyle: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white38 : AppColors.textDeep.withValues(alpha: 0.4)),
              suffixIcon: IconButton(icon: const Icon(Icons.auto_awesome, color: AppColors.primary), onPressed: _performSearch),
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: isDark ? BorderSide.none : const BorderSide(color: AppColors.shelf)),
            ),
            onSubmitted: (_) => _performSearch(),
          ),
          const SizedBox(height: 24),
          if (_isLoading) const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
                    Text('FIELD ALERTS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.orange.shade700)),
                    const SizedBox(height: 16),
                    ..._indicatorResults.map((i) => _buildIndicatorListItem(i, isDark)),
                    const SizedBox(height: 32),
                  ],
                  if (_hospitalResults.isNotEmpty) ...[
                    Text('RECOMMENDED FACILITIES', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.primary)),
                    const SizedBox(height: 16),
                    ..._hospitalResults.map((h) => _buildHospitalListItem(h, isDark)),
                  ] else if (_aiInsight != null)
                    Center(child: Padding(padding: const EdgeInsets.all(40.0), child: Text('No matching facilities found.', style: GoogleFonts.plusJakartaSans(color: AppColors.secondary, fontSize: 13)))),
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
        gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.1), AppColors.primary.withValues(alpha: 0.05)]),
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
              Text('FIELD INTELLIGENCE INSIGHT', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 16),
          Text(_aiInsight!, style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.6, color: isDark ? Colors.white : AppColors.textDeep)),
        ],
      ),
    );
  }

  Widget _buildHospitalListItem(Map<String, dynamic> h, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: 20,
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.local_hospital, color: AppColors.primary),
          ),
          title: Text(h['name'], style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textDeep)),
          subtitle: Text(h['speciality'], style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white60 : AppColors.textDeep.withValues(alpha: 0.6))),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primary),
          onTap: () => context.push('/hospital/${h['id']}'),
        ),
      ),
    );
  }

  Widget _buildIndicatorListItem(Map<String, dynamic> i, bool isDark) {
    final IconData icon;
    final Color color;
    switch (i['type']) {
      case 'heat': icon = Icons.wb_sunny_rounded; color = Colors.orange; break;
      case 'outbreak': icon = Icons.coronavirus_rounded; color = Colors.red; break;
      case 'disaster': icon = Icons.flood_rounded; color = Colors.blue; break;
      default: icon = Icons.eco_rounded; color = Colors.green;
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
          title: Text(i['description'] ?? 'Field Intelligence', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textDeep)),
          subtitle: Text('Regional Risk Marker', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.bold)),
          onTap: () => context.push('/map'),
        ),
      ),
    );
  }
}
