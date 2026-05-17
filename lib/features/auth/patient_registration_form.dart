import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_app/auth_repository.dart';
import 'package:hospital_app/core/services/gemini_ai_service.dart';
import 'package:hospital_app/core/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class PatientRegistrationForm extends ConsumerStatefulWidget {
  const PatientRegistrationForm({super.key});

  @override
  ConsumerState<PatientRegistrationForm> createState() => _PatientRegistrationFormState();
}

class _PatientRegistrationFormState extends ConsumerState<PatientRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _genotypeController = TextEditingController();
  final _vaccinationController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _chronicConditionsController = TextEditingController();
  final _dobController = TextEditingController();
  final _genderController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  bool _isLoading = false;
  bool _isAILoading = false;
  final GeminiAIService _geminiService = GeminiAIService();

  @override
  void dispose() {
    _nameController.dispose();
    _bloodGroupController.dispose();
    _genotypeController.dispose();
    _vaccinationController.dispose();
    _heartRateController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _allergiesController.dispose();
    _chronicConditionsController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _fillWithAI() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo of a medical report'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return;

    setState(() => _isAILoading = true);

    try {
      final bytes = await pickedFile.readAsBytes();
      final data = await _geminiService.extractPatientData("Extract data from this medical record", imageBytes: bytes);
      
      setState(() {
        if (data.name != null) _nameController.text = data.name!;
        if (data.bloodGroup != null) _bloodGroupController.text = data.bloodGroup!;
        if (data.genotype != null) _genotypeController.text = data.genotype!;
        if (data.vaccinationStatus != null) _vaccinationController.text = data.vaccinationStatus!;
        if (data.heartRate != null) _heartRateController.text = data.heartRate.toString();
        if (data.weight != null) _weightController.text = data.weight.toString();
        if (data.height != null) _heightController.text = data.height.toString();
        if (data.allergies != null) _allergiesController.text = data.allergies!;
        if (data.chronicConditions != null) _chronicConditionsController.text = data.chronicConditions!;
        if (data.dob != null) _dobController.text = data.dob!;
        if (data.gender != null) _genderController.text = data.gender!;
        if (data.emergencyContact != null) _emergencyContactController.text = data.emergencyContact!;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Form populated using AI analysis'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI extraction failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAILoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
          final data = {
            'name': _nameController.text,
            'bloodGroup': _bloodGroupController.text,
            'genotype': _genotypeController.text,
            'vaccinationStatus': _vaccinationController.text,
            'heartRate': int.tryParse(_heartRateController.text),
            'weight': double.tryParse(_weightController.text),
            'height': double.tryParse(_heightController.text),
            'allergies': _allergiesController.text,
            'chronicConditions': _chronicConditionsController.text,
            'dob': _dobController.text,
            'gender': _genderController.text,
            'emergencyContact': _emergencyContactController.text,
            'onboardingCompleted': true,
          };

        await FirebaseFirestore.instance.collection('users').doc(user.uid).update(data);
        
        if (mounted) {
          _showQRCodeDialog(data);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showQRCodeDialog(Map<String, dynamic> data) {
    // Select 7 details for QR code
    final qrData = {
      'Name': data['name'],
      'Blood': data['bloodGroup'],
      'Geno': data['genotype'],
      'Vax': data['vaccinationStatus'],
      'Weight': '${data['weight']}kg',
      'Allergies': data['allergies'],
      'ID': ref.read(authRepositoryProvider).currentUser?.uid.substring(0, 8),
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Text(
            'Digital Health ID',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your medical profile is ready. Show this QR code to medical personnel.'),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              width: 200,
              child: QrImageView(
                data: jsonEncode(qrData),
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Profile Saved Successfully',
              style: GoogleFonts.plusJakartaSans(color: Colors.green, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/');
            },
            child: const Text('Go to Dashboard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Text('Health Profile', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textDeep)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isAILoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: AppColors.accent),
              onPressed: _fillWithAI,
              tooltip: 'Fill with Gemini AI',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complete Your Medical Profile',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Help us provide better care by filling in your medical details.',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Basic Information'),
              _buildTextField(_nameController, 'Full Name', Icons.person_outline, isDark),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField(_dobController, 'Date of Birth', Icons.calendar_today_outlined, isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_genderController, 'Gender', Icons.wc, isDark)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField(_bloodGroupController, 'Blood Group', Icons.bloodtype_outlined, isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_genotypeController, 'Genotype', Icons.science_outlined, isDark)),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(_vaccinationController, 'Vaccination Status', Icons.vaccines_outlined, isDark),
              const SizedBox(height: 16),
              _buildTextField(_emergencyContactController, 'Emergency Contact', Icons.contact_phone_outlined, isDark),
              const SizedBox(height: 32),
              _buildSectionTitle('Vitals & Measurements'),
              Row(
                children: [
                  Expanded(child: _buildTextField(_heartRateController, 'Heart Rate (bpm)', Icons.favorite_outline, isDark, keyboardType: TextInputType.number)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_weightController, 'Weight (kg)', Icons.monitor_weight_outlined, isDark, keyboardType: TextInputType.number)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_heightController, 'Height (cm)', Icons.height, isDark, keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Medical History'),
              _buildTextField(_allergiesController, 'Allergies', Icons.warning_amber_rounded, isDark, maxLines: 2),
              const SizedBox(height: 16),
              _buildTextField(_chronicConditionsController, 'Chronic Conditions', Icons.history_edu, isDark, maxLines: 2),
              const SizedBox(height: 48),
              _buildSubmitButton(isDark),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.accent,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String hint, 
    IconData icon, 
    bool isDark, 
    {TextInputType keyboardType = TextInputType.text, int maxLines = 1}
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.blue.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.primary.withValues(alpha: 0.05)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: isDark ? Colors.white : AppColors.textDeep),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.white30 : AppColors.textDeep.withValues(alpha: 0.3)),
          prefixIcon: Icon(icon, color: isDark ? Colors.white30 : AppColors.primary.withValues(alpha: 0.3), size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
        validator: (value) {
          if (hint == 'Full Name' && (value == null || value.isEmpty)) {
            return 'Please enter your name';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return GestureDetector(
      onTap: _isLoading ? null : _submit,
      child: Container(
        height: 64,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.black)
              : Text(
                  'Save Profile & Generate QR',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
