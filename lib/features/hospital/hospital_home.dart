import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/notification_provider.dart';
import 'notifications_screen.dart';
import 'all_appointments_screen.dart';
import './widgets/hospital_stats_grid.dart';
import './widgets/hospital_analytics.dart';
import './widgets/appointment_card.dart';
import '../../providers/hospital_provider.dart';
import '../../providers/staff_provider.dart';

class HospitalHomeScreen extends ConsumerStatefulWidget {
  const HospitalHomeScreen({super.key});

  @override
  ConsumerState<HospitalHomeScreen> createState() => _HospitalHomeScreenState();
}

class _HospitalHomeScreenState extends ConsumerState<HospitalHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final Color bgColor =
        isDark ? AppColors.backgroundDark : AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      body: isMobile
          ? SafeArea(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _HospitalDashboard(),
                  _HospitalScheduleManagement(),
                  _HospitalStaffManagement(),
                  const _HospitalProfile(),
                ],
              ),
            )
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.selected,
                  backgroundColor: surfaceColor,
                  selectedIconTheme:
                      const IconThemeData(color: AppColors.primary),
                  unselectedIconTheme: IconThemeData(
                      color: AppColors.textDeep.withValues(alpha: 0.5)),
                  selectedLabelTextStyle: GoogleFonts.plusJakartaSans(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelTextStyle: GoogleFonts.plusJakartaSans(
                    color: AppColors.textDeep.withValues(alpha: 0.5),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month),
                      label: Text('Schedule'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: Text('Staff'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('Profile'),
                    ),
                  ],
                ),
                const VerticalDivider(
                    thickness: 1, width: 1, color: AppColors.shelf),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      _HospitalDashboard(),
                      _HospitalScheduleManagement(),
                      _HospitalStaffManagement(),
                      const _HospitalProfile(),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: isMobile
          ? Container(
              decoration: const BoxDecoration(
                border:
                    Border(top: BorderSide(color: AppColors.shelf, width: 1)),
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) => setState(() => _selectedIndex = index),
                selectedItemColor: AppColors.primary,
                unselectedItemColor: AppColors.textDeep.withValues(alpha: 0.4),
                backgroundColor: AppColors.background,
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard), label: 'Home'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.calendar_month), label: 'Schedule'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.people), label: 'Staff'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.person), label: 'Profile'),
                ],
              ),
            )
          : null,
    );
  }
}

