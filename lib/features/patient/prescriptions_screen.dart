import 'package:hospital_app/providers/country_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/theme/app_colors.dart';
import '../../core/services/gemini_ai_service.dart';
import '../../core/widgets/glass_card.dart';

class PrescriptionsScreen extends ConsumerStatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  ConsumerState<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends ConsumerState<PrescriptionsScreen> {
  final GeminiAIService _aiService = GeminiAIService();

  void _showAIExplanation(String diagnosis, List<String> medicines, String prescriptionId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.shelf,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: FutureBuilder<String>(
                  future: _getOrGenerateExplanation(diagnosis, medicines, prescriptionId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    return ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(32),
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Prescription Guide',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDeep,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.shelf),
                          ),
                          child: MarkdownBody(
                            data: snapshot.data ?? '',
                            styleSheet: MarkdownStyleSheet(
                              p: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                height: 1.6,
                                color: AppColors.secondaryDark,
                              ),
                              h1: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                              h2: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                              listBullet: GoogleFonts.plusJakartaSans(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ).animate().fadeIn().slideY(begin: 0.1),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _getOrGenerateExplanation(String diagnosis, List<String> medicines, String prescriptionId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "User not logged in";

    final docRef = FirebaseFirestore.instance
        .collection('prescriptions')
        .doc(prescriptionId);

    try {
      final doc = await docRef.get();
      if (doc.exists && doc.data()?.containsKey('aiExplanation') == true) {
        return doc.data()!['aiExplanation'];
      }

      final selectedCountry = ref.read(countryProvider);
      final explanation = await _aiService.explainPrescription(diagnosis, medicines, country: selectedCountry);
      await docRef.set({'aiExplanation': explanation}, SetOptions(merge: true));
      return explanation;
    } catch (e) {
      return "Error fetching explanation: $e";
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildWarmAppBar(context, isDark),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            sliver: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('prescriptions')
                  .where('patientId', isEqualTo: user?.uid)
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.medication_liquid_rounded, 
                            size: 80, 
                            color: AppColors.shelf
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No scripts found',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.secondaryDark.withValues(alpha: 0.5),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final prescriptions = snapshot.data!.docs;

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = prescriptions[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildMinimalPrescriptionCard(data, index, isDark, doc.id);
                    },
                    childCount: prescriptions.length,
                  ),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildWarmAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 140,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12.0),
        child: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textDeep, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.fromLTRB(24, 70, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COLLECTION',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Written Pages',
                style: GoogleFonts.playfairDisplay(
                  color: isDark ? Colors.white : AppColors.textDeep,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalPrescriptionCard(Map<String, dynamic> data, int index, bool isDark, String docId) {
    final date = (data['date'] as Timestamp).toDate();
    final doctorName = data['doctorName'] ?? 'Physician';
    final diagnosis = data['diagnosis'] ?? 'General Consultation';
    final medicines = (data['medicines'] as List<dynamic>?) ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMMM dd').format(date).toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Icon(Icons.more_horiz_rounded, color: AppColors.shelf, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              diagnosis,
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textDeep,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Issued by Dr. $doctorName',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.secondaryDark.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ...medicines.take(2).map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                '• ${m.toString()}',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.secondaryDark,
                  fontSize: 14,
                ),
              ),
            )),
            if (medicines.length > 2)
              Text(
                '+ ${medicines.length - 2} more medications',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _showAIExplanation(
                diagnosis, 
                medicines.map((e) => e.toString()).toList(),
                docId
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 16),
                    const SizedBox(width: 10),
                    Text(
                      'Clinical Insight',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1, curve: Curves.easeOutQuad);
  }
}
