import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:hospital_app/providers/appointment_provider.dart';
import 'package:hospital_app/core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hospital_app/core/widgets/ai_processing_overlay.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hospital_app/core/services/gemini_ai_service.dart';

import '../../providers/country_provider.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final String? initialSymptoms;
  final String? specialty;
  final String? initialDoctorId;
  final String? hospitalId;
  const BookingScreen(
      {super.key,
      this.initialSymptoms,
      this.specialty,
      this.initialDoctorId,
      this.hospitalId});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  DateTime? _selectedDate;
  String? _selectedDoctorId;
  String? _selectedTime;
  String? _recommendedDoctorId;
  late final TextEditingController _symptomsController;
  bool _isSubmitting = false;
  final GeminiAIService _aiService = GeminiAIService();
  String? _selectedDepartment;

  @override
  void initState() {
    super.initState();
    _symptomsController = TextEditingController(text: widget.initialSymptoms);
    _selectedDepartment = widget.specialty;
    _selectedDoctorId = widget.initialDoctorId;
  }

  @override
  void dispose() {
    _symptomsController.dispose();
    super.dispose();
  }

  Future<void> _bookAppointment() async {
    if (_selectedDate == null ||
        _selectedDoctorId == null ||
        _selectedTime == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const AIProcessingOverlay(message: 'Securing your appointment...'),
    );

    final selectedCountry = ref.read(countryProvider);
    try {
      await ref.read(appointmentProvider.notifier).create(
            _selectedDoctorId!,
            _symptomsController.text.isEmpty
                ? "Routine checkup"
                : _symptomsController.text,
            _selectedDate!,
            _selectedTime!,
            country: selectedCountry,
          );

      if (mounted) {
        Navigator.pop(context); // Close overlay
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment Request Sent!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close overlay
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildWarmSliverHeader(isDark),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildSectionLabel('SELECT SPECIALIST'),
                      const SizedBox(height: 16),
                      _buildDoctorList(isDark),
                      const SizedBox(height: 32),
                      _buildSectionLabel('DESCRIBE SYMPTOMS'),
                      const SizedBox(height: 16),
                      _buildPremiumInput(isDark)
                          .animate()
                          .fadeIn(duration: 600.ms, curve: Curves.easeOutQuad)
                          .slideY(begin: 0.1, curve: Curves.easeOutQuad),
                      const SizedBox(height: 32),
                      _buildSectionLabel('CHOOSE DATE'),
                      const SizedBox(height: 16),
                      _buildDatePicker(isDark)
                          .animate()
                          .fadeIn(duration: 600.ms, curve: Curves.easeOutQuad)
                          .slideY(begin: 0.1, curve: Curves.easeOutQuad),
                      if (_selectedDate != null &&
                          _selectedDoctorId != null) ...[
                        const SizedBox(height: 32),
                        _buildSectionLabel('AVAILABLE SLOTS'),
                        const SizedBox(height: 16),
                        _buildTimeSlots(isDark),
                      ],
                      const SizedBox(height: 48),
                      _buildConfirmButton(isDark),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: AppColors.secondaryDark.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildWarmSliverHeader(bool isDark) {
    return SliverAppBar(
      expandedHeight: 140,
      collapsedHeight: 80,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12.0),
        child: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : AppColors.textDeep, size: 18),
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
                'BOOK APPOINTMENT',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Expert Care',
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

  Widget _buildPremiumInput(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.shelf),
      ),
      child: TextField(
        controller: _symptomsController,
        maxLines: 4,
        style: GoogleFonts.plusJakartaSans(
            color: isDark ? Colors.white : AppColors.textDeep, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'How are you feeling today?',
          hintStyle: GoogleFonts.plusJakartaSans(
              color: AppColors.secondaryDark.withValues(alpha: 0.4),
              fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(24),
        ),
      ),
    );
  }

  Widget _buildDoctorList(bool isDark) {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor');

    if (widget.hospitalId != null) {
      query = query.where('hospitalId', isEqualTo: widget.hospitalId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final doctors = snapshot.data!.docs;
        return Column(
          children: [
            if (_symptomsController.text.length > 10)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: _buildSmartMatchButton(doctors, isDark),
              ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: doctors.length,
                itemBuilder: (context, index) {
                  final docData = doctors[index].data() as Map<String, dynamic>;
                  final id = doctors[index].id;
                  final speciality = docData['speciality']?.toString() ?? '';
                  final isSelected = _selectedDoctorId == id;
                  final isRecommended = _recommendedDoctorId == id ||
                      (_selectedDepartment != null &&
                          speciality.toLowerCase() ==
                              _selectedDepartment!.toLowerCase());
                  final imageUrl = docData['profileImageUrl'];

                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedDoctorId = id;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 140,
                      margin: const EdgeInsets.only(right: 16, bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : (isDark ? AppColors.surfaceDark : Colors.white),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: isSelected ? AppColors.primary : AppColors.shelf),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          )
                        ] : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.4)
                                      : AppColors.shelf,
                                  width: 2),
                              image: DecorationImage(
                                image: imageUrl != null &&
                                        imageUrl.isNotEmpty
                                    ? NetworkImage(imageUrl)
                                    : const NetworkImage(
                                        'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=200'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            docData['name']?.split(' ').last ?? 'Doctor',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : AppColors.textDeep,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            docData['speciality'] ?? 'Specialist',
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected ? Colors.white70 : AppColors.secondaryDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isRecommended)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'AI MATCH',
                                style: GoogleFonts.plusJakartaSans(
                                  color: isSelected ? Colors.white : AppColors.primary,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSmartMatchButton(
      List<QueryDocumentSnapshot> doctors, bool isDark) {
    return GestureDetector(
      onTap: () async {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AIProcessingOverlay(
              message: 'Finding the best specialist...'),
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
            symptoms: _symptomsController.text,
            availableDoctors: docList,
          );

          final Map<String, dynamic> result = jsonDecode(recommendation);
          final String? recommendedId = result['recommendedDoctorId'];

          if (mounted) Navigator.pop(context);

          if (recommendedId == null || recommendedId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('AI could not determine a match.')),
            );
            return;
          }

          setState(() {
            _recommendedDoctorId = recommendedId;
            _selectedDoctorId = recommendedId;
          });
        } catch (e) {
          if (mounted) Navigator.pop(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 12),
            Text('SMART MATCH WITH AI',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(bool isDark) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 30)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: isDark ? AppColors.surfaceDark : Colors.white,
                  onSurface: isDark ? Colors.white : AppColors.textDeep,
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          setState(() {
            _selectedDate = date;
            _selectedTime = null;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.shelf),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedDate == null
                        ? 'Select Date'
                        : DateFormat('EEEE, MMM d').format(_selectedDate!),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _selectedDate == null
                          ? AppColors.secondaryDark.withValues(alpha: 0.4)
                          : AppColors.textDeep,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.expand_more_rounded, color: AppColors.shelf, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlots(bool isDark) {
    if (_selectedDate == null || _selectedDoctorId == null) {
      return const SizedBox();
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_selectedDoctorId)
          .collection('schedules')
          .doc(dateStr)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (!snapshot.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('No slots available for this date.',
                style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontWeight: FontWeight.w600)),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final slots = List<String>.from(data['slots'] ?? []);

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: slots.map((slot) {
            final isSelected = _selectedTime == slot;
            return GestureDetector(
              onTap: () => setState(() => _selectedTime = slot),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : (isDark ? AppColors.surfaceDark : Colors.white),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.shelf),
                ),
                child: Text(
                  slot,
                  style: GoogleFonts.plusJakartaSans(
                    color: isSelected ? Colors.white : AppColors.textDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildConfirmButton(bool isDark) {
    bool canSubmit = _selectedDate != null &&
        _selectedDoctorId != null &&
        _selectedTime != null;
    return GestureDetector(
      onTap: canSubmit ? _bookAppointment : null,
      child: Container(
        height: 64,
        width: double.infinity,
        decoration: BoxDecoration(
          color: canSubmit ? AppColors.primary : AppColors.shelf,
          borderRadius: BorderRadius.circular(16),
          boxShadow: canSubmit ? [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ] : [],
        ),
        child: Center(
          child: Text(
            'CONFIRM BOOKING',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1),
          ),
        ),
      ),
    );
  }
}
