import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_colors.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Decorative Orbs (Matching Register Screen style)
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scale(
                  duration: 5.seconds,
                  begin: const Offset(1, 1),
                  end: const Offset(1.2, 1.2),
                  curve: Curves.easeInOut,
                )
                .then()
                .scale(begin: const Offset(1.2, 1.2), end: const Offset(1, 1)),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 60.0 : 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),
                  Text(
                    'UNICEF CLIMATE VENTURE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 2,
                    ),
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),
                  const SizedBox(height: 16),
                  Text(
                    'Medicore\nChild Care',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: isTablet ? 64 : 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDeep,
                      height: 1.1,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 800.ms)
                      .slideY(begin: 0.2),
                  const SizedBox(height: 24),
                  Text(
                    'Advancing pediatric healthcare resilience through frontier tech and climate intelligence.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      color: AppColors.textDeep.withValues(alpha: 0.7),
                      height: 1.6,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 800.ms)
                      .slideY(begin: 0.2),
                  const Spacer(flex: 3),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: () => context.push('/register'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: const Text('Begin Registration',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 600.ms)
                      .scale(begin: const Offset(0.9, 0.9)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: OutlinedButton(
                      onPressed: () => context.push('/login'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        foregroundColor: AppColors.primary,
                      ),
                      child: const Text('Sign In',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 800.ms)
                      .scale(begin: const Offset(0.9, 0.9)),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