class _HospitalDashboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final statsAsync = ref.watch(hospitalDashboardStatsProvider);
    final appointmentsAsync = ref.watch(hospitalAppointmentsProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UNICEF Climate Venture',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'Frontier Tech Dashboard',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: isMobile ? 28 : 36,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hub_outlined,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'OPEN SOURCE',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Optimizing healthcare resilience for climate-vulnerable pediatric populations.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 14 : 16,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppColors.textDeep.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 32),
                statsAsync.when(
                  data: (stats) => HospitalStatsGrid(
                    isMobile: isMobile,
                    patientCount: stats['patients']!,
                    doctorCount: stats['doctors']!,
                    todayCount: stats['today']!,
                    isDark: isDark,
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Text('Error: $e'),
                ),
                const SizedBox(height: 32),
                _FrontierTechArea4(isMobile: isMobile, isDark: isDark),
                const SizedBox(height: 32),
                HospitalAnalytics(
                    isMobile: isMobile,
                    hospitalId: user?.uid ?? '',
                    isDark: isDark),
                const SizedBox(height: 32),
                _buildUpcomingAppointmentsHeader(context, isMobile, isDark),
              ],
            ),
          ),
        ),
        appointmentsAsync.when(
          data: (appointments) {
            if (appointments.isEmpty) {
              return SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Text('No upcoming appointments',
                        style: TextStyle(
                            color: isDark
                                ? AppColors.textLight.withValues(alpha: 0.5)
                                : AppColors.secondary)),
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16.0 : 24.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final appointment = appointments[index];
                    return AppointmentCard(
                      appointment: appointment,
                      isMobile: isMobile,
                      docId: appointment['id'],
                      isDark: isDark,
                    );
                  },
                  childCount: appointments.length,
                ),
              ),
            );
          },
          loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator())),
          error: (e, st) => SliverToBoxAdapter(child: Text('Error: $e')),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildUpcomingAppointmentsHeader(
      BuildContext context, bool isMobile, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Upcoming Appointments',
            style: GoogleFonts.playfairDisplay(
              fontSize: isMobile ? 22 : 26,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textDeep,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AllAppointmentsScreen()),
              );
            },
            child: Text(
              'View All',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EarlyWarningSection extends ConsumerWidget {
  final String hospitalId;
  final bool isMobile;
  final bool isDark;

  const _EarlyWarningSection({
    required this.hospitalId,
    required this.isMobile,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_rounded,
                  color: AppColors.error, size: 24),
              const SizedBox(width: 12),
              Text(
                'Area 2: Early Warning System',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textDeep,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'REAL-TIME',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Risk communication active for local schools and community clinics. Identifying real-time protective measures.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: isDark
                  ? Colors.white70
                  : AppColors.textDeep.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrontierTechArea4 extends StatelessWidget {
  final bool isMobile;
  final bool isDark;

  const _FrontierTechArea4({required this.isMobile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.05),
              Colors.transparent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Spacer());
  }

  Widget _buildConnectivityStatus(String label, bool active) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppColors.success : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.success : Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _HospitalScheduleManagement extends ConsumerStatefulWidget {
  @override
  ConsumerState<_HospitalScheduleManagement> createState() =>
      _HospitalScheduleManagementState();
}

class _HospitalScheduleManagementState
    extends ConsumerState<_HospitalScheduleManagement> {
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  List<String> _selectedDays = [];

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule Management',
            style: GoogleFonts.playfairDisplay(
              fontSize: isMobile ? 28 : 32,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textDeep,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set available time slots for appointments',
            style: GoogleFonts.plusJakartaSans(
                color: isDark
                    ? Colors.white60
                    : AppColors.textDeep.withValues(alpha: 0.6),
                fontSize: isMobile ? 14 : 16),
          ),
          const SizedBox(height: 32),
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.background,
              borderRadius: BorderRadius.circular(24),
              boxShadow: isDark ? [] : AppColors.softShadow,
              border:
                  Border.all(color: isDark ? Colors.white10 : AppColors.shelf),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Working Days',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textDeep)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _days.map((day) {
                    final isSelected = _selectedDays.contains(day);
                    return FilterChip(
                      label: Text(day,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: isMobile ? 12 : 14,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white70
                                      : AppColors.textDeep))),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      checkmarkColor: Colors.white,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : AppColors.background,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedDays.add(day);
                          } else {
                            _selectedDays.remove(day);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                // Responsive Start/End Time layout
                Flex(
                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: isMobile ? 0 : 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Start Time',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textDeep)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _startTimeController,
                            style: GoogleFonts.plusJakartaSans(
                                color:
                                    isDark ? Colors.white : AppColors.textDeep),
                            decoration: InputDecoration(
                              hintText: '08:00 AM',
                              hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.white24
                                      : AppColors.textDeep
                                          .withValues(alpha: 0.3)),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : AppColors.background,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white10
                                          : AppColors.shelf)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white10
                                          : AppColors.shelf)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                        width: isMobile ? 0 : 16, height: isMobile ? 16 : 0),
                    Expanded(
                      flex: isMobile ? 0 : 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('End Time',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textDeep)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _endTimeController,
                            style: GoogleFonts.plusJakartaSans(
                                color:
                                    isDark ? Colors.white : AppColors.textDeep),
                            decoration: InputDecoration(
                              hintText: '05:00 PM',
                              hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.white24
                                      : AppColors.textDeep
                                          .withValues(alpha: 0.3)),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : AppColors.background,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white10
                                          : AppColors.shelf)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white10
                                          : AppColors.shelf)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (user != null) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .update({
                          'schedule': {
                            'days': _selectedDays,
                            'startTime': _startTimeController.text,
                            'endTime': _endTimeController.text,
                          }
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Schedule updated successfully!')));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Save Schedule',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100), // Extra space for mobile bottom nav
        ],
      ),
    );
  }
}

