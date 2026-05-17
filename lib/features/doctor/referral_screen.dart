import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ai_processing_overlay.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/gemini_ai_service.dart';
import '../../providers/notification_provider.dart';

class ReferralScreen extends ConsumerStatefulWidget {
  final String? patientId;
  const ReferralScreen({super.key, this.patientId});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  String? _selectedDoctorId;
  String? _selectedPatientId;
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  bool _isAiMatching = false;
  String? _aiRecommendationReason;
  final GeminiAIService _aiService = GeminiAIService();

  @override
  void initState() {
    super.initState();
    _selectedPatientId = widget.patientId;
  }

  Future<void> _matchSpecialistWithAI() async {
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient first')),
      );
      return;
    }

    setState(() => _isAiMatching = true);

    try {
      // 1. Fetch patient's latest symptoms
      final appointmentSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: _selectedPatientId)
          .orderBy('dateTime', descending: true)
          .limit(1)
          .get();

      if (appointmentSnapshot.docs.isEmpty) {
        throw 'No recent symptoms found for this patient';
      }

      final symptoms = appointmentSnapshot.docs.first.get('symptoms') as String;

      // 2. Fetch available doctors
      final doctorsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .get();

      final doctors = doctorsSnapshot.docs
          .where((d) => d.id != FirebaseAuth.instance.currentUser?.uid)
          .map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': data['name'] as String,
          'speciality': (data['speciality'] ?? 'General Medicine') as String,
        };
      }).toList();

      // 3. Call AI Service
      final aiResponse = await _aiService.matchSpecialist(
        symptoms: symptoms,
        availableDoctors: doctors,
      );

      final decoded = jsonDecode(aiResponse);
      
      setState(() {
        _selectedDoctorId = decoded['recommendedDoctorId'];
        _aiRecommendationReason = decoded['reason'];
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI Matching Error: $e')),
      );
    } finally {
      setState(() => _isAiMatching = false);
    }
  }

  void _sendReferral() async {
    if (_selectedDoctorId == null || _selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both a patient and a doctor')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AIProcessingOverlay(message: 'Encrypting referral data...'),
    );

    try {
      final currentDoctorId = FirebaseAuth.instance.currentUser!.uid;
      
      // Get current doctor's name
      final currentDoctorDoc = await FirebaseFirestore.instance.collection('users').doc(currentDoctorId).get();
      final currentDoctorName = currentDoctorDoc.data()?['name'] ?? 'Doctor';

      // Get patient's name
      final patientDoc = await FirebaseFirestore.instance.collection('users').doc(_selectedPatientId).get();
      final patientName = patientDoc.data()?['name'] ?? 'Patient';

      final docRef = await FirebaseFirestore.instance.collection('referrals').add({
        'fromDoctorId': currentDoctorId,
        'toDoctorId': _selectedDoctorId,
        'patientId': _selectedPatientId,
        'notes': _notesController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Send notification to the target doctor
      await ref.read(notificationServiceProvider).sendNotification(
        userId: _selectedDoctorId!,
        title: 'New Patient Referral',
        body: 'Dr. $currentDoctorName has referred $patientName to you.',
        type: 'referral',
        relatedId: docRef.id,
      );

      if (mounted) {
        Navigator.pop(context); // Close overlay
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referral sent successfully')),
        );
        Navigator.pop(context); // Go back
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? AppColors.textLight : AppColors.textDeep;
    final Color surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(isDark, textColor),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('Select Patient'),
                  const SizedBox(height: 12),
                  _buildPatientSelector(surfaceColor, textColor),
                  const SizedBox(height: 32),
                  _buildSectionLabel('Select Specialist'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildDoctorSelector(surfaceColor, textColor)),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _isAiMatching ? null : _matchSpecialistWithAI,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: AppColors.coolGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: AppColors.softShadow,
                          ),
                          child: _isAiMatching 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                  if (_aiRecommendationReason != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'AI Recommendation: $_aiRecommendationReason',
                              style: GoogleFonts.plusJakartaSans(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: 0.2),
                  ],
                  const SizedBox(height: 32),
                  _buildSectionLabel('Clinical Notes'),
                  const SizedBox(height: 12),
                  _buildNotesInput(surfaceColor, textColor),
                  const SizedBox(height: 48),
                  _buildSubmitButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isDark, Color textColor) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                shape: BoxShape.circle,
                boxShadow: AppColors.softShadow,
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'New Referral',
          style: GoogleFonts.plusJakartaSans(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppColors.secondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildPatientSelector(Color surfaceColor, Color textColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        
        final patientIds = snapshot.data!.docs.map((d) => d['patientId'] as String).toSet().toList();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.softShadow,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.05)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPatientId,
              isExpanded: true,
              hint: Text('Choose a patient', style: GoogleFonts.plusJakartaSans(color: textColor.withValues(alpha: 0.4))),
              dropdownColor: surfaceColor,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
              items: patientIds.map((id) {
                return DropdownMenuItem(
                  value: id,
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(id).snapshots(),
                    builder: (context, s) {
                      final name = s.data?.get('name') ?? 'Loading...';
                      return Text(
                        name, 
                        style: GoogleFonts.plusJakartaSans(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        )
                      );
                    },
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedPatientId = val),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1);
      },
    );
  }

  Widget _buildDoctorSelector(Color surfaceColor, Color textColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        
        final doctors = snapshot.data!.docs.where((d) => d.id != FirebaseAuth.instance.currentUser?.uid).toList();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.softShadow,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.05)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDoctorId,
              isExpanded: true,
              hint: Text('Choose a specialist', style: GoogleFonts.plusJakartaSans(color: textColor.withValues(alpha: 0.4))),
              dropdownColor: surfaceColor,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
              items: doctors.map((d) {
                final data = d.data() as Map<String, dynamic>;
                return DropdownMenuItem(
                  value: d.id,
                  child: Text(
                    '${data['name']} (${data['speciality'] ?? 'Specialist'})', 
                    style: GoogleFonts.plusJakartaSans(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    )
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedDoctorId = val),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideX(begin: 0.1);
      },
    );
  }

  Widget _buildNotesInput(Color surfaceColor, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.softShadow,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: _notesController,
        maxLines: 5,
        style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Provide details about why you are referring this patient...',
          hintStyle: GoogleFonts.plusJakartaSans(color: textColor.withValues(alpha: 0.3)),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _sendReferral,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(
              'Send Referral & Medical History', 
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold, 
                fontSize: 16,
                color: Colors.white,
              )
            ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }
}
