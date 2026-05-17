import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_app/auth_repository.dart';
import 'package:hospital_app/core/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import 'package:hospital_app/core/theme/theme_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final VoidCallback? onHomePressed;
  const ProfileScreen({super.key, this.onHomePressed});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  String? _selectedSpeciality;
  bool _isLoading = false;

  final List<String> _specialities = [
    'Cardiology', 'Pediatrics', 'Neurology', 'Orthopedics', 'General Medicine', 'Dermatology', 'Psychiatry'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  Future<void> _updateProfileImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

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
      setState(() => _isLoading = true);
      try {
        final uid = ref.read(authRepositoryProvider).currentUser?.uid;
        if (uid == null) return;

        final refStorage = FirebaseStorage.instance.ref().child('profile_images').child('$uid.jpg');
        await refStorage.putFile(File(croppedFile.path));
        final url = await refStorage.getDownloadURL();

        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'profileImageUrl': url,
        });
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      final updates = {
        'name': _nameController.text.trim(),
      };
      if (_selectedSpeciality != null) {
        updates['speciality'] = _selectedSpeciality!;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update(updates);
      setState(() => _isEditing = false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          if (!_isEditing) {
             _nameController.text = userData['name'] ?? '';
             _selectedSpeciality = userData['speciality'];
          }

          final bool isDoctor = userData['role'] == 'doctor';
          final bool isHealthWorker = userData['role'] == 'health_worker';
          final String uniqueId = userData['uniqueId'] ?? (isHealthWorker ? 'HWK-PENDING' : 'ID-PENDING');

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildHeader(userData, isDark),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildUniqueIdCard(uniqueId, isDoctor, isHealthWorker),
                      const SizedBox(height: 24),
                      _buildInfoCard(userData, isDark),
                      const SizedBox(height: 32),
                      if (_isEditing)
                        _buildActionButtons()
                      else
                        _buildEditToggle(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> data, bool isDark) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: [
        if (widget.onHomePressed != null)
          _buildGlassHeaderButton(
            Icons.dashboard_rounded,
            widget.onHomePressed!,
          ),
        _buildGlassHeaderButton(
          ref.watch(themeProvider) == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          () => ref.read(themeProvider.notifier).toggleTheme(),
        ),
        _buildGlassHeaderButton(
          Icons.logout_rounded,
          () => ref.read(authRepositoryProvider).signOut(),
        ),
        const SizedBox(width: 12),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.premiumGradient,
          ),
          child: Stack(
            children: [
              Positioned(
                top: -50,
                right: -50,
                child: CircleAvatar(radius: 100, backgroundColor: Colors.white.withValues(alpha: 0.05)),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    _buildProfileImage(data['profileImageUrl']),
                    const SizedBox(height: 16),
                    Text(
                      data['name'] ?? 'User Name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      data['email'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white70),
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

  Widget _buildGlassHeaderButton(IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildProfileImage(String? url) {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
            image: url != null && url.isNotEmpty
                ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                : const DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200'),
                    fit: BoxFit.cover,
                  ),
          ),
          child: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.white)) : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _updateProfileImage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
              child: const Icon(Icons.edit, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    ).animate().scale(delay: 200.ms, curve: Curves.bounceOut);
  }

  Widget _buildUniqueIdCard(String id, bool isDoctor, bool isHealthWorker) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isHealthWorker 
          ? LinearGradient(colors: [Colors.teal.shade400, Colors.teal.shade700])
          : (isDoctor ? AppColors.accentGradient : AppColors.premiumGradient),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: (isHealthWorker ? Colors.teal : (isDoctor ? AppColors.accent : AppColors.primary)).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
            child: Icon(
              isHealthWorker ? Icons.verified_rounded : (isDoctor ? Icons.medical_services : Icons.badge), 
              color: Colors.white, 
              size: 30
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHealthWorker ? 'Field Intelligence ID' : (isDoctor ? 'Doctor License ID' : 'Medical Health ID'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                Text(
                  id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2),
                ),
              ],
            ),
          ),
          const Icon(Icons.qr_code_2, color: Colors.white, size: 40),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> data, bool isDark) {
    bool isDoctor = data['role'] == 'doctor';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: isDark ? null : AppColors.softShadow,
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.primary.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          _buildInfoRow('Full Name', _nameController, Icons.person_outline, editable: _isEditing, isDark: isDark),
          Divider(height: 40, color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.primary.withValues(alpha: 0.05)),
          _buildInfoRow('Speciality', TextEditingController(text: _selectedSpeciality ?? 'General Specialist'), Icons.medical_information_outlined,
            editable: _isEditing && isDoctor, isDropdown: isDoctor, isDark: isDark),
          Divider(height: 40, color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.primary.withValues(alpha: 0.05)),
          _buildInfoRow('Account Type', TextEditingController(text: data['role']?.toString().toUpperCase()), Icons.verified_user_outlined, editable: false, isDark: isDark),
          Divider(height: 40, color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.primary.withValues(alpha: 0.05)),
          _buildInfoRow('Join Date', TextEditingController(text: 'Oct 2023'), Icons.calendar_today_outlined, editable: false, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, TextEditingController controller, IconData icon, {required bool editable, bool isDropdown = false, required bool isDark}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label, 
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 4),
              if (editable)
                if (isDropdown)
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSpeciality,
                      isExpanded: true,
                      dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.textLight : AppColors.textDeep),
                      hint: const Text('Select Speciality'),
                      items: _specialities.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) => setState(() => _selectedSpeciality = val),
                    ),
                  )
                else
                  TextField(
                    controller: controller,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.textLight : AppColors.textDeep),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  )
              else
                Text(
                  controller.text, 
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.textLight : AppColors.textDeep)
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditToggle() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => setState(() => _isEditing = true),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 8,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
        ),
        child: const Text('Edit Profile Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => setState(() => _isEditing = false),
            child: const Text('Discard', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(vertical: 20),
            ),
            child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
