import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/staff_provider.dart';

class HospitalFullManagementScreen extends ConsumerStatefulWidget {
  final String hospitalId;
  final String hospitalName;

  const HospitalFullManagementScreen({
    super.key,
    required this.hospitalId,
    required this.hospitalName,
  });

  @override
  ConsumerState<HospitalFullManagementScreen> createState() => _HospitalFullManagementScreenState();
}

class _HospitalFullManagementScreenState extends ConsumerState<HospitalFullManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Text(widget.hospitalName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? Colors.white70 : AppColors.secondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Schedule'),
            Tab(text: 'Staff'),
            Tab(text: 'Profile'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _HospitalScheduleTab(hospitalId: widget.hospitalId),
          _HospitalStaffTab(hospitalId: widget.hospitalId),
          _HospitalProfileTab(hospitalId: widget.hospitalId),
        ],
      ),
    );
  }
}

class _HospitalScheduleTab extends ConsumerStatefulWidget {
  final String hospitalId;
  const _HospitalScheduleTab({required this.hospitalId});

  @override
  ConsumerState<_HospitalScheduleTab> createState() => _HospitalScheduleTabState();
}

class _HospitalScheduleTabState extends ConsumerState<_HospitalScheduleTab> {
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  List<String> _selectedDays = [];
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.hospitalId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final schedule = data['schedule'] as Map<String, dynamic>?;
      if (schedule != null) {
        setState(() {
          _selectedDays = List<String>.from(schedule['days'] ?? []);
          _startTimeController.text = schedule['startTime'] ?? '';
          _endTimeController.text = schedule['endTime'] ?? '';
        });
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Working Days', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textDeep)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _days.map((day) {
              final isSelected = _selectedDays.contains(day);
              return FilterChip(
                label: Text(day, style: GoogleFonts.plusJakartaSans(color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textDeep))),
                selected: isSelected,
                selectedColor: AppColors.primary,
                checkmarkColor: Colors.white,
                backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                onSelected: (selected) {
                  setState(() {
                    if (selected) _selectedDays.add(day);
                    else _selectedDays.remove(day);
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start Time', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textDeep)),
                    const SizedBox(height: 8),
                    _buildTimeField(_startTimeController, '08:00 AM', isDark),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('End Time', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textDeep)),
                    const SizedBox(height: 8),
                    _buildTimeField(_endTimeController, '05:00 PM', isDark),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('users').doc(widget.hospitalId).update({
                  'schedule': {
                    'days': _selectedDays,
                    'startTime': _startTimeController.text,
                    'endTime': _endTimeController.text,
                  }
                });
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule updated!')));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('Save Schedule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeField(TextEditingController controller, String hint, bool isDark) {
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : AppColors.textDeep),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey),
        filled: true,
        fillColor: isDark ? Colors.white10 : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

class _HospitalStaffTab extends ConsumerWidget {
  final String hospitalId;
  const _HospitalStaffTab({required this.hospitalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final staffAsync = ref.watch(staffProvider(hospitalId));
    final requestsAsync = ref.watch(staffRequestsProvider(hospitalId));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Current Staff', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textDeep)),
            IconButton(
              onPressed: () => _showAddDoctorDialog(context, hospitalId),
              icon: const Icon(Icons.person_add_alt_1, color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        staffAsync.when(
          data: (doctors) => doctors.isEmpty 
              ? const Text('No doctors registered') 
              : Column(children: doctors.map((d) => _buildDoctorCard(context, d, isDark)).toList()),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
        const SizedBox(height: 32),
        Text('Pending Applications', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textDeep)),
        const SizedBox(height: 16),
        requestsAsync.when(
          data: (requests) => requests.isEmpty 
              ? const Text('No pending applications') 
              : Column(children: requests.map((r) => _buildRequestCard(r, isDark)).toList()),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  void _showAddDoctorDialog(BuildContext context, String hospitalId) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Doctor by Email'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(hintText: 'doctor@example.com'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final query = await FirebaseFirestore.instance
                  .collection('users')
                  .where('email', isEqualTo: emailController.text.trim())
                  .where('role', isEqualTo: 'doctor')
                  .get();
              
              if (query.docs.isEmpty) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor not found')));
                return;
              }

              await query.docs.first.reference.update({'hospitalId': hospitalId});
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor added to staff')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(BuildContext context, Map<String, dynamic> doctor, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? Colors.white10 : Colors.white,
      child: ListTile(
        leading: CircleAvatar(backgroundImage: NetworkImage(doctor['profileImageUrl'] ?? 'https://i.pravatar.cc/150?u=${doctor['id']}')),
        title: Text(doctor['name'], style: TextStyle(color: isDark ? Colors.white : AppColors.textDeep, fontWeight: FontWeight.bold)),
        subtitle: Text(doctor['speciality'] ?? 'General Specialty', style: TextStyle(color: isDark ? Colors.white70 : AppColors.secondary)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_note, color: AppColors.primary),
              onPressed: () => _showEditDoctorDialog(context, doctor),
            ),
            IconButton(
              icon: const Icon(Icons.person_remove, color: Colors.redAccent),
              onPressed: () => FirebaseFirestore.instance.collection('users').doc(doctor['id']).update({'hospitalId': FieldValue.delete()}),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDoctorDialog(BuildContext context, Map<String, dynamic> doctor) {
    final specController = TextEditingController(text: doctor['speciality']);
    final addressController = TextEditingController(text: doctor['address']);
    final startTimeController = TextEditingController(text: doctor['schedule']?['startTime'] ?? '09:00 AM');
    final endTimeController = TextEditingController(text: doctor['schedule']?['endTime'] ?? '05:00 PM');
    List<String> selectedDays = List<String>.from(doctor['schedule']?['days'] ?? []);
    final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit ${doctor['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: specController, decoration: const InputDecoration(labelText: 'Specialization')),
                TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Location/Address')),
                const SizedBox(height: 16),
                const Text('Doctor Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: days.map((day) {
                    final isSelected = selectedDays.contains(day);
                    return FilterChip(
                      label: Text(day, style: const TextStyle(fontSize: 10)),
                      selected: isSelected,
                      onSelected: (val) {
                        setDialogState(() {
                          if (val) selectedDays.add(day);
                          else selectedDays.remove(day);
                        });
                      },
                    );
                  }).toList(),
                ),
                Row(
                  children: [
                    Expanded(child: TextField(controller: startTimeController, decoration: const InputDecoration(labelText: 'Start'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: endTimeController, decoration: const InputDecoration(labelText: 'End'))),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('users').doc(doctor['id']).update({
                  'speciality': specController.text,
                  'address': addressController.text,
                  'schedule': {
                    'days': selectedDays,
                    'startTime': startTimeController.text,
                    'endTime': endTimeController.text,
                  }
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? Colors.white10 : Colors.white,
      child: ListTile(
        title: Text(req['fromName'], style: TextStyle(color: isDark ? Colors.white : AppColors.textDeep, fontWeight: FontWeight.bold)),
        subtitle: const Text('Wants to join staff'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.redAccent),
              onPressed: () => FirebaseFirestore.instance.collection('hospital_requests').doc(req['id']).update({'status': 'rejected'}),
            ),
            IconButton(
              icon: const Icon(Icons.check, color: AppColors.success),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('hospital_requests').doc(req['id']).update({'status': 'accepted'});
                await FirebaseFirestore.instance.collection('users').doc(req['fromId']).update({'hospitalId': hospitalId});
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HospitalProfileTab extends StatefulWidget {
  final String hospitalId;
  const _HospitalProfileTab({required this.hospitalId});

  @override
  State<_HospitalProfileTab> createState() => _HospitalProfileTabState();
}

class _HospitalProfileTabState extends State<_HospitalProfileTab> {
  final _descriptionController = TextEditingController();
  String? _imageUrl;
  bool _isUploading = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHospitalData();
  }

  Future<void> _loadHospitalData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.hospitalId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _imageUrl = data['profileImageUrl'];
        _descriptionController.text = data['description'] ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('hospital_backgrounds')
          .child('${widget.hospitalId}_bg.jpg');
      
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(widget.hospitalId).update({
        'profileImageUrl': url,
      });

      setState(() {
        _imageUrl = url;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Background image updated successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    await FirebaseFirestore.instance.collection('users').doc(widget.hospitalId).update({
      'description': _descriptionController.text,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hospital Background Image',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textDeep,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _isUploading ? null : _updateImage,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
                image: _imageUrl != null
                    ? DecorationImage(image: NetworkImage(_imageUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: Stack(
                children: [
                  if (_imageUrl == null)
                    const Center(child: Icon(Icons.add_a_photo, size: 40, color: AppColors.secondary)),
                  if (_isUploading)
                    const Center(child: CircularProgressIndicator()),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Hospital Description',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textDeep,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 5,
            style: TextStyle(color: isDark ? Colors.white : AppColors.textDeep),
            decoration: InputDecoration(
              hintText: 'Enter hospital description...',
              hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey),
              filled: true,
              fillColor: isDark ? Colors.white10 : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
