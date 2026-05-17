import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_app/core/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class AIProcessingOverlay extends StatelessWidget {
  final String message;
  const AIProcessingOverlay({super.key, this.message = 'Medicore AI processing...'});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const SizedBox(
                        height: 80,
                        width: 80,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      ),
                      const Icon(Icons.auto_awesome, color: AppColors.accent, size: 30)
                          .animate(onPlay: (controller) => controller.repeat())
                          .shimmer(duration: 2.seconds)
                          .scale(duration: 1.seconds, curve: Curves.easeInOut),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    message,
                    style: GoogleFonts.plusJakartaSans(
                      color: isDark ? Colors.white : AppColors.textDeep,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Powered by Gemini 2.0 Flash',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate().scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack).fadeIn(),
      ),
    );
  }
}
