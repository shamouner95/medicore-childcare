import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_app/core/services/gemini_ai_service.dart';
import 'package:hospital_app/core/widgets/glass_card.dart';
import 'package:hospital_app/providers/country_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:hospital_app/core/widgets/ai_processing_overlay.dart';

class SymptomCheckerScreen extends ConsumerStatefulWidget {
  const SymptomCheckerScreen({super.key});

  @override
  ConsumerState<SymptomCheckerScreen> createState() => _SymptomCheckerScreenState();
}

class _SymptomCheckerScreenState extends ConsumerState<SymptomCheckerScreen> {
  final _controller = TextEditingController();
  final _service = GeminiAIService();
  final _picker = ImagePicker();
  bool _isLoading = false;
  SymptomAnalysis? _analysis;
  File? _selectedImage;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) setState(() => _selectedImage = File(image.path));
  }

  void _analyze() async {
    if (_controller.text.isEmpty && _selectedImage == null) return;
    
    final selectedCountry = ref.read(countryProvider);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AIProcessingOverlay(message: 'Gemini 2.0 is analyzing for $selectedCountry...'),
    );

    try {
      // 1. Fetch Environmental Indicators (Health Worker data)
      final indicatorSnapshot = await FirebaseFirestore.instance
          .collection('environmental_indicators')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      final indicators = indicatorSnapshot.docs.map((doc) => {
        'type': doc['type'],
        'description': doc['description'],
      }).toList();

      final imageBytes = _selectedImage != null ? await _selectedImage!.readAsBytes() : null;
      
      // We'll update GeminiAIService to accept indicators if needed, 
      // but for now, we can append them to the symptoms query to provide context.
      String enhancedQuery = _controller.text;
      if (indicators.isNotEmpty) {
        enhancedQuery += "\n\nLocal Field Context: ${indicators.map((i) => "${i['type']}: ${i['description']}").join(", ")}";
      }

      final result = await _service.analyzeSymptoms(
        enhancedQuery,
        imageBytes: imageBytes,
        country: selectedCountry,
      );
      
      if (!mounted) return;
      Navigator.pop(context); // Close overlay
      
      setState(() => _analysis = result);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('symptom_history').add({
          'symptoms': _controller.text,
          'analysis': {
            'summary': result.summary,
            'urgency': result.urgency,
            'advice': result.advice,
            'recommendedDepartment': result.recommendedDepartment,
          },
          'timestamp': FieldValue.serverTimestamp(),
          'hasImage': _selectedImage != null,
          'country': selectedCountry, // Added country field for regional analysis
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close overlay
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
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
                          _buildDescription(isDark),
                          const SizedBox(height: 32),
                          _buildInputGlass(isDark),
                          if (_analysis != null) _buildAnalysisResults(isDark, isTablet),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_analysis == null) _buildBottomBar(isDark, isTablet),
        ],
      ),
    );
  }

  Widget _buildBackdropDecor(bool isDark) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -50,
            left: -50,
            child: Container(width: 300, height: 300, decoration: BoxDecoration(color: (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.05), shape: BoxShape.circle)),
          ),
          Positioned(
            bottom: 200,
            right: -100,
            child: Container(width: 400, height: 400, decoration: BoxDecoration(color: (isDark ? Colors.white : AppColors.accent).withValues(alpha: 0.05), shape: BoxShape.circle)),
          ),
        ],
      ),
    );
  }

  Widget _buildModernAppBar(BuildContext context, bool isDark) {
    final selectedCountry = ref.watch(countryProvider);
    final countries = ref.watch(availableCountriesProvider);

    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textDeep, size: 16),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: (isDark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.1)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedCountry,
            isDense: true,
            dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
            items: countries.map((String country) {
              return DropdownMenuItem<String>(
                value: country,
                child: Text(country, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textDeep)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) ref.read(countryProvider.notifier).setCountry(value);
            },
          ),
        ),
      ),
      actions: [
        IconButton(icon: Icon(Icons.history_rounded, color: isDark ? Colors.white : AppColors.textDeep), onPressed: () {}),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildDescription(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SYMPTOM ANALYZER', style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 12),
        Text('Describe how\nyou feel.', style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white : AppColors.textDeep, fontSize: 40, fontWeight: FontWeight.w800, height: 1.1)),
      ],
    ).animate().fadeIn().slideX(begin: -0.1);
  }

  Widget _buildInputGlass(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 40,
      child: Column(
        children: [
          TextField(
            controller: _controller,
            maxLines: 6,
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? Colors.white : AppColors.textDeep,
              fontSize: 18,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Sharp chest pain after exercise...',
              hintStyle: GoogleFonts.plusJakartaSans(
                color: AppColors.secondary,
                fontSize: 18,
              ),
              border: InputBorder.none,
            ),
          ),
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.file(
                      _selectedImage!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: const CircleAvatar(
                        backgroundColor: Colors.black26,
                        child: Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildInputTool(Icons.add_a_photo_rounded, 'Photo', _pickImage, isDark),
              const SizedBox(width: 12),
              _buildInputTool(Icons.mic_none_rounded, 'Voice', () {}, isDark),
            ],
          ),
        ],
      ),
    ).animate().scale(delay: 200.ms);
  }

  Widget _buildInputTool(IconData icon, String label, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.background, 
          borderRadius: BorderRadius.circular(16)
        ),
        child: Row(children: [Icon(icon, size: 18, color: AppColors.primary), const SizedBox(width: 8), Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white70 : AppColors.textDeep))]),
      ),
    );
  }

  Widget _buildAnalysisResults(bool isDark, bool isTablet) {
    final urgency = _analysis!.urgency;
    final isCritical = urgency.toLowerCase().contains('high') || urgency.toLowerCase().contains('emergency');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('AI INSIGHTS', style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white : AppColors.textDeep, fontSize: 16, fontWeight: FontWeight.w900)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: (isCritical ? AppColors.accent : AppColors.secondary).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(100)),
              child: Text(urgency.toUpperCase(), style: TextStyle(color: isCritical ? AppColors.accent : AppColors.secondary, fontWeight: FontWeight.w900, fontSize: 10)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        GlassCard(
          padding: EdgeInsets.all(isTablet ? 40 : 32),
          borderRadius: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _analysis!.summary,
                style: GoogleFonts.plusJakartaSans(
                  color: isDark ? Colors.white70 : AppColors.textDeep,
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'RECOVERY STEPS',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              ..._analysis!.advice.map((step) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(step,
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : AppColors.textDeep,
                                    fontSize: 14))),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 72,
                child: ElevatedButton(
                  onPressed: () => context.push('/book', extra: {
                    'symptoms': _controller.text,
                    'specialty': _analysis?.recommendedDepartment,
                  }),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                  child: Text(
                    'BOOK SPECIALIST', 
                    style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 13)
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 72,
                child: OutlinedButton(
                  onPressed: () => context.push('/map', extra: {
                    'symptoms': _controller.text,
                  }),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: Text(
                    'FIND NEARBY CARE', 
                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, color: isDark ? Colors.white : AppColors.textDeep, fontSize: 13)
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildBottomBar(bool isDark, bool isTablet) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isTablet ? 800 : double.infinity),
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, isTablet ? 48 : 40),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
              border: Border.all(color: (isDark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.05)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 40, offset: const Offset(0, -10))],
            ),
            child: SizedBox(
              height: 72,
              child: ElevatedButton(
                onPressed: _analyze,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome_rounded),
                    const SizedBox(width: 12),
                    Text('START AI ANALYSIS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
