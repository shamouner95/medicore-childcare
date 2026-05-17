import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_app/core/services/gemini_ai_service.dart';
import 'package:hospital_app/core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hospital_app/core/widgets/glass_card.dart';
import 'package:hospital_app/providers/country_provider.dart';

class AIInsightsScreen extends ConsumerStatefulWidget {
  const AIInsightsScreen({super.key});

  @override
  ConsumerState<AIInsightsScreen> createState() => _AIInsightsScreenState();
}

class _AIInsightsScreenState extends ConsumerState<AIInsightsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GeminiAIService _aiService = GeminiAIService();
  
  bool _isLoadingTrend = false;
  bool _isLoadingLifestyle = false;
  HealthTrendAnalysis? _trend;
  LifestylePlan? _lifestyle;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStoredData().then((exists) {
      if (!exists) _loadData();
    });
  }

  Future<bool> _loadStoredData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null) return false;

    bool hasData = false;
    if (data.containsKey('lastTrendAnalysis')) {
      setState(() => _trend = HealthTrendAnalysis.fromJson(data['lastTrendAnalysis']));
      hasData = true;
    }
    if (data.containsKey('lastLifestylePlan')) {
      setState(() => _lifestyle = LifestylePlan.fromJson(data['lastLifestylePlan']));
      hasData = true;
    }
    return hasData;
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingTrend = true);
    setState(() => _isLoadingLifestyle = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final selectedCountry = ref.read(countryProvider);
      
      // Fetch history for trends
      final appointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final history = appointments.docs.map((doc) => {
        'symptoms': doc.get('symptoms'),
        'aiSummary': doc.get('aiSummary'),
        'status': doc.get('status'),
        'prescription': doc.data().containsKey('prescription') ? doc.get('prescription') : null,
        'createdAt': (doc.get('createdAt') as Timestamp).toDate().toIso8601String(),
      }).toList();
      
      final trend = await _aiService.predictHealthTrends(history, country: selectedCountry);
      
      // Generate lifestyle based on recent medical context (including prescriptions)
      String context = "General wellness in $selectedCountry";
      if (history.isNotEmpty) {
        context = "Medical Context History in $selectedCountry (Latest first):\n";
        for (var app in history) {
          context += "- Symptoms: ${app['symptoms'] ?? 'None'}\n";
          if (app['prescription'] != null && app['prescription'].toString().isNotEmpty) {
            context += "  Doctor's Prescription: ${app['prescription']}\n";
          }
          context += "  AI Assessment: ${app['aiSummary']}\n";
        }
      }
      
      final lifestyle = await _aiService.generateLifestyleCoaching(context, country: selectedCountry);

      // Persist to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'lastTrendAnalysis': {
          'forecast': trend.forecast,
          'identifiedPatterns': trend.identifiedPatterns,
          'potentialRisks': trend.potentialRisks,
        },
        'lastLifestylePlan': {
          'mealPlan': lifestyle.mealPlan,
          'exerciseRoutine': lifestyle.exerciseRoutine,
          'nutritionalAdvice': lifestyle.nutritionalAdvice,
        },
        'lastAIUpdate': FieldValue.serverTimestamp(),
      });

      setState(() {
        _trend = trend;
        _lifestyle = lifestyle;
        _isLoadingTrend = false;
        _isLoadingLifestyle = false;
      });
    } catch (e) {
      debugPrint('AI Insights Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load insights: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadData,
            ),
          ),
        );
      }
      setState(() {
        _isLoadingTrend = false;
        _isLoadingLifestyle = false;
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
                      padding: EdgeInsets.symmetric(horizontal: isTablet ? 40.0 : 24.0),
                      child: Column(
                        children: [
                          _buildTabToggle(),
                          const SizedBox(height: 32),
                          if (_isLoadingTrend || _isLoadingLifestyle)
                            SizedBox(
                              height: 400,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 48)
                                      .animate(onPlay: (c) => c.repeat()).rotate(duration: 2.seconds).scale(begin: const Offset(0.8,0.8), end: const Offset(1.2, 1.2)),
                                    const SizedBox(height: 24),
                                    Text('Generating Intelligence...', style: GoogleFonts.plusJakartaSans(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            )
                          else if (_trend == null && _lifestyle == null)
                             SizedBox(
                              height: 300,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.analytics_outlined, color: AppColors.secondary, size: 48),
                                    const SizedBox(height: 16),
                                    Text('No insights available yet.', style: GoogleFonts.plusJakartaSans(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    TextButton(onPressed: _loadData, child: const Text('Generate Insights')),
                                  ],
                                ),
                              ),
                            )
                          else
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 1200),
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildTrendTab(isTablet),
                                  _buildLifestyleTab(isTablet),
                                ],
                              ),
                            ),
                        ],
                      ),
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
        child: CircleAvatar(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textDeep, size: 16),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                ? [AppColors.navyDepth, AppColors.backgroundDark]
                : [const Color(0xFFE0E7FF), AppColors.background],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Text(
                  'HEALTH INTELLIGENCE',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'AI Insights',
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

  Widget _buildTabToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 60,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? [] : AppColors.softShadow,
        border: Border.all(color: (isDark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.05)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.secondary,
        labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Trends'),
          Tab(text: 'Lifestyle'),
        ],
      ),
    );
  }

  Widget _buildTrendTab(bool isTablet) {
    if (_trend == null) return const Center(child: Text('No data available'));

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInsightCard(
            'Predictive Forecast',
            _trend!.forecast,
            Icons.auto_graph_rounded,
            AppColors.primary,
          ),
          const SizedBox(height: 24),
          if (isTablet)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildListCard('Identified Patterns', _trend!.identifiedPatterns, Icons.pattern_rounded, AppColors.accent)),
                const SizedBox(width: 24),
                Expanded(child: _buildListCard('Potential Risks', _trend!.potentialRisks, Icons.warning_amber_rounded, AppColors.accent)),
              ],
            )
          else ...[
            _buildListCard('Identified Patterns', _trend!.identifiedPatterns, Icons.pattern_rounded, AppColors.accent),
            const SizedBox(height: 24),
            _buildListCard('Potential Risks', _trend!.potentialRisks, Icons.warning_amber_rounded, AppColors.accent),
          ],
          const SizedBox(height: 100),
        ],
      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
    );
  }

  Widget _buildLifestyleTab(bool isTablet) {
    if (_lifestyle == null) return const Center(child: Text('No plan available'));

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInsightCard(
            'Nutritional Advice',
            _lifestyle!.nutritionalAdvice,
            Icons.restaurant_rounded,
            AppColors.accent,
          ),
          const SizedBox(height: 24),
          if (isTablet)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildListCard('3-Day Meal Plan', _lifestyle!.mealPlan, Icons.calendar_today_rounded, AppColors.primary)),
                const SizedBox(width: 24),
                Expanded(child: _buildListCard('Exercise Routine', _lifestyle!.exerciseRoutine, Icons.fitness_center_rounded, AppColors.accentSecondary)),
              ],
            )
          else ...[
            _buildListCard('3-Day Meal Plan', _lifestyle!.mealPlan, Icons.calendar_today_rounded, AppColors.primary),
            const SizedBox(height: 24),
            _buildListCard('Exercise Routine', _lifestyle!.exerciseRoutine, Icons.fitness_center_rounded, AppColors.accentSecondary),
          ],
          const SizedBox(height: 100),
        ],
      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
    );
  }

  Widget _buildInsightCard(String title, String content, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.all(28),
      borderRadius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: isDark ? Colors.white : AppColors.textDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            content,
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? Colors.white70 : AppColors.textDeep.withValues(alpha: 0.7),
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(String title, List<String> items, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.all(28),
      borderRadius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: isDark ? Colors.white : AppColors.textDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.plusJakartaSans(
                      color: isDark ? Colors.white70 : AppColors.textDeep.withValues(alpha: 0.7),
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
