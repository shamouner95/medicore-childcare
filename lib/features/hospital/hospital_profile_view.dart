import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HospitalProfileView extends StatefulWidget {
  final String hospitalId;

  const HospitalProfileView({super.key, required this.hospitalId});

  @override
  State<HospitalProfileView> createState() => _HospitalProfileViewState();
}

class _HospitalProfileViewState extends State<HospitalProfileView> {
  String? _userRole;
  bool _isLoadingRole = true;
  Map<String, dynamic>? _hospitalData;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _userRole = doc.data()?['role'];
          _isLoadingRole = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingRole = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(widget.hospitalId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Hospital not found'));
          }

          _hospitalData = snapshot.data!.data() as Map<String, dynamic>;
          final data = _hospitalData!;
          final schedule = data['schedule'] as Map<String, dynamic>?;

          return CustomScrollView(
            slivers: [
              _buildAppBar(data),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection(data),
                      const SizedBox(height: 24),
                      _buildResourceBanner(data),
                      const SizedBox(height: 32),
                      _buildScheduleSection(schedule),
                      const SizedBox(height: 32),
                      _buildDoctorsSection(widget.hospitalId),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomSheet: _isLoadingRole ? const SizedBox.shrink() : _buildAction(context, widget.hospitalId, data: _hospitalData ?? {}),
    );
  }

  Widget _buildAppBar(Map<String, dynamic> data) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(data['name'] ?? 'Hospital Name',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              data['profileImageUrl'] ?? 'https://images.unsplash.com/photo-1586773860418-d3b9a8ec81a2?q=80&w=2073',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceBanner(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'FIELD RESOURCE STATUS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSimpleStat(Icons.people_outline, '${data['doctorCount'] ?? 0}', 'Doctors'),
              _buildSimpleStat(Icons.king_bed_outlined, '${data['bedSpaces'] ?? 0}', 'Bed Spaces'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Verified by Medicore Health Workers',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 24, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDeep)),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.secondary)),
      ],
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.medical_services, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(data['speciality'] ?? 'General Medical Center',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.location_on, color: AppColors.secondary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(data['address'] ?? 'Address not available',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.secondary)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('About', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          data['description'] ?? 'This hospital is committed to providing high-quality healthcare services with advanced medical technology and experienced staff.',
          style: const TextStyle(color: AppColors.secondary, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildScheduleSection(Map<String, dynamic>? schedule) {
    if (schedule == null) return const SizedBox.shrink();

    final days = (schedule['days'] as List<dynamic>?)?.join(', ') ?? 'N/A';
    final hours = '${schedule['startTime']} - ${schedule['endTime']}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_filled, color: AppColors.primary),
              const SizedBox(width: 12),
              Text('Available Schedule', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _buildScheduleRow('Days', days),
          const Divider(height: 24),
          _buildScheduleRow('Hours', hours),
        ],
      ),
    ).animate().slideX(begin: 0.1);
  }

  Widget _buildScheduleRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.secondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDeep)),
      ],
    );
  }

  Widget _buildDoctorsSection(String hospitalId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Available Doctors', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'doctor')
              .where('hospitalId', isEqualTo: hospitalId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            final doctors = snapshot.data!.docs;

            if (doctors.isEmpty) {
              return const Text('No doctors listed at this moment.', style: TextStyle(color: AppColors.secondary));
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: doctors.length,
              itemBuilder: (context, index) {
                final doctor = doctors[index].data() as Map<String, dynamic>;
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade100)),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(doctor['profileImageUrl'] ?? 'https://i.pravatar.cc/150?u=${doctor['name']}'),
                    ),
                    title: Text(doctor['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(doctor['speciality']),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Navigate to doctor details or start chat
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAction(BuildContext context, String hospitalId, {required Map<String, dynamic> data}) {
    if (_userRole == 'doctor') {
      return _buildApplyAction(context, hospitalId);
    }
    return _buildBookingAction(context, hospitalId);
  }

  Widget _buildBookingAction(BuildContext context, String hospitalId) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: ElevatedButton(
        onPressed: () {
          context.push('/book', extra: {'hospitalId': hospitalId});
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Book Appointment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildApplyAction(BuildContext context, String hospitalId) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('hospital_requests')
          .where('fromId', isEqualTo: user?.uid)
          .where('toId', isEqualTo: hospitalId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        final hasPendingRequest = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
          ),
          child: ElevatedButton(
            onPressed: hasPendingRequest ? null : () => _applyToHospital(context, hospitalId),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasPendingRequest ? Colors.grey : AppColors.accent,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              hasPendingRequest ? 'Application Pending' : 'Apply to Join Staff',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        );
      },
    );
  }

  Future<void> _applyToHospital(BuildContext context, String hospitalId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final hospitalDoc = await FirebaseFirestore.instance.collection('users').doc(hospitalId).get();

    await FirebaseFirestore.instance.collection('hospital_requests').add({
      'fromId': user.uid,
      'fromName': userDoc.data()?['name'] ?? 'Doctor',
      'fromRole': 'doctor',
      'toId': hospitalId,
      'toName': hospitalDoc.data()?['name'] ?? 'Hospital',
      'toRole': 'hospital',
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application sent successfully!')));
    }
  }
}
