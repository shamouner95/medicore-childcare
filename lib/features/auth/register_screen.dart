import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_app/auth_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hospital_app/core/services/gemini_ai_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Patient Health Profile Controllers
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

  // Hospital Controllers
  final _hospitalSpecializationController = TextEditingController();
  final _hospitalAddressController = TextEditingController();
  double? _latitude;
  double? _longitude;

  String _selectedRole = 'patient';
  String? _selectedSpeciality;
  File? _imageFile;
  bool _isLoading = false;
  bool _isAILoading = false;
  final GeminiAIService _geminiService = GeminiAIService();

  final List<String> _specialities = [
    'General Pediatrics',
    'Pediatric Cardiology',
    'Pediatric Neurology',
    'Pediatric Orthopedics',
    'Pediatric Surgery',
    'Neonatology',
    'Pediatric Emergency Medicine',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Crop Profile Picture'),
        ],
      );
      if (croppedFile != null) {
        setState(() => _imageFile = File(croppedFile.path));
      }
    }
  }

  Future<String?> _uploadImage(String uid) async {
    if (_imageFile == null) return null;
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_images')
        .child('$uid.jpg');
    await ref.putFile(_imageFile!);
    return await ref.getDownloadURL();
  }

  Future<void> _fillWithAI() async {
    final promptController = TextEditingController();
    final prompt = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('AI Auto-fill',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold, color: AppColors.textDeep)),
        content: TextField(
          controller: promptController,
          maxLines: 4,
          style: const TextStyle(color: AppColors.textDeep),
          decoration: InputDecoration(
            hintText:
                'Describe your health status (e.g., "I am a 25 year old male, blood group A+, no allergies...")',
            hintStyle: const TextStyle(color: AppColors.secondary),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.secondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, promptController.text),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Process', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (prompt == null || prompt.isEmpty) return;

    setState(() => _isAILoading = true);

    try {
      final data = await _geminiService.extractPatientData(prompt);

      setState(() {
        if (data.name != null && _nameController.text.isEmpty)
          _nameController.text = data.name!;
        if (data.bloodGroup != null)
          _bloodGroupController.text = data.bloodGroup!;
        if (data.genotype != null) _genotypeController.text = data.genotype!;
        if (data.vaccinationStatus != null)
          _vaccinationController.text = data.vaccinationStatus!;
        if (data.heartRate != null)
          _heartRateController.text = data.heartRate.toString();
        if (data.weight != null)
          _weightController.text = data.weight.toString();
        if (data.height != null)
          _heightController.text = data.height.toString();
        if (data.allergies != null) _allergiesController.text = data.allergies!;
        if (data.chronicConditions != null)
          _chronicConditionsController.text = data.chronicConditions!;
        if (data.dob != null) _dobController.text = data.dob!;
        if (data.gender != null) _genderController.text = data.gender!;
        if (data.emergencyContact != null)
          _emergencyContactController.text = data.emergencyContact!;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('AI Extraction failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAILoading = false);
    }
  }

  String _generateQRData() {
    final data = {
      'name': _nameController.text,
      'blood': _bloodGroupController.text,
      'genotype': _genotypeController.text,
      'vax': _vaccinationController.text,
      'hr': _heartRateController.text,
      'allergies': _allergiesController.text,
      'emergency': _emergencyContactController.text,
    };
    return jsonEncode(data);
  }

  int _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _register() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.isEmpty) return;
    if (_selectedRole == 'doctor' && _selectedSpeciality == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a speciality')));
      return;
    }

    if (_selectedRole == 'patient' && _dobController.text.isNotEmpty) {
      try {
        final dob = DateTime.parse(_dobController.text);
        if (_calculateAge(dob) >= 18) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Registration is restricted to pediatric patients (under 18 years old)')),
          );
          return;
        }
      } catch (e) {
        // Handle parsing errors for non-standard date strings
      }
    }

    setState(() => _isLoading = true);
    try {
      Map<String, dynamic>? extraData;
      String? speciality =
          _selectedRole == 'doctor' ? _selectedSpeciality : null;

      if (_selectedRole == 'patient') {
        extraData = {
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
          'qrData': _generateQRData(),
          'onboardingCompleted': true,
        };
      } else if (_selectedRole == 'hospital') {
        speciality = _hospitalSpecializationController.text;
        extraData = {
          'address': _hospitalAddressController.text,
          'latitude': _latitude,
          'longitude': _longitude,
          'isVerified': false,
        };
      } else if (_selectedRole == 'health_worker') {
        extraData = {
          'isVerified': false,
          'organization': 'UNICEF Affiliate', // Default for now
          'contributionCount': 0,
        };
      }

      await ref.read(authRepositoryProvider).register(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            name: _nameController.text.trim(),
            role: _selectedRole,
            speciality: speciality,
            extraData: extraData,
          );

      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null && _imageFile != null) {
        final imageUrl = await _uploadImage(user.uid);
        if (mounted) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'profileImageUrl': imageUrl,
          });
        }
      }

      if (mounted) {
        context.go('/');
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildDecorativeOrbs(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: isTablet ? 600 : double.infinity),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 48.0 : 24.0,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildBackButton(context),
                      const SizedBox(height: 40),
                      Text(
                        'Create Account',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textDeep,
                          fontSize: isTablet ? 44 : 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                        ),
                      ).animate().fadeIn().slideX(begin: -0.1),
                      const SizedBox(height: 32),
                      Center(child: _buildImagePicker()),
                      const SizedBox(height: 40),
                      _buildTextField(
                          _nameController, 'Full Name', Icons.person_outline),
                      const SizedBox(height: 16),
                      _buildTextField(_emailController, 'Email Address',
                          Icons.email_outlined),
                      const SizedBox(height: 16),
                      _buildTextField(
                          _passwordController, 'Password', Icons.lock_outline,
                          isPassword: true),
                      const SizedBox(height: 32),
                      _buildRoleSelector(),
                      if (_selectedRole == 'doctor') ...[
                        const SizedBox(height: 24),
                        _buildSpecialityDropdown(),
                      ],
                      if (_selectedRole == 'hospital') ...[
                        const SizedBox(height: 24),
                        _buildHospitalFields(),
                      ],
                      if (_selectedRole == 'patient') ...[
                        const SizedBox(height: 32),
                        _buildPatientHealthForm(isTablet),
                        const SizedBox(height: 32),
                        _buildQRPreview(),
                      ],
                      const SizedBox(height: 48),
                      _buildRegisterButton(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorativeOrbs() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .scale(
                duration: 4.seconds,
                begin: const Offset(1, 1),
                end: const Offset(1.2, 1.2),
                curve: Curves.easeInOut,
              )
              .then()
              .scale(begin: const Offset(1.2, 1.2), end: const Offset(1, 1)),
        ),
      ],
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: AppColors.softShadow,
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.textDeep, size: 20),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppColors.softShadow,
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2), width: 2),
              image: _imageFile != null
                  ? DecorationImage(
                      image: FileImage(_imageFile!), fit: BoxFit.cover)
                  : null,
            ),
            child: _imageFile == null
                ? const Icon(Icons.add_a_photo_outlined,
                    size: 32, color: AppColors.primary)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                  color: AppColors.accent, shape: BoxShape.circle),
              child: const Icon(Icons.edit, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildRoleCard('patient', 'Patient', Icons.person_search_outlined),
          const SizedBox(width: 16),
          _buildRoleCard('doctor', 'Doctor', Icons.medical_services_outlined),
          const SizedBox(width: 16),
          _buildRoleCard(
              'health_worker', 'Health Worker', Icons.engineering_outlined),
        ],
      ),
    );
  }

  Widget _buildRoleCard(String role, String label, IconData icon) {
    bool isSelected = _selectedRole == role;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        width: 120, // Give it a fixed width inside the horizontal scroll
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark ? [] : AppColors.softShadow,
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : AppColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : AppColors.textDeep),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientHealthForm(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Health Profile',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textDeep,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _isAILoading ? null : _fillWithAI,
              icon: _isAILoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_isAILoading ? 'Processing...' : 'Auto-fill with AI'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Complete your medical profile for better care.',
          style: TextStyle(color: AppColors.secondary, fontSize: 14),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Basic Information'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildTextField(_dobController, 'Date of Birth',
                    Icons.calendar_today_outlined)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildTextField(_genderController, 'Gender', Icons.wc)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildTextField(_bloodGroupController, 'Blood Group',
                    Icons.bloodtype_outlined)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildTextField(
                    _genotypeController, 'Genotype', Icons.science_outlined)),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(_vaccinationController, 'Vaccination Status',
            Icons.vaccines_outlined),
        const SizedBox(height: 16),
        _buildTextField(_emergencyContactController, 'Emergency Contact',
            Icons.contact_phone_outlined),
        const SizedBox(height: 32),
        _buildSectionTitle('Vitals & Metrics'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildTextField(_heartRateController, 'Heart Rate (bpm)',
                    Icons.favorite_border)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildTextField(_weightController, 'Weight (kg)',
                    Icons.monitor_weight_outlined)),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(_heightController, 'Height (cm)', Icons.height),
        const SizedBox(height: 32),
        _buildSectionTitle('Medical History'),
        const SizedBox(height: 16),
        _buildTextField(
            _allergiesController, 'Allergies', Icons.warning_amber_rounded),
        const SizedBox(height: 16),
        _buildTextField(
            _chronicConditionsController, 'Chronic Conditions', Icons.history),
      ],
    );
  }

  Widget _buildQRPreview() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: isDark ? [] : AppColors.softShadow,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            'Health ID Preview',
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? Colors.white : AppColors.textDeep,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          QrImageView(
            data: _generateQRData(),
            version: QrVersions.auto,
            size: 160.0,
            gapless: false,
            foregroundColor: isDark ? Colors.white : AppColors.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Contains your encrypted medical vitals.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        color: AppColors.primary,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {bool isPassword = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? [] : AppColors.softShadow,
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: TextStyle(color: isDark ? Colors.white : AppColors.textDeep),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: isDark ? Colors.white30 : AppColors.secondary),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(24),
        ),
      ),
    );
  }

  Widget _buildHospitalFields() {
    return Column(
      children: [
        _buildTextField(
            _hospitalSpecializationController,
            'Specializations (e.g. Surgery, Pediatrics)',
            Icons.local_hospital_outlined),
        const SizedBox(height: 16),
        _buildTextField(_hospitalAddressController, 'Hospital Address',
            Icons.location_on_outlined),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            // Simplified: In a real app, use a location picker screen
            // For now, let's mock selecting a location
            setState(() {
              _latitude = 6.5244; // Default to Lagos for demo
              _longitude = 3.3792;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location selected (Lagos Mock)')),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.softShadow,
              border: Border.all(
                  color: _latitude != null
                      ? AppColors.primary
                      : Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(Icons.map_outlined,
                    color: _latitude != null
                        ? AppColors.primary
                        : AppColors.secondary),
                const SizedBox(width: 12),
                Text(
                  _latitude != null
                      ? 'Location Set ($_latitude, $_longitude)'
                      : 'Set Hospital Location',
                  style: TextStyle(
                      color: _latitude != null
                          ? AppColors.primary
                          : AppColors.secondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialityDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _selectedSpeciality,
          hint: const Text('Select Speciality',
              style: TextStyle(color: AppColors.secondary)),
          dropdownColor: Colors.white,
          decoration: const InputDecoration(border: InputBorder.none),
          items: _specialities
              .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s,
                      style: const TextStyle(color: AppColors.textDeep))))
              .toList(),
          onChanged: (val) => setState(() => _selectedSpeciality = val),
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _register,
      child: Container(
        height: 72,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.premiumGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  'Create Account',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
    );
  }
}
