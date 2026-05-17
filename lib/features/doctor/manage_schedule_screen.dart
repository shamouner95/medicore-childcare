import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';

class ManageScheduleScreen extends StatefulWidget {
  const ManageScheduleScreen({super.key});

  @override
  State<ManageScheduleScreen> createState() => _ManageScheduleScreenState();
}

class _ManageScheduleScreenState extends State<ManageScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  final Set<String> _availableSlots = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .doc(dateStr)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final slots = List<String>.from(data['slots'] ?? []);
        setState(() {
          _availableSlots.clear();
          _availableSlots.addAll(slots);
          _isLoading = false;
        });
      } else {
        setState(() {
          _availableSlots.clear();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSchedule() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .doc(dateStr)
          .set({
        'slots': _availableSlots.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule updated successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating schedule: $e'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: Stack(
        children: [
          _buildBackdropDecor(isDark),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isTablet ? 800 : double.infinity),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildModernAppBar(context, isDark),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isTablet ? 40 : 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildHeader(isDark),
                          const SizedBox(height: 32),
                          _buildDateSelector(isDark),
                          const SizedBox(height: 40),
                          _buildSectionHeader('AVAILABILITY SLOTS', isDark),
                          const SizedBox(height: 20),
                          if (_isLoading)
                            _buildLoadingState()
                          else
                            _buildTimeSlotsGrid(isDark, isTablet),
                          const SizedBox(height: 40),
                          _buildSectionHeader('UPCOMING PREVIEW', isDark),
                          const SizedBox(height: 20),
                          _buildAppointmentPreview(isDark),
                          const SizedBox(height: 250),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomAction(isDark, isTablet),
        ],
      ),
    );
  }

  Widget _buildBackdropDecor(bool isDark) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: isDark ? 0.03 : 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: isDark ? 0.03 : 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, 
              color: isDark ? Colors.white : AppColors.textDeep, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton(
            icon: Icon(Icons.tune_rounded, color: isDark ? Colors.white : AppColors.textDeep),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRACTICE MANAGEMENT',
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.primary,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Manage your\nSchedule.',
          style: GoogleFonts.plusJakartaSans(
            color: isDark ? Colors.white : AppColors.textDeep,
            fontSize: 40,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -1,
          ),
        ),
      ],
    ).animate().fadeIn().slideX(begin: -0.1);
  }

  Widget _buildDateSelector(bool isDark) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: 14,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, _selectedDate);

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _loadSchedule();
            },
            child: Container(
              width: 75,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                gradient: isSelected ? AppColors.premiumGradient : null,
                color: isSelected ? null : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(24),
                boxShadow: isSelected
                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))]
                  : (isDark ? [] : AppColors.softShadow),
                border: Border.all(
                  color: isSelected ? Colors.transparent : (isDark ? Colors.white10 : AppColors.primary.withValues(alpha: 0.05)),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date).toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: isSelected ? Colors.white70 : AppColors.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    date.day.toString(),
                    style: GoogleFonts.plusJakartaSans(
                      color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.textDeep),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1);
        },
      ),
    );
  }

  Widget _buildTimeSlotsGrid(bool isDark, bool isTablet) {
    final List<String> slots = [
      '09:00 AM', '10:00 AM', '11:00 AM', '12:00 PM',
      '02:00 PM', '03:00 PM', '04:00 PM', '05:00 PM', '06:00 PM'
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 3 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.5,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isAvailable = _availableSlots.contains(slot);
        
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isAvailable) {
                _availableSlots.remove(slot);
              } else {
                _availableSlots.add(slot);
              }
            });
          },
          child: AnimatedContainer(
            duration: 200.ms,
            decoration: BoxDecoration(
              gradient: isAvailable ? AppColors.accentGradient : null,
              color: isAvailable ? null : (isDark ? AppColors.surfaceDark : Colors.white),
              borderRadius: BorderRadius.circular(20),
              boxShadow: isAvailable 
                ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))]
                : (isDark ? [] : AppColors.softShadow),
              border: Border.all(
                color: isAvailable ? Colors.transparent : (isDark ? Colors.white10 : AppColors.primary.withValues(alpha: 0.05)),
                width: 1,
              ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isAvailable ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                    size: 16,
                    color: isAvailable ? Colors.white : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    slot,
                    style: GoogleFonts.plusJakartaSans(
                      color: isAvailable ? Colors.white : (isDark ? Colors.white70 : AppColors.textDeep),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(delay: (index * 30).ms).scale(begin: const Offset(0.95, 0.95));
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text('Syncing with cloud...', style: GoogleFonts.plusJakartaSans(color: AppColors.secondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: isDark ? Colors.white38 : AppColors.secondary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: isDark ? Colors.white10 : AppColors.primary.withValues(alpha: 0.05))),
      ],
    );
  }

  Widget _buildAppointmentPreview(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.event_note_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Insights',
                  style: GoogleFonts.plusJakartaSans(
                    color: isDark ? Colors.white : AppColors.textDeep,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_availableSlots.length} active slots for ${DateFormat('MMM dd').format(_selectedDate)}',
                  style: GoogleFonts.plusJakartaSans(
                    color: isDark ? Colors.white60 : AppColors.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white24 : Colors.black26, size: 16),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2);
  }

  Widget _buildBottomAction(bool isDark, bool isTablet) {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, isTablet ? 40 : 32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (isDark ? AppColors.backgroundDark : Colors.white).withValues(alpha: 0),
              isDark ? AppColors.backgroundDark : Colors.white,
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTablet ? 800 : double.infinity),
            child: Container(
              height: 64,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _saveSchedule,
                  borderRadius: BorderRadius.circular(24),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          'Update Daily Availability',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: 1, delay: 800.ms);
  }
}

