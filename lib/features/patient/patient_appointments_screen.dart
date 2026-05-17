import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_app/core/theme/app_colors.dart';
import 'package:hospital_app/providers/appointment_provider.dart';
import 'package:hospital_app/models/appointment_model.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import '../../core/widgets/glass_card.dart';

class PatientAppointmentsScreen extends ConsumerWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(appointmentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverHeader(context, isDark),
          if (appointments.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 64, color: AppColors.secondary.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'No appointments found',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.secondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final appointment = appointments[index];
                    return _buildAppointmentCard(context, appointment, isDark)
                        .animate()
                        .fadeIn(delay: (index * 100).ms)
                        .slideY(begin: 0.1);
                  },
                  childCount: appointments.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textDeep),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
        title: Text(
          'My Appointments',
          style: GoogleFonts.plusJakartaSans(
            color: isDark ? Colors.white : AppColors.textDeep,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        background: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: (isDark ? AppColors.backgroundDark : AppColors.background).withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(BuildContext context, Appointment appointment, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GlassCard(
        borderRadius: 28,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusBadge(appointment.status),
                    Text(
                      appointment.appointmentDate,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(appointment.doctorId).get(),
                  builder: (context, snapshot) {
                    final docData = snapshot.data?.data() as Map<String, dynamic>?;
                    final doctorName = docData?['name'] ?? 'Doctor';
                    final specialty = docData?['speciality'] ?? 'Specialist';
                    final imageUrl = docData?['profileImageUrl'];

                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: imageUrl != null 
                            ? NetworkImage(imageUrl) 
                            : const NetworkImage('https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=200'),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctorName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : AppColors.textDeep,
                                ),
                              ),
                              Text(
                                specialty,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chat_bubble_rounded, color: AppColors.primary, size: 20),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 18, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Text(
                      appointment.appointmentTime,
                      style: GoogleFonts.plusJakartaSans(
                        color: isDark ? Colors.white70 : AppColors.textDeep,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (appointment.status == 'confirmed' || appointment.status == 'completed')
                      GestureDetector(
                        onTap: () => context.push('/health-journey', extra: {'appointmentId': appointment.id}),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppColors.premiumGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 8),
                              Text(
                                'Health Journey',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'confirmed':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'completed':
        color = AppColors.primary;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = AppColors.secondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
