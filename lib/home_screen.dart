import 'package:flutter/material.dart';
import 'package:hospital_app/features/patient/patient_home.dart';
import 'package:hospital_app/features/doctor/doctor_home.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final role = userData?['role'] ?? 'patient';

        if (role == 'doctor') {
          return const DoctorHomeScreen();
        } else {
          return const PatientHomeScreen();
        }
      },
    );
  }
}
