import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final bool isMobile;
  final String docId;
  final bool isDark;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.isMobile,
    required this.docId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.shelf),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_outline, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment['patientName'] ?? 'Unknown Patient',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textDeep,
                  ),
                ),
                Text(
                  '${appointment['appointmentDate']} • ${appointment['appointmentTime']}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.textDeep.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          _buildStatusBadge(appointment['status'] ?? 'pending'),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'accepted':
        color = AppColors.success;
        break;
      case 'pending':
        color = AppColors.accent;
        break;
      default:
        color = AppColors.textDeep.withValues(alpha: 0.4);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
