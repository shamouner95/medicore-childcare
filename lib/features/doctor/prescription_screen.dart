import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_app/core/theme/app_colors.dart';
import 'package:hospital_app/core/widgets/ai_processing_overlay.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hospital_app/models/prescription_model.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PrescriptionScreen extends ConsumerStatefulWidget {
  final String? prefilledPatientUniqueId;
  const PrescriptionScreen({super.key, this.prefilledPatientUniqueId});

  @override
  ConsumerState<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends ConsumerState<PrescriptionScreen> {
  final _patientIdController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _medicineController = TextEditingController();
  final List<String> _medicines = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledPatientUniqueId != null) {
      _patientIdController.text = widget.prefilledPatientUniqueId!;
    }
  }

  void _addMedicine() {
    if (_medicineController.text.isNotEmpty) {
      setState(() {
        _medicines.add(_medicineController.text.trim());
        _medicineController.clear();
      });
    }
  }

  Future<void> _submitPrescription() async {
    if (_patientIdController.text.isEmpty || _diagnosisController.text.isEmpty || _medicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and add at least one medicine')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AIProcessingOverlay(message: 'Generating Digital RX...'),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userData = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
      final doctorName = userData.data()?['name'] ?? 'Doctor';

      final patientQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('uniqueId', isEqualTo: _patientIdController.text.trim())
          .get();

      if (patientQuery.docs.isEmpty) throw 'Patient not found with this ID';

      final patientUid = patientQuery.docs.first.id;

      final prescription = Prescription(
        id: '',
        patientId: patientUid,
        doctorId: user!.uid,
        doctorName: doctorName,
        diagnosis: _diagnosisController.text.trim(),
        medicines: _medicines,
        date: DateTime.now(),
      );

      await FirebaseFirestore.instance.collection('prescriptions').add(prescription.toMap());

      if (mounted) {
        Navigator.pop(context); // Close overlay
        Navigator.pop(context); // Go back
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prescription sent successfully'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildPremiumHeader(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Patient Information').animate().fadeIn(duration: 500.ms).slideX(begin: -0.1),
                      const SizedBox(height: 16),
                      _buildTextField(_patientIdController, 'Patient Unique ID (e.g. PAT-12345)', Icons.badge_outlined).animate().fadeIn(duration: 600.ms, delay: 100.ms).slideY(begin: 0.1),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Clinical Diagnosis').animate().fadeIn(duration: 500.ms, delay: 200.ms).slideX(begin: -0.1),
                      const SizedBox(height: 16),
                      _buildTextField(_diagnosisController, 'Enter diagnosis summary...', Icons.medical_information_outlined, maxLines: 3).animate().fadeIn(duration: 600.ms, delay: 300.ms).slideY(begin: 0.1),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Prescribed Medications').animate().fadeIn(duration: 500.ms, delay: 400.ms).slideX(begin: -0.1),
                      const SizedBox(height: 16),
                      _buildMedicineInput().animate().fadeIn(duration: 600.ms, delay: 500.ms).slideY(begin: 0.1),
                      const SizedBox(height: 16),
                      _buildMedicineList(),
                      const SizedBox(height: 140),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: _buildSubmitButton().animate().fadeIn(duration: 600.ms, delay: 700.ms).scale(begin: const Offset(0.9, 0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: AppColors.softShadow,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDeep, size: 20),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.premiumGradient,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Write Prescription',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1),
                ),
                Text('Digital Healthcare Management', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title, 
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14, 
        fontWeight: FontWeight.w800, 
        color: AppColors.secondary,
        letterSpacing: 1.2,
      )
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.softShadow,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.plusJakartaSans(color: AppColors.textDeep, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.textDeep.withValues(alpha: 0.3)),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(24),
        ),
      ),
    );
  }

  Widget _buildMedicineInput() {
    return Row(
      children: [
        Expanded(child: _buildTextField(_medicineController, 'Add Medication', Icons.medication_outlined)),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _addMedicine,
          child: Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicineList() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _medicines.map((m) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.softShadow,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            Text(
              m, 
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textDeep, 
                fontWeight: FontWeight.bold
              )
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => setState(() => _medicines.remove(m)),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.red, size: 14),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 72,
      decoration: BoxDecoration(
        gradient: AppColors.premiumGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3), 
            blurRadius: 20, 
            offset: const Offset(0, 10)
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitPrescription,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(
              'Send Prescription',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white, 
                fontSize: 18, 
                fontWeight: FontWeight.bold
              ),
            ),
      ),
    );
  }
}
