import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hospital_app/auth_repository.dart';
import 'package:hospital_app/features/auth/register_screen.dart';
import 'package:hospital_app/features/auth/forgot_password_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hospital_app/features/patient/symptom_checker_screen.dart';
import 'package:hospital_app/features/patient/health_id_screen.dart';
import 'package:hospital_app/features/patient/booking_screen.dart';
import 'package:hospital_app/features/patient/prescriptions_screen.dart';
import 'package:hospital_app/features/patient/test_results_screen.dart';
import 'package:hospital_app/features/patient/chat_screen.dart';
import 'package:hospital_app/features/patient/ai_insights_screen.dart';
import 'package:hospital_app/features/patient/map_screen.dart';
import 'package:hospital_app/features/patient/health_journey_screen.dart';
import 'package:hospital_app/features/doctor/doctor_list_screen.dart';
import 'package:hospital_app/features/doctor/referral_screen.dart';

import 'package:hospital_app/features/doctor/doctor_home.dart';
import 'package:hospital_app/features/hospital/hospital_home.dart';
import 'package:hospital_app/features/hospital/hospital_profile_view.dart';
import '../../features/auth/login_screen.dart';
import '../../features/doctor/doctor_chat_list_screen.dart';
import '../../home_screen.dart';

import 'package:hospital_app/features/doctor/clinical_forecast_screen.dart';
import 'package:hospital_app/features/admin/broadcast_alert_screen.dart';
import 'package:hospital_app/features/welcome_screen.dart';
import 'package:hospital_app/features/health_worker/health_worker_home.dart';

import 'package:hospital_app/features/profile/profile_screen.dart';

import 'package:hospital_app/features/patient/billing_screen.dart';

import 'package:hospital_app/features/patient/patient_appointments_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Watch the auth state stream to trigger router rebuilds on auth changes
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/welcome',
    redirect: (context, state) {
      // If the authentication state is still loading, don't redirect yet
      if (authState.isLoading || authState.hasError) return null;

      // Determine if the user is logged in
      final isAuthenticated = authState.value != null;

      // Determine if the user is currently navigating to the login screen
      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToRegister = state.matchedLocation == '/register';
      final isGoingToWelcome = state.matchedLocation == '/welcome';

      // Rule 1: Unauthenticated users going anywhere besides welcome/login/register are redirected to welcome
      if (!isAuthenticated && !isGoingToLogin && !isGoingToRegister && !isGoingToWelcome) {
        return '/welcome';
      }

      // Rule 2: Authenticated users trying to go to welcome/login/register are redirected to home
      if (isAuthenticated && (isGoingToLogin || isGoingToRegister || isGoingToWelcome)) {
        return '/';
      }

      // No redirect needed
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return const LoginScreen();
          
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final role = data['role'] ?? 'patient';
                
                if (role == 'doctor') {
                  return const DoctorHomeScreen();
                }
                if (role == 'hospital') {
                  return const HospitalHomeScreen();
                }
                if (role == 'health_worker') {
                  // We'll create this screen next
                  return const HealthWorkerHomeScreen();
                }
              }
              return const HomeScreen();
            },
          );
        },
      ),
      GoRoute(
        path: '/symptoms',
        builder: (context, state) => const SymptomCheckerScreen(),
      ),
      GoRoute(
        path: '/health-id',
        builder: (context, state) => const HealthIDScreen(),
      ),
      GoRoute(
        path: '/book',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return BookingScreen(
            initialSymptoms: extra?['symptoms'],
            specialty: extra?['specialty'],
            initialDoctorId: extra?['doctorId'],
            hospitalId: extra?['hospitalId'],
          );
        },
      ),
      GoRoute(
        path: '/prescriptions',
        builder: (context, state) => const PrescriptionsScreen(),
      ),
      GoRoute(
        path: '/results',
        builder: (context, state) => const TestResultsScreen(),
      ),
      GoRoute(
        path: '/billing',
        builder: (context, state) => const BillingScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ChatScreen(
            doctorId: extra?['doctorId'],
            doctorName: extra?['doctorName'],
          );
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/ai-insights',
        builder: (context, state) => const AIInsightsScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return MapScreen(
            initialSymptoms: extra?['symptoms'],
          );
        },
      ),
      GoRoute(
        path: '/appointments',
        builder: (context, state) => const PatientAppointmentsScreen(),
      ),
      GoRoute(
        path: '/health-journey',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return HealthJourneyScreen(
            appointmentId: extra?['appointmentId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/doctor-chats',
        builder: (context, state) => const DoctorChatListScreen(),
      ),
      GoRoute(
        path: '/doctors',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return DoctorListScreen(
            initialSymptoms: extra?['symptoms'],
            initialDepartment: extra?['department'],
          );
        },
      ),
      GoRoute(
        path: '/referral',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ReferralScreen(patientId: extra?['patientId']);
        },
      ),
      GoRoute(
        path: '/clinical-forecast',
        builder: (context, state) => const ClinicalForecastScreen(),
      ),
      GoRoute(
        path: '/broadcast-alert',
        builder: (context, state) => const BroadcastAlertScreen(),
      ),
      GoRoute(
        path: '/hospital/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return HospitalProfileView(hospitalId: id);
        },
      ),
    ],
  );
});
