import 'package:hospital_app/providers/country_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_app/providers/appointment_provider.dart';
import 'package:hospital_app/models/appointment_model.dart';
import 'package:hospital_app/core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'package:hospital_app/core/widgets/glass_card.dart';
import 'package:hospital_app/core/widgets/ai_processing_overlay.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hospital_app/core/services/gemini_ai_service.dart';
import 'package:hospital_app/core/models/test_result.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class AppointmentDetailScreen extends ConsumerStatefulWidget {
  final Appointment appointment;

  const AppointmentDetailScreen({super.key, required this.appointment});

  @override
  ConsumerState<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends ConsumerState<AppointmentDetailScreen> {
  final _reasonController = TextEditingController();
  final _prescriptionController = TextEditingController();
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  final GeminiAIService _aiService = GeminiAIService();

  @override
  void initState() {
    super.initState();
    _prescriptionController.text = widget.appointment.prescription ?? '';
  }

  void _handleStatusUpdate(String status) async {
    if (status == 'rejected' && _reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for declining')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AIProcessingOverlay(message: status == 'accepted' ? 'Securing consultation slot...' : 'Processing rejection...'),
    );

    try {
      await ref.read(appointmentProvider.notifier).updateStatus(
            widget.appointment.id,
            status,
            reason: status == 'rejected' ? _reasonController.text : null,
          );
      if (mounted) {
        Navigator.pop(context); // Close overlay
        Navigator.pop(context); // Go back to list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Appointment $status successfully')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _uploadLabReport() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AIProcessingOverlay(message: 'Uploading to Patient Cloud...'),
    );

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('lab_reports')
          .child('${widget.appointment.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      final uploadTask = await ref.putFile(File(image.path));
      final url = await uploadTask.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointment.id)
          .update({
        'labReports': FieldValue.arrayUnion([url])
      });

      if (mounted) {
        Navigator.pop(context); // Close overlay
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lab report uploaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading report: $e')),
        );
      }
    }
  }

  void _viewReport(String url) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: AppColors.textDeep.withValues(alpha: 0.9),
      pageBuilder: (context, anim1, anim2) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Hero(
              tag: url,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _analyzeReportAI(url),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            label: const Text('AI Analysis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Future<void> _analyzeReportAI(String url) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AIProcessingOverlay(message: 'Gemini 1.5 Pro scanning report...'),
    );

    try {
      final response = await http.get(Uri.parse(url));
      final testResult = await _aiService.extractLabReportData(response.bodyBytes);
      
      if (mounted) {
        Navigator.pop(context); // Close overlay
        _showLabAnalysisResults(testResult);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Analysis failed: $e')));
      }
    }
  }

  void _showLabAnalysisResults(TestResult result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.backgroundDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(32),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Lab Analysis', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textDeep)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: isDark ? Colors.white : AppColors.textDeep)),
                ],
              ),
              const SizedBox(height: 32),
              _buildModernInsightCard('Test Title', result.title, Icons.biotech_rounded, AppColors.primary, isDark),
              const SizedBox(height: 16),
              _buildModernInsightCard('Status', result.status, Icons.analytics_rounded, result.isNormal ? AppColors.success : AppColors.accent, isDark),
              const SizedBox(height: 16),
              _buildModernInsightCard('Laboratory', result.labName, Icons.business_rounded, AppColors.secondary, isDark),
              const SizedBox(height: 24),
              if (!result.isNormal)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Abnormal values detected. Clinical correlation required.',
                          style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernInsightCard(String title, String content, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white : AppColors.textDeep, fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }

  void _showDeclineDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          title: Text('Decline Request', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textDeep)),
          content: TextField(
            controller: _reasonController,
            maxLines: 3,
            style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white : AppColors.textDeep),
            decoration: InputDecoration(
              hintText: 'Enter reason...',
              hintStyle: GoogleFonts.plusJakartaSans(color: (isDark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.3)),
              filled: true,
              fillColor: (isDark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: (isDark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.6)))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _handleStatusUpdate('rejected');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('Confirm', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _addPrescription() async {
    if (_prescriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter prescription details')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AIProcessingOverlay(message: 'Syncing Clinical Data...'),
    );

    try {
      await FirebaseFirestore.instance.collection('appointments').doc(widget.appointment.id).update({'prescription': _prescriptionController.text});
      if (mounted) {
        Navigator.pop(context); // Close overlay
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prescription synchronized to Patient Cloud')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error syncing data: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.appointment.patientId).snapshots(),
        builder: (context, snapshot) {
          final patientData = snapshot.data?.data() as Map<String, dynamic>?;
          final name = patientData?['name'] ?? 'Patient';
          final image = patientData?['profileImageUrl'];

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildDribbbleHeader(context, name, image, isDark),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      _buildInfoRow(isDark).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
                      const SizedBox(height: 40),
                      _buildSectionLabel('PATIENT CLINICAL BRIEF').animate().fadeIn(duration: 500.ms, delay: 50.ms).slideX(begin: -0.1),
                      const SizedBox(height: 16),
                      _buildPatientBriefCard(patientData, isDark),
                      const SizedBox(height: 40),
                      _buildSectionLabel('REPORTED SYMPTOMS').animate().fadeIn(duration: 500.ms, delay: 100.ms).slideX(begin: -0.1),
                      const SizedBox(height: 16),
                      _buildSymptomsCard(isDark).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.1),
                      const SizedBox(height: 40),
                      _buildSectionLabel('MEDICORE AI PRE-SCREENING').animate().fadeIn(duration: 500.ms, delay: 300.ms).slideX(begin: -0.1),
                      const SizedBox(height: 16),
                      _buildAICard(patientData).animate().fadeIn(duration: 600.ms, delay: 400.ms).slideY(begin: 0.1),
                      const SizedBox(height: 40),
                      _buildSectionLabel('LABORATORY ASSETS').animate().fadeIn(duration: 500.ms, delay: 500.ms).slideX(begin: -0.1),
                      const SizedBox(height: 16),
                      _buildModernReports(isDark).animate().fadeIn(duration: 600.ms, delay: 600.ms).slideY(begin: 0.1),
                      const SizedBox(height: 40),
                      if (widget.appointment.status == 'accepted') ...[
                        _buildSectionLabel('CLINICAL DIAGNOSIS & RX').animate().fadeIn(duration: 500.ms).slideX(begin: -0.1),
                        const SizedBox(height: 16),
                        _buildPrescriptionBox(isDark).animate().fadeIn(duration: 600.ms, delay: 100.ms).slideY(begin: 0.1),
                      ],
                      const SizedBox(height: 160),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: widget.appointment.status == 'pending' ? _buildFloatingActions(isDark) : null,
    );
  }

  Widget _buildDribbbleHeader(BuildContext context, String name, String? imageUrl, bool isDark) {
    return SliverAppBar(
      expandedHeight: 420,
      pinned: true,
      stretch: true,
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
                boxShadow: isDark ? [] : AppColors.softShadow,
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textDeep, size: 20),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              Image.network(imageUrl, fit: BoxFit.cover)
            else
              Container(
                decoration: const BoxDecoration(gradient: AppColors.premiumGradient),
                child: const Icon(Icons.person, size: 100, color: Colors.white24),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (isDark ? AppColors.backgroundDark : AppColors.background).withValues(alpha: 0.1),
                    (isDark ? AppColors.backgroundDark : AppColors.background).withValues(alpha: 0.4),
                    isDark ? AppColors.backgroundDark : AppColors.background,
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text('PREMIUM PATIENT', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                  const SizedBox(height: 16),
                  Text(name, style: GoogleFonts.playfairDisplay(fontSize: 48, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.textDeep, height: 1)),
                  const SizedBox(height: 8),
                  Text('Scheduled for ${widget.appointment.appointmentDate} • ${widget.appointment.appointmentTime}', 
                    style: GoogleFonts.plusJakartaSans(color: (isDark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.5), fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildQuickStat('TYPE', 'Consultation', Icons.videocam_rounded, isDark),
        _buildQuickStat('PRIORITY', 'High', Icons.bolt_rounded, isDark),
        _buildQuickStat('ID', '#${widget.appointment.id.substring(0, 5)}', Icons.fingerprint_rounded, isDark),
      ],
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: isDark ? [] : AppColors.softShadow,
            border: Border.all(color: isDark ? Colors.white10 : AppColors.shelf),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(height: 12),
        Text(value, style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white : AppColors.textDeep, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white38 : AppColors.textDeep.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text, style: GoogleFonts.plusJakartaSans(color: AppColors.primary.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2));
  }

  Widget _buildPatientBriefCard(Map<String, dynamic>? patientData, bool isDark) {
    final selectedCountry = ref.read(countryProvider);
    return FutureBuilder<PatientBrief>(
      future: _aiService.getPatientRecordSummary(patientData ?? {}, country: selectedCountry),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: isDark ? Colors.white10 : AppColors.shelf),
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
          );
        }
        final brief = snapshot.data!;
        return GlassCard(
          padding: const EdgeInsets.all(24),
          borderRadius: 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(brief.summary, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : AppColors.textDeep)),
              if (brief.criticalAlerts.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...brief.criticalAlerts.map((alert) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.primary, size: 14),
                      const SizedBox(width: 8),
                      Text(alert, style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSymptomsCard(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Text(widget.appointment.symptoms, 
        style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white : AppColors.textDeep, fontSize: 16, height: 1.6, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildAICard(Map<String, dynamic>? patientData) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('MEDICORE GEN-AI INSIGHT', 
                    style: GoogleFonts.plusJakartaSans(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                ],
              ),
              const SizedBox(height: 16),
              Text(widget.appointment.aiSummary, 
                style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 18, fontStyle: FontStyle.italic, height: 1.6, fontWeight: FontWeight.w600)),
            ],
          ),
        ).animate().shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.2)),
        const SizedBox(height: 16),
        _buildClinicalToolsTrigger(patientData),
      ],
    );
  }

  Widget _buildClinicalToolsTrigger(Map<String, dynamic>? patientData) {
    return GestureDetector(
      onTap: () => _showClinicalInsights(patientData),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.biotech_rounded, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Generate Clinical Intelligence', 
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 14)),
            ),
            const Icon(Icons.auto_fix_high_rounded, color: AppColors.accent, size: 18),
          ],
        ),
      ),
    );
  }

  void _showClinicalInsights(Map<String, dynamic>? patientData) async {
    final selectedCountry = ref.read(countryProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AIProcessingOverlay(message: 'Consulting Medical Knowledge Base...'),
    );

    try {
      final insights = await _aiService.getClinicalTools(
        widget.appointment.symptoms, 
        patientData?.toString() ?? "No major history",
        country: selectedCountry,
      );
      if (mounted) {
        Navigator.pop(context); // Close overlay
        _showClinicalInsightsModal(insights);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Intelligence generation failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showClinicalInsightsModal(ClinicalInsights insights) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark : AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 40,
              offset: const Offset(0, -10),
            )
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : AppColors.textDeep.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(32),
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.psychology_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Clinical Intelligence', 
                            style: GoogleFonts.playfairDisplay(fontSize: 26, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textDeep)),
                          Text('AI-Generated Differential Analysis', 
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? Colors.white60 : AppColors.textDeep.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildInsightSection('Differential Diagnoses', insights.differentialDiagnoses, Icons.troubleshoot_rounded),
                  const SizedBox(height: 24),
                  _buildInsightSection('Suggested Laboratory Panels', insights.suggestedTests, Icons.biotech_rounded),
                  const SizedBox(height: 24),
                  if (insights.potentialDrugInteractions.isNotEmpty) ...[
                    _buildInsightSection('Medication Vigilance', insights.potentialDrugInteractions, Icons.warning_amber_rounded, color: Colors.orange.shade800),
                    const SizedBox(height: 24),
                  ],
                  Text('CLINICAL OBSERVATION', 
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 10, color: isDark ? Colors.white38 : AppColors.textDeep.withValues(alpha: 0.4), letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    borderRadius: 24,
                    child: Text(insights.clinicalNote, 
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, color: isDark ? Colors.white : AppColors.textDeep, height: 1.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightSection(String title, List<String> items, IconData icon, {Color? color}) {
    final themeColor = color ?? AppColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: themeColor),
            const SizedBox(width: 8),
            Text(title.toUpperCase(), 
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 10, color: themeColor, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: themeColor.withValues(alpha: 0.1)),
            ),
            child: Text(item, 
              style: GoogleFonts.plusJakartaSans(color: themeColor, fontSize: 12, fontWeight: FontWeight.w700)),
          )).toList(),
        ),
      ],
    );
  }


  Widget _buildModernReports(bool isDark) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('appointments').doc(widget.appointment.id).snapshots(),
      builder: (context, snapshot) {
        final reports = (snapshot.data?.data() as Map<String, dynamic>?)?['labReports'] as List? ?? [];
        
        return Column(
          children: [
            if (reports.isEmpty)
              GlassCard(
                padding: const EdgeInsets.all(40),
                borderRadius: 32,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, color: isDark ? Colors.white24 : AppColors.textDeep.withValues(alpha: 0.2), size: 40), 
                    const SizedBox(height: 12), 
                    Text('No reports uploaded', style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white38 : AppColors.textDeep.withValues(alpha: 0.4), fontWeight: FontWeight.w600))
                  ],
                ),
              )
            else
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: reports.length,
                  itemBuilder: (context, index) => GestureDetector(
                    onTap: () => _viewReport(reports[index]),
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        image: DecorationImage(image: NetworkImage(reports[index]), fit: BoxFit.cover),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24), 
                          gradient: LinearGradient(
                            begin: Alignment.topCenter, 
                            end: Alignment.bottomCenter, 
                            colors: [Colors.transparent, AppColors.textDeep.withValues(alpha: 0.6)]
                          )
                        ),
                        child: const Center(child: Icon(Icons.fullscreen_rounded, color: Colors.white, size: 32)),
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.appointment.status == 'accepted') ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _uploadLabReport,
                  icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                  label: Text('UPLOAD LAB REPORT', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                    side: const BorderSide(color: AppColors.shelf),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPrescriptionBox(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 32,
      child: Column(
        children: [
          TextField(
            controller: _prescriptionController,
            maxLines: 6,
            style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white : AppColors.textDeep, fontSize: 16, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Enter clinical notes and prescription...',
              hintStyle: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white24 : AppColors.textDeep.withValues(alpha: 0.3)),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addPrescription,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
              ),
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('SYNC TO PATIENT CLOUD', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _showDeclineDialog,
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: isDark ? [] : AppColors.softShadow,
                  border: Border.all(color: AppColors.shelf),
                ),
                child: Center(child: Text('Decline', style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white60 : AppColors.textDeep.withValues(alpha: 0.5), fontWeight: FontWeight.bold, fontSize: 16))),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () => _handleStatusUpdate('accepted'),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 15))],
                ),
                child: Center(child: Text('Accept Request', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.5, curve: Curves.easeOutQuart, duration: 800.ms).fadeIn();
  }

}
