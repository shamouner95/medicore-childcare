import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/gemini_ai_service.dart';
import '../../core/widgets/ai_processing_overlay.dart';
import 'dart:convert';

class DoctorListScreen extends StatefulWidget {
  final String? initialSymptoms;
  final String? initialDepartment;
  const DoctorListScreen({super.key, this.initialSymptoms, this.initialDepartment});

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  String? _recommendedDoctorId;
  final GeminiAIService _aiService = GeminiAIService();
  String? _symptoms;
  List<Map<String, dynamic>> _activeOutbreaks = [];

  @override
  void initState() {
    super.initState();
    _symptoms = widget.initialSymptoms;
    _fetchRegionalIntelligence();
  }

  Future<void> _fetchRegionalIntelligence() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('environmental_indicators')
          .where('type', isEqualTo: 'outbreak')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();
      
      if (mounted) {
        setState(() {
          _activeOutbreaks = snapshot.docs.map((doc) => doc.data()).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching regional intel: $e');
    }
  }

  Future<void> _performSmartMatch(List<QueryDocumentSnapshot> doctors) async {
    if (_symptoms == null || _symptoms!.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AIProcessingOverlay(message: 'Medicore AI is finding the perfect match...'),
    );

    try {
      final List<Map<String, String>> docList = doctors.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {
          'id': d.id,
          'name': data['name']?.toString() ?? '',
          'speciality': data['speciality']?.toString() ?? '',
        };
      }).toList();

      final recommendation = await _aiService.matchSpecialist(
        symptoms: _symptoms!,
        availableDoctors: docList,
      );

      final Map<String, dynamic> result = jsonDecode(recommendation);
      final String recommendedId = result['recommendedDoctorId'];

      if (mounted) {
        Navigator.pop(context); // Close overlay
        setState(() {
          _recommendedDoctorId = recommendedId;
        });

        // Show recommendation info
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? AppColors.backgroundDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 40),
                const SizedBox(height: 20),
                Text('AI Recommendation', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(result['reason'], textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(color: AppColors.secondary)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('VIEW RECOMMENDATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .snapshots();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, isDark),
          StreamBuilder(
            stream: stream,
            builder: (context, AsyncSnapshot<QuerySnapshot> snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                );
              }

              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'No specialists found',
                      style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                );
              }

              final doctors = snap.data!.docs;

              return SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_symptoms != null && _symptoms!.length > 10)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: _buildSmartMatchPromo(doctors, isDark),
                      ),
                    ...doctors.asMap().entries.map((entry) {
                      final index = entry.key;
                      final doc = entry.value;
                      final data = doc.data() as Map<String, dynamic>;
                      final speciality = data['speciality']?.toString() ?? '';
                      final isAiMatched = _recommendedDoctorId == doc.id;
                      final isDeptMatched = widget.initialDepartment != null && 
                          speciality.toLowerCase() == widget.initialDepartment!.toLowerCase();

                      return _buildDoctorCard(context, doc.id, data, isDark, index, isAiMatched || isDeptMatched);
                    }),
                    if (_activeOutbreaks.isNotEmpty)
                      _buildRegionalAdvisory(isDark),
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSmartMatchPromo(List<QueryDocumentSnapshot> doctors, bool isDark) {
    return GestureDetector(
      onTap: () => _performSmartMatch(doctors),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.coolGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SMART MATCH AVAILABLE', 
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text('Let Medicore AI find the best specialist for your symptoms.', 
                    style: GoogleFonts.plusJakartaSans(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    ).animate().shimmer(duration: 2.seconds);
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 120,
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        // IconButton(
        //   icon: Icon(Icons.map_rounded, color: isDark ? Colors.white : Colors.green),
        //   onPressed: () => context.push('/map', extra: {'symptoms': _symptoms}),
        // ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          'Find Specialists',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.accent.withValues(alpha: 0.1),
                isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegionalAdvisory(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top:32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emergency_outlined, color: Colors.orange, size: 20),
              const SizedBox(width: 12),
              Text('REGIONAL EPIDEMIC ADVISORY', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.orange, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Specialists in hospitals near reported outbreak zones are currently on high alert. Prioritize booking these professionals for urgent infectious concerns.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: isDark ? Colors.white70 : AppColors.textDeep, height: 1.5),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildDoctorCard(BuildContext context, String docId, Map<String, dynamic> data, bool isDark, int index, bool isRecommended) {
    final String name = data['name'] ?? 'Medical Professional';
    final String speciality = data['speciality'] ?? 'General Medicine';
    final String imageUrl = data['profileImageUrl'] ?? 'https://ui-avatars.com/api/?name=${name.replaceAll(' ', '+')}&background=random';
    
    // Check if hospital is in surge focus (mocking proximity for now or checking a flag)
    final bool isSurgeFocus = data['surgeFocus'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isRecommended ? AppColors.accent : (isSurgeFocus ? Colors.orange.withValues(alpha: 0.5) : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          width: (isRecommended || isSurgeFocus) ? 2 : 1,
        ),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/book', extra: {
            'doctorId': docId,
            'symptoms': _symptoms,
            'specialty': speciality,
          }),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  children: [
                    Hero(
                      tag: 'doctor_$docId',
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    if (isRecommended || isSurgeFocus)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: isRecommended ? AppColors.accent : Colors.orange, shape: BoxShape.circle),
                          child: Icon(isRecommended ? Icons.auto_awesome : Icons.bolt, color: Colors.white, size: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (isRecommended)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('AI MATCH', style: GoogleFonts.plusJakartaSans(color: AppColors.accent, fontSize: 8, fontWeight: FontWeight.w900)),
                            ),
                          if (isSurgeFocus)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('SURGE FOCUS', style: GoogleFonts.plusJakartaSans(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.w900)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        speciality,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.orangeAccent, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '4.9 (120+ reviews)',
                            style: GoogleFonts.plusJakartaSans(
                              color: isDark ? Colors.white38 : Colors.black45,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.accent, size: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1);
  }
}
