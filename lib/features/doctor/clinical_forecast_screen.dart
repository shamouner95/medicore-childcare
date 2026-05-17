import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_app/core/services/gemini_ai_service.dart';
import 'package:hospital_app/core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hospital_app/providers/country_provider.dart';
import 'package:hospital_app/core/widgets/glass_card.dart';

class ClinicalForecastScreen extends ConsumerStatefulWidget {
  const ClinicalForecastScreen({super.key});

  @override
  ConsumerState<ClinicalForecastScreen> createState() => _ClinicalForecastScreenState();
}

class _ClinicalForecastScreenState extends ConsumerState<ClinicalForecastScreen> {
  final GeminiAIService _aiService = GeminiAIService();
  bool _isLoading = false;
  PracticeInsights? _insights;
  EpidemicInsight? _regionalTrends;
  ClimatePediatricSurge? _climateSurge;

  @override
  void initState() {
    super.initState();
    _loadForecast();
  }

  Future<void> _loadForecast() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final selectedCountry = ref.read(countryProvider);
      
      if (user == null) {
         setState(() => _isLoading = false);
         return;
      }

      // 1. Fetch Practice-Specific Data
      final appointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();

      final logs = appointments.docs.map((doc) => {
        'symptoms': doc.get('symptoms'),
        'status': doc.get('status'),
        'createdAt': (doc.get('createdAt') as Timestamp).toDate().toIso8601String(),
        'patientId': doc.get('patientId'),
        if (doc.data().containsKey('prescription')) 'prescription': doc.get('prescription'),
      }).toList();

      // 2. Fetch Regional Aggregated Symptom Data (using Collection Group)
      final regionalSymptomsQuery = await FirebaseFirestore.instance
          .collectionGroup('symptom_history')
          .where('country', isEqualTo: selectedCountry) // Filter by country for regional accuracy
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final regionalLogs = regionalSymptomsQuery.docs.map((doc) => {
        'symptoms': doc.get('symptoms'),
        'timestamp': (doc.get('timestamp') as Timestamp).toDate().toIso8601String(),
      }).toList();
      
      // Get AI Insights
      final insights = logs.isEmpty 
        ? PracticeInsights(
            efficiencyScore: "NEW",
            optimizationTips: ["Start booking appointments to see insights.", "Complete your doctor profile."],
            patientSatisfactionForecast: "Waiting for your first patients to provide analysis.",
            busyHourPredictions: ["Not enough data yet."]
          )
        : await _aiService.getPracticeManagementInsights(logs, country: selectedCountry);

      final trends = await _aiService.getEpidemicOutreach(regionalLogs, country: selectedCountry);
      
      final climateSurge = await _aiService.getClimatePediatricSurgeForecast(
        regionalSymptomTrends: regionalLogs,
        country: selectedCountry,
      );

