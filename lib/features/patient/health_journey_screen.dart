import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_app/providers/country_provider.dart';
import 'package:hospital_app/core/theme/app_colors.dart';
import 'package:hospital_app/core/services/gemini_ai_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hospital_app/core/widgets/glass_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hospital_app/core/widgets/ai_processing_overlay.dart';

class HealthJourneyScreen extends ConsumerStatefulWidget {
  final String appointmentId;
  const HealthJourneyScreen({super.key, required this.appointmentId});

  @override
  ConsumerState<HealthJourneyScreen> createState() => _HealthJourneyScreenState();
}

class _HealthJourneyScreenState extends ConsumerState<HealthJourneyScreen> {
  final GeminiAIService _aiService = GeminiAIService();
  final TextEditingController _checkinController = TextEditingController();
  bool _isLoading = false;
  HealthJourneyAnalysis? _analysis;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  void _loadAnalysis() async {
    final doc = await FirebaseFirestore.instance.collection('appointments').doc(widget.appointmentId).get();
    if (doc.exists && doc.data()?['healthJourney'] != null) {
      setState(() {
        _analysis = HealthJourneyAnalysis.fromJson(doc.data()?['healthJourney']);
      });
    }
  }

  void _submitCheckin() async {
    if (_checkinController.text.isEmpty) return;

    final selectedCountry = ref.read(countryProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AIProcessingOverlay(message: 'Analyzing recovery metrics...'),
    );

    try {
      final appDoc = await FirebaseFirestore.instance.collection('appointments').doc(widget.appointmentId).get();
      final data = appDoc.data()!;
      
      final List<String> checkins = List<String>.from(data['dailyCheckins'] ?? []);
      checkins.add(_checkinController.text);

      final analysis = await _aiService.analyzeRecoveryProgress(
        data['symptoms'] ?? '',
        data['prescription'] ?? '',
        checkins,
        country: selectedCountry,
      );

      await FirebaseFirestore.instance.collection('appointments').doc(widget.appointmentId).update({
        'dailyCheckins': checkins,
        'healthJourney': {
          'recoveryProgress': analysis.recoveryProgress,
          'statusMessage': analysis.statusMessage,
          'nextSteps': analysis.nextSteps,
          'alertDoctor': analysis.alertDoctor,
        }
      });

      if (mounted) {
        Navigator.pop(context); // Close overlay
        setState(() {
          _analysis = analysis;
          _checkinController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daily check-in recorded!')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close overlay
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isTablet ? 800 : double.infinity),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildCrystalHeader(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isTablet ? 40 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      _buildSectionLabel('RECOVERY VELOCITY'),
                      const SizedBox(height: 16),
                      _buildRecoveryChart(isTablet),
                      const SizedBox(height: 40),
                      if (_analysis != null) ...[
                        _buildSectionLabel('MEDICORE AI INSIGHTS'),
                        const SizedBox(height: 16),
                        _buildStatusCard(),
                        const SizedBox(height: 40),
                        _buildSectionLabel('DAILY ACTION PLAN'),
                        const SizedBox(height: 16),
                        _buildNextSteps(isTablet),
                        const SizedBox(height: 40),
                      ],
                      _buildSectionLabel('HOW ARE YOU FEELING?'),
                      const SizedBox(height: 16),
                      _buildCheckinInput(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCrystalHeader(BuildContext context) {
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
                  'HEALTH JOURNEY',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'Patient Progress',
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

  Widget _buildSectionLabel(String text) {
    return Text(text, style: GoogleFonts.plusJakartaSans(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2));
  }

  Widget _buildRecoveryChart(bool isTablet) {
    final dataPoints = _analysis?.recoveryProgress ??
        [0.0, 20.0, 45.0, 35.0, 70.0]; // Sample data if null
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: EdgeInsets.all(isTablet ? 36 : 28),
      borderRadius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progress Index',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDeep)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${dataPoints.last.toInt()}%',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: isTablet ? 260 : 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.textDeep.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            'Day ${value.toInt() + 1}',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${value.toInt()}%',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (dataPoints.length - 1).toDouble(),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: dataPoints
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value))
                        .toList(),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    gradient: const LinearGradient(
                        colors: [AppColors.accent, AppColors.primary]),
                    barWidth: 5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 6,
                        color: Colors.white,
                        strokeWidth: 3,
                        strokeColor: AppColors.accent,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.accent.withValues(alpha: 0.1),
                          AppColors.accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.white,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        return LineTooltipItem(
                          '${barSpot.y.toInt()}%',
                          GoogleFonts.plusJakartaSans(
                            color: AppColors.textDeep,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: AppColors.coolGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('MEDICORE GEN-AI ANALYSIS', 
                style: GoogleFonts.plusJakartaSans(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _analysis?.statusMessage ?? '',
            style: GoogleFonts.plusJakartaSans(fontSize: 16, height: 1.6, color: Colors.white, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
          ),
          if (_analysis?.alertDoctor == true)
            Container(
              margin: const EdgeInsets.only(top:20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'AI suggests alerting your doctor due to slow progress.',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().shimmer(duration: Duration(milliseconds: 2), color: Colors.white.withValues(alpha: 0.2));
  }

  Widget _buildNextSteps(bool isTablet) {
    final steps = _analysis?.nextSteps ?? [];
    if (isTablet) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 90,
        ),
        itemCount: steps.length,
        itemBuilder: (context, index) => _buildStepCard(steps[index]),
      );
    }
    return Column(
      children: steps.map((step) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildStepCard(step),
      )).toList(),
    );
  }

  Widget _buildStepCard(String step) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(step,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.textDeep,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckinInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.all(28),
      borderRadius: 32,
      child: Column(
        children: [
          TextField(
            controller: _checkinController,
            maxLines: 3,
            style: GoogleFonts.plusJakartaSans(
                color: isDark ? Colors.white : AppColors.textDeep, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'e.g. Feeling much better today...',
              hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.secondary),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitCheckin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 8,
                shadowColor: AppColors.primary.withValues(alpha: 0.3),
              ),
              child: const Text('UPDATE PROGRESS',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}
