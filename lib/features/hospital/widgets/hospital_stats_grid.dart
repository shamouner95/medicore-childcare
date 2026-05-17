import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';

class HospitalStatsGrid extends StatelessWidget {
  final bool isMobile;
  final String patientCount;
  final String doctorCount;
  final String todayCount;
  final bool isDark;

  const HospitalStatsGrid({
    super.key,
    required this.isMobile,
    required this.patientCount,
    required this.doctorCount,
    required this.todayCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildStatCard('Total Patients', patientCount, Icons.people_outline, AppColors.primary),
          const SizedBox(width: 16),
          _buildStatCard('Medical Staff', doctorCount, Icons.medication_outlined, AppColors.secondary),
          const SizedBox(width: 16),
          _buildStatCard("Today's Visits", todayCount, Icons.calendar_today_outlined, AppColors.accent),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      child: Container(
        width: isMobile ? 160 : 200,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textDeep,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.textDeep.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