      setState(() {
        _insights = insights;
        _regionalTrends = trends;
        _climateSurge = climateSurge;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading clinical forecast: $e');
      setState(() {
        _isLoading = false;
        // Fallback for demo or error state
        _insights = PracticeInsights(
          efficiencyScore: "!",
          optimizationTips: ["Ensure you have a stable internet connection.", "Database sync might be in progress."],
          patientSatisfactionForecast: "Unable to retrieve AI analysis at this time.",
          busyHourPredictions: ["Data sync error"]
        );
      });
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
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isTablet ? 800 : double.infinity),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(context),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(isTablet ? 40.0 : 24.0),
                      child: _isLoading 
                        ? _buildLoadingState()
                        : _buildContent(isDark, isTablet),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textDeep, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                ? [AppColors.backgroundDark, AppColors.backgroundDark]
                : [const Color(0xFFE0E7FF), AppColors.background],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Text(
                  'PRACTICE INTELLIGENCE',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'Clinical Forecast',
                  style: GoogleFonts.plusJakartaSans(
                    color: isDark ? Colors.white : AppColors.textDeep,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 48)
              .animate(onPlay: (c) => c.repeat())
              .rotate(duration: 2.seconds)
              .scale(begin: const Offset(0.8,0.8), end: const Offset(1.2, 1.2)),
            const SizedBox(height: 24),
            Text('Synthesizing Practice Data...', 
              style: GoogleFonts.plusJakartaSans(color: AppColors.secondary, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark, bool isTablet) {
    if (_insights == null) return const Center(child: Text('Failed to load insights'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEfficiencyScoreCard(isDark, isTablet),
        const SizedBox(height: 24),
        _buildClimatePediatricInsight(isDark, isTablet),
        const SizedBox(height: 24),
        if (_regionalTrends != null) ...[
          _buildRegionalForecastCard(isDark, isTablet),
          const SizedBox(height: 24),
        ],
        if (isTablet)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildForecastCard('Patient Satisfaction Forecast', _insights!.patientSatisfactionForecast, Icons.sentiment_very_satisfied_rounded, AppColors.secondary, isDark)),
              const SizedBox(width: 24),
              Expanded(child: _buildListCard('Predicted Busy Hours', _insights!.busyHourPredictions, Icons.access_time_filled_rounded, AppColors.primary, isDark)),
            ],
          )
        else ...[
          _buildForecastCard('Patient Satisfaction Forecast', _insights!.patientSatisfactionForecast, Icons.sentiment_very_satisfied_rounded, AppColors.secondary, isDark),
          const SizedBox(height: 24),
          _buildListCard('Predicted Busy Hours', _insights!.busyHourPredictions, Icons.access_time_filled_rounded, AppColors.primary, isDark),
        ],
        const SizedBox(height: 24),
        _buildListCard('Operational Optimization', _insights!.optimizationTips, Icons.tips_and_updates_rounded, AppColors.accent, isDark),
        const SizedBox(height: 100),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1);
  }

  Widget _buildClimatePediatricInsight(bool isDark, bool isTablet) {
    if (_climateSurge == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.child_care_rounded, color: AppColors.accent, size: 24),
              const SizedBox(width: 12),
              Text(
                'CLIMATE-PEDIATRIC WATCH',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: AppColors.accent,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _climateSurge!.riskLevel.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _climateSurge!.insight,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textDeep,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Recommendation: ${_climateSurge!.recommendation}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: isDark ? Colors.white70 : AppColors.textDeep.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          if (_climateSurge!.resourcePlanning.isNotEmpty) ...[
            const SizedBox(height: 16),
            ..._climateSurge!.resourcePlanning.map((plan) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? Colors.white60 : AppColors.textDeep),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildRegionalForecastCard(bool isDark, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
        boxShadow: isDark ? [] : AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.analytics_rounded, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 16),
              Text('REGIONAL HEALTH OUTLOOK', 
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5, color: AppColors.secondary)),
            ],
          ),
          const SizedBox(height: 20),
          Text(_regionalTrends!.status, 
            style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textDeep)),
          const SizedBox(height: 12),
          Text(_regionalTrends!.projection, 
            style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white70 : AppColors.textDeep.withValues(alpha: 0.7), fontSize: 15, height: 1.5)),
          const SizedBox(height: 24),
          Text('ADVISORY FOR DOCTORS', 
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.secondary)),
          const SizedBox(height: 12),
          ..._regionalTrends!.doctorRecommendations.map((rec) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                const Icon(Icons.shield_moon_rounded, color: AppColors.secondary, size: 16),
                const SizedBox(width: 12),
                Expanded(child: Text(rec, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.white60 : AppColors.secondary))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildEfficiencyScoreCard(bool isDark, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 40 : 28),
      decoration: BoxDecoration(
        gradient: AppColors.organicGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: isDark ? [] : AppColors.premiumShadow,
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CLINIC EFFICIENCY',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Current Grade',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: isTablet ? 32 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: isTablet ? 100 : 80,
            height: isTablet ? 100 : 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _insights!.efficiencyScore,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: isTablet ? 48 : 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCard(String title, String content, IconData icon, Color color, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ),
              ),
              const SizedBox(width: 16),
              Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : AppColors.textDeep)),
            ],
          ),
          const SizedBox(height: 20),
          Text(content, style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white70 : AppColors.textDeep.withValues(alpha: 0.7), fontSize: 15, height: 1.6, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildListCard(String title, List<String> items, IconData icon, Color color, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: isDark ? Colors.white : AppColors.textDeep)),
            ],
          ),
          const SizedBox(height: 20),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline_rounded, color: color, size: 18),
                const SizedBox(width: 12),
                Expanded(child: Text(item, style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white70 : AppColors.textDeep.withValues(alpha: 0.7), fontSize: 14, height: 1.4, fontWeight: FontWeight.w500))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