class _HospitalStaffManagement extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? AppColors.textLight : AppColors.textDeep;

    final staffAsync = ref.watch(staffProvider(null));
    final requestsAsync = ref.watch(staffRequestsProvider(null));
    final invitationsAsync = ref.watch(sentInvitationsProvider(null));

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Text(
                      'Staff Management',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: isMobile ? 28 : 32,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textDeep,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddDoctorDialog(
                          context, user?.uid, isDark, textColor),
                      icon: const Icon(Icons.add),
                      label: Text('Add Doctor',
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          staffAsync.when(
            data: (doctors) {
              if (doctors.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64,
                            color: AppColors.textDeep.withValues(alpha: 0.1)),
                        const SizedBox(height: 16),
                        Text(
                          'No doctors registered yet',
                          style: GoogleFonts.plusJakartaSans(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : AppColors.textDeep.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final doctor = doctors[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isDark ? [] : AppColors.softShadow,
                        border: Border.all(
                            color: isDark ? Colors.white10 : AppColors.shelf),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          backgroundImage: NetworkImage(doctor[
                                  'profileImageUrl'] ??
                              'https://i.pravatar.cc/150?u=${doctor['name']}'),
                        ),
                        title: Text(
                          doctor['name'] ?? 'Dr. Name',
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              color:
                                  isDark ? Colors.white : AppColors.textDeep),
                        ),
                        subtitle: Text(doctor['speciality'] ?? 'General',
                            style: GoogleFonts.plusJakartaSans(
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.textDeep
                                        .withValues(alpha: 0.6))),
                        trailing: IconButton(
                          icon: const Icon(Icons.person_remove_outlined,
                              color: AppColors.primary),
                          onPressed: () => _removeDoctor(doctor['id']),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn()
                        .slideX(begin: 0.1, delay: (index * 50).ms);
                  },
                  childCount: doctors.length,
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator())),
            error: (e, st) => SliverToBoxAdapter(child: Text('Error: $e')),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Text(
                  'Pending Applications',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textDeep,
                  ),
                ),
                const SizedBox(height: 16),
                requestsAsync.when(
                  data: (requests) {
                    if (requests.isEmpty) {
                      return Text('No pending applications',
                          style: GoogleFonts.plusJakartaSans(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : AppColors.textDeep.withValues(alpha: 0.5)));
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final req = requests[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceDark
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color:
                                    isDark ? Colors.white10 : AppColors.shelf),
                          ),
                          child: ListTile(
                            title: Text(req['fromName'],
                                style: GoogleFonts.plusJakartaSans(
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textDeep,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text('Requested to join staff',
                                style: GoogleFonts.plusJakartaSans(
                                    color: isDark
                                        ? Colors.white70
                                        : AppColors.textDeep
                                            .withValues(alpha: 0.6))),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: AppColors.primary),
                                  onPressed: () =>
                                      _handleJoinRequest(req['id'], 'rejected'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check,
                                      color: AppColors.success),
                                  onPressed: () => _handleJoinRequest(
                                      req['id'], 'accepted',
                                      doctorId: req['fromId'],
                                      hospitalId: user?.uid),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, st) => Text('Error: $e'),
                ),
                const SizedBox(height: 32),
                Text(
                  'Invitations Sent',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textDeep,
                  ),
                ),
                const SizedBox(height: 16),
                invitationsAsync.when(
                  data: (invitations) {
                    if (invitations.isEmpty) {
                      return Text('No pending invitations sent',
                          style: GoogleFonts.plusJakartaSans(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : AppColors.textDeep.withValues(alpha: 0.5)));
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: invitations.length,
                      itemBuilder: (context, index) {
                        final req = invitations[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceDark
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color:
                                    isDark ? Colors.white10 : AppColors.shelf),
                          ),
                          child: ListTile(
                            title: Text(req['toName'],
                                style: GoogleFonts.plusJakartaSans(
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textDeep,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text('Invited to join staff',
                                style: GoogleFonts.plusJakartaSans(
                                    color: isDark
                                        ? Colors.white70
                                        : AppColors.textDeep
                                            .withValues(alpha: 0.6))),
                            trailing: const Icon(Icons.hourglass_empty,
                                color: AppColors.accent),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, st) => Text('Error: $e'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeDoctor(String doctorId) async {
    await FirebaseFirestore.instance.collection('users').doc(doctorId).update({
      'hospitalId': FieldValue.delete(),
    });
  }

  Future<void> _handleJoinRequest(String requestId, String status,
      {String? doctorId, String? hospitalId}) async {
    await FirebaseFirestore.instance
        .collection('hospital_requests')
        .doc(requestId)
        .update({
      'status': status,
    });
    if (status == 'accepted' && doctorId != null && hospitalId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(doctorId)
          .update({
        'hospitalId': hospitalId,
      });
    }
  }

  void _showAddDoctorDialog(
      BuildContext context, String? hospitalId, bool isDark, Color textColor) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        title: Text('Invite Doctor',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Enter the registered email of the doctor to send an invitation.',
                style: TextStyle(
                    color: isDark
                        ? AppColors.textLight.withValues(alpha: 0.8)
                        : AppColors.textDeep)),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Doctor Email',
                labelStyle: TextStyle(
                    color: isDark
                        ? AppColors.textLight.withValues(alpha: 0.5)
                        : AppColors.secondary),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12),
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(
                      color: isDark
                          ? AppColors.textLight.withValues(alpha: 0.7)
                          : AppColors.secondary))),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isNotEmpty && hospitalId != null) {
                final doctorSnapshot = await FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'doctor')
                    .where('email', isEqualTo: emailController.text.trim())
                    .get();

                if (doctorSnapshot.docs.isNotEmpty) {
                  final doctorDoc = doctorSnapshot.docs.first;
                  final hospitalDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(hospitalId)
                      .get();

                  await FirebaseFirestore.instance
                      .collection('hospital_requests')
                      .add({
                    'fromId': hospitalId,
                    'fromName': hospitalDoc.data()!['name'] ?? 'Hospital',
                    'fromRole': 'hospital',
                    'toId': doctorDoc.id,
                    'toName': doctorDoc.data()?['name'] ?? 'Doctor',
                    'toRole': 'doctor',
                    'status': 'pending',
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Invitation sent to doctor!')));
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Doctor not found or not registered as a doctor role.')));
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Send Invitation',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _HospitalProfile extends ConsumerStatefulWidget {
  const _HospitalProfile();

  @override
  ConsumerState<_HospitalProfile> createState() => _HospitalProfileState();
}

class _HospitalProfileState extends ConsumerState<_HospitalProfile> {
  bool _isEditing = false;
  bool _isLoading = false;
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _specialityController;
  late TextEditingController _descriptionController;
  late TextEditingController _latController;
  late TextEditingController _lngController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _specialityController = TextEditingController();
    _descriptionController = TextEditingController();
    _latController = TextEditingController();
    _lngController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _specialityController.dispose();
    _descriptionController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _updateProfileImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Profile Picture',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'Crop Profile Picture'),
      ],
    );

    if (croppedFile != null) {
      setState(() => _isLoading = true);
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;

        final refStorage = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('$uid.jpg');
        await refStorage.putFile(File(croppedFile.path));
        final url = await refStorage.getDownloadURL();

        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'profileImageUrl': url,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile picture updated!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfileChanges() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'speciality': _specialityController.text.trim(),
        'description': _descriptionController.text.trim(),
        'latitude': double.tryParse(_latController.text) ?? 0.0,
        'longitude': double.tryParse(_lngController.text) ?? 0.0,
      });
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? AppColors.textLight : AppColors.textDeep;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.data() as Map<String, dynamic>;

        if (!_isEditing) {
          _nameController.text = data['name'] ?? '';
          _addressController.text = data['address'] ?? '';
          _specialityController.text = data['speciality'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _latController.text = (data['latitude'] ?? '').toString();
          _lngController.text = (data['longitude'] ?? '').toString();
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Stack(
                children: [
                  CircleAvatar(
                    radius: isMobile ? 50 : 60,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: NetworkImage(data['profileImageUrl'] ??
                        'https://images.unsplash.com/photo-1586773860418-d3b9a8ec81a2?w=400'),
                  ),
                  if (_isLoading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle),
                        child: const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white)),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _updateProfileImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                            color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isEditing)
                TextField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDeep),
                  decoration: InputDecoration(
                      hintText: 'Hospital Name',
                      hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white24
                              : AppColors.textDeep.withValues(alpha: 0.3)),
                      border: InputBorder.none),
                )
              else
                Text(
                  data['name'] ?? 'Hospital Name',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDeep),
                  textAlign: TextAlign.center,
                ),
              Text(
                data['email'] ?? '',
                style: GoogleFonts.plusJakartaSans(
                    color: isDark
                        ? Colors.white60
                        : AppColors.textDeep.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.background,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: isDark ? [] : AppColors.softShadow,
                  border: Border.all(
                      color: isDark ? Colors.white10 : AppColors.shelf),
                ),
                child: Column(
                  children: [
                    _buildEditableRow(
                        Icons.medical_services_outlined,
                        'Speciality/Type',
                        _specialityController,
                        _isEditing,
                        isDark,
                        textColor),
                    const Divider(height: 32, color: AppColors.shelf),
                    _buildEditableRow(Icons.location_on_outlined, 'Address',
                        _addressController, _isEditing, isDark, textColor),
                    const Divider(height: 32, color: AppColors.shelf),
                    Row(
                      children: [
                        Expanded(
                            child: _buildEditableRow(
                                Icons.map_outlined,
                                'Latitude',
                                _latController,
                                _isEditing,
                                isDark,
                                textColor)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _buildEditableRow(
                                Icons.map_outlined,
                                'Longitude',
                                _latController,
                                _isEditing,
                                isDark,
                                textColor)),
                      ],
                    ),
                    const Divider(height: 32, color: AppColors.shelf),
                    _buildEditableRow(Icons.description_outlined, 'Description',
                        _descriptionController, _isEditing, isDark, textColor,
                        maxLines: 3),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (_isEditing)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _isEditing = false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: AppColors.textDeep,
                          side: const BorderSide(color: AppColors.shelf),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text('Cancel',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfileChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text('Save Changes',
                                style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              else
                _buildProfileOption(Icons.edit, 'Edit Profile', () {
                  setState(() => _isEditing = true);
                }, isDark, textColor),
              if (!_isEditing) ...[
                _buildProfileOption(
                  Icons.notifications_outlined,
                  'Notifications',
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen())),
                  isDark,
                  textColor,
                  badgeCount: ref.watch(unreadNotificationsCountProvider),
                ),
                _buildProfileOption(
                    Icons.security, 'Security', () {}, isDark, textColor),
                _buildProfileOption(Icons.help_outline, 'Help & Support', () {},
                    isDark, textColor),
                const Divider(height: 40, color: AppColors.shelf),
                ListTile(
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.logout, color: AppColors.primary),
                  ),
                  title: Text('Logout',
                      style: GoogleFonts.plusJakartaSans(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ],
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditableRow(
      IconData icon,
      String label,
      TextEditingController controller,
      bool isEditing,
      bool isDark,
      Color textColor,
      {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.plusJakartaSans(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : AppColors.textDeep.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              if (isEditing)
                TextField(
                  controller: controller,
                  maxLines: maxLines,
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDeep),
                  decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 4)),
                )
              else
                Text(
                    controller.text.isEmpty ? 'Not specified' : controller.text,
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textDeep)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileOption(IconData icon, String title, VoidCallback onTap,
      bool isDark, Color textColor,
      {int badgeCount = 0}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Row(
        children: [
          Text(title,
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textDeep)),
          if (badgeCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeCount.toString(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      trailing: Icon(Icons.chevron_right,
          color: isDark
              ? Colors.white24
              : AppColors.textDeep.withValues(alpha: 0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
