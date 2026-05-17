import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hospital_app/core/services/health_id_service.dart';
import 'package:hospital_app/auth_repository.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

import '../../core/widgets/glass_card.dart';

class HealthIDScreen extends ConsumerWidget {
  const HealthIDScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textDeep, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          
          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final String name = userData['name'] ?? 'User';
          final String uniqueId = userData['uniqueId'] ?? 'ID-PENDING';
          final String profileImageUrl = userData['profileImageUrl'] ?? 'https://ui-avatars.com/api/?name=${name.replaceAll(' ', '+')}';
          
          final String qrData = HealthIDService.generateQRData(userData);

          return Stack(
            children: [
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.05),
                  ),
                ),
              ),
              
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 80),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildProfileHeader(name, uniqueId, profileImageUrl, isDark),
                      const SizedBox(height: 48),
                      _buildQRCard(qrData, isDark),
                      const SizedBox(height: 48),
                      _buildOfflineContinuityCard(isDark),
                      const SizedBox(height: 16),
                      _buildInfoCard(isDark),
                      const SizedBox(height: 40),
                      _buildActionButtons(isDark),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildProfileHeader(String name, String uniqueId, String imageUrl, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
          ),
          child: CircleAvatar(
            radius: 40,
            backgroundImage: NetworkImage(imageUrl),
          ),
        ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 16),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textDeep,
          ),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
        Text(
          'Universal Health ID: #$uniqueId',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.primary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildQRCard(String userId, bool isDark) {
    return GlassCard(
      borderRadius: 40,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.shelf),
            ),
            child: QrImageView(
              data: userId,
              version: QrVersions.auto,
              size: 200.0,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.textDeep,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.textDeep,
              ),
            ),
          ).animate().scale(delay: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            'SCAN FOR ACCESS',
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? Colors.white.withValues(alpha: 0.5) : AppColors.textDeep.withValues(alpha: 0.3),
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildOfflineContinuityCard(bool isDark) {
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.signal_wifi_off_rounded, color: AppColors.accent, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Climate Resilience: Offline Sync',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppColors.textDeep,
                      ),
                    ),
                    Text(
                      'This QR Code contains encrypted pediatric history for service continuity in low-connectivity zones.',
                      style: GoogleFonts.plusJakartaSans(
                        color: isDark ? Colors.white70 : AppColors.textDeep.withValues(alpha: 0.7),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1);
  }

  Widget _buildInfoCard(bool isDark) {
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.security_rounded, color: AppColors.success, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Your health data is encrypted and shared only with authorized medical professionals.',
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? Colors.white70 : AppColors.textDeep.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1);
  }

  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildSecondaryButton(Icons.save_alt_rounded, 'Save to Phone', isDark),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPrimaryButton(Icons.share_rounded, 'Share ID', isDark),
        ),
      ],
    ).animate().fadeIn(delay: 1000.ms);
  }

  Widget _buildPrimaryButton(IconData icon, String label, bool isDark) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.share_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(IconData icon, String label, bool isDark) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.textDeep.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.textDeep.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isDark ? Colors.white : AppColors.textDeep, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: isDark ? Colors.white : AppColors.textDeep,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppShadows {
  static List<BoxShadow> premiumShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.4),
      blurRadius: 30,
      offset: const Offset(0, 15),
    ),
  ];
}
