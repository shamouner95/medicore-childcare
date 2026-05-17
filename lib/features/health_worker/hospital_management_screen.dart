import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'hospital_full_management_screen.dart';

class HospitalManagementScreen extends ConsumerStatefulWidget {
  const HospitalManagementScreen({super.key});

  @override
  ConsumerState<HospitalManagementScreen> createState() => _HospitalManagementScreenState();
}

class _HospitalManagementScreenState extends ConsumerState<HospitalManagementScreen> {
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Text('Manage Facilities', style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.textLight : AppColors.textDeep,
        )),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business_rounded, color: AppColors.primary),
            onPressed: () => _showAddHospitalDialog(context, isDark),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('users').where('role', isEqualTo: 'hospital').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_hospital_outlined, size: 64, color: AppColors.secondary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('No hospitals registered yet.', style: GoogleFonts.plusJakartaSans(color: AppColors.secondary)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              return _buildHospitalCard(data, doc.id, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildHospitalCard(Map<String, dynamic> data, String id, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    data['name'] ?? 'Unknown Hospital',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      color: isDark ? AppColors.textLight : AppColors.textDeep
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data['speciality'] ?? 'General',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.secondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    data['address'] ?? 'No address provided',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.secondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildStatItem(Icons.person_outline, '${data['doctorCount'] ?? 0}', 'Doctors', isDark),
                    const SizedBox(width: 20),
                    _buildStatItem(Icons.king_bed_outlined, '${data['bedSpaces'] ?? 0}', 'Beds', isDark),
                    const SizedBox(width: 20),
                    _buildStatItem(Icons.verified_user_outlined, data['isVerified'] == true ? 'Yes' : 'No', 'Verified', isDark),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings_suggest_outlined, color: AppColors.secondary, size: 20),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HospitalFullManagementScreen(
                              hospitalId: id,
                              hospitalName: data['name'] ?? 'Hospital',
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                      onPressed: () => _showEditHospitalDialog(context, id, data, isDark),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () => _showDeleteConfirmDialog(context, id, data['name'] ?? 'Hospital'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX();
  }

  Future<void> _showDeleteConfirmDialog(BuildContext context, String id, String name) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Facility?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove "$name"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await _db.collection('users').doc(id).delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditHospitalDialog(BuildContext context, String id, Map<String, dynamic> data, bool isDark) async {
    final nameController = TextEditingController(text: data['name']);
    final addressController = TextEditingController(text: data['address']);
    final doctorsController = TextEditingController(text: data['doctorCount']?.toString());
    final bedsController = TextEditingController(text: data['bedSpaces']?.toString());
    final specialityController = TextEditingController(text: data['speciality']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        title: Text('Edit Facility', style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.textLight : AppColors.textDeep,
        )),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameController, 'Hospital Name', Icons.business, isDark),
              const SizedBox(height: 12),
              _buildDialogField(specialityController, 'Speciality', Icons.category, isDark),
              const SizedBox(height: 12),
              _buildDialogField(addressController, 'Address', Icons.map, isDark),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildDialogField(doctorsController, 'Doctors', Icons.people, isDark, isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDialogField(bedsController, 'Beds', Icons.bed, isDark, isNumber: true)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _db.collection('users').doc(id).update({
                'name': nameController.text,
                'speciality': specialityController.text,
                'address': addressController.text,
                'doctorCount': int.tryParse(doctorsController.text) ?? 0,
                'bedSpaces': int.tryParse(bedsController.text) ?? 0,
              });
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, bool isDark) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.bold, 
          fontSize: 14, 
          color: isDark ? AppColors.textLight : AppColors.textDeep
        )),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.secondary)),
      ],
    );
  }

  Future<void> _showAddHospitalDialog(BuildContext context, bool isDark) async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final doctorsController = TextEditingController();
    final bedsController = TextEditingController();
    final specialityController = TextEditingController();
    double lat = 6.5244;
    double lng = 3.3792;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        title: Text('Register New Facility', style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.textLight : AppColors.textDeep,
        )),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameController, 'Hospital Name', Icons.business, isDark),
              const SizedBox(height: 12),
              _buildDialogField(specialityController, 'Speciality', Icons.category, isDark),
              const SizedBox(height: 12),
              _buildDialogField(addressController, 'Address', Icons.map, isDark),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildDialogField(doctorsController, 'Doctors', Icons.people, isDark, isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDialogField(bedsController, 'Beds', Icons.bed, isDark, isNumber: true)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Defaulting to current location for demo (Lagos)', style: TextStyle(fontSize: 10, color: AppColors.secondary)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _db.collection('users').add({
                'name': nameController.text,
                'role': 'hospital',
                'speciality': specialityController.text,
                'address': addressController.text,
                'doctorCount': int.tryParse(doctorsController.text) ?? 0,
                'bedSpaces': int.tryParse(bedsController.text) ?? 0,
                'latitude': lat,
                'longitude': lng,
                'isVerified': true,
                'createdAt': FieldValue.serverTimestamp(),
                'contributedBy': FirebaseAuth.instance.currentUser?.uid,
              });
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Register', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(TextEditingController controller, String hint, IconData icon, bool isDark, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: isDark ? AppColors.textLight : AppColors.textDeep),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white38 : AppColors.secondary),
        prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
        filled: true,
        fillColor: isDark ? Colors.white10 : AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
