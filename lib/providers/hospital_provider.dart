import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../core/services/gemini_ai_service.dart';
import 'notification_provider.dart';

final hospitalDashboardStatsProvider = StreamProvider<Map<String, String>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value({'doctors': '0', 'patients': '0', 'today': '0'});

  final doctorsStream = FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'doctor')
      .where('hospitalId', isEqualTo: user.uid)
      .snapshots();

  final appointmentsStream = FirebaseFirestore.instance
      .collection('appointments')
      .where('hospitalId', isEqualTo: user.uid)
      .snapshots();

  return doctorsStream.asyncMap((docSnapshot) async {
    final apptSnapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('hospitalId', isEqualTo: user.uid)
        .get();

    final docs = apptSnapshot.docs;
    final appts = docs.map((d) => d.data()).toList();
    
    final patientCount = appts.map((a) => a['patientId']).toSet().length.toString();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayCount = appts.where((a) => a['appointmentDate'] == todayStr).length.toString();
    
    return {
      'doctors': docSnapshot.docs.length.toString(),
      'patients': patientCount,
      'today': todayCount,
    };
  });
});

final hospitalAppointmentsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('appointments')
      .where('hospitalId', isEqualTo: user.uid)
      .orderBy('dateTime', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
});

final climateIntelligenceProvider = FutureProvider.autoDispose.family<ClimatePediatricSurge?, String>((ref, hospitalId) async {
  final aiService = GeminiAIService();
  
  try {
    // Fetch regional symptom trends
    final regionalSymptomsQuery = await FirebaseFirestore.instance
        .collectionGroup('symptom_history')
        .orderBy('timestamp', descending: true)
        .limit(30)
        .get();

    final regionalLogs = regionalSymptomsQuery.docs.map((doc) => {
      'symptoms': doc.get('symptoms'),
      'timestamp': (doc.get('timestamp') as Timestamp).toDate().toIso8601String(),
    }).toList();

    final forecast = await aiService.getClimatePediatricSurgeForecast(
      regionalSymptomTrends: regionalLogs,
      // Removed fixed country to support global context via provider state
    );

    // Trigger notification if risk is high or critical
    if (forecast.riskLevel == 'High' || forecast.riskLevel == 'Critical') {
      final recentAlerts = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: hospitalId)
          .where('type', isEqualTo: 'climate_alert')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      bool shouldSend = true;
      if (recentAlerts.docs.isNotEmpty) {
        final lastAlert = recentAlerts.docs.first.data();
        final lastTimestamp = (lastAlert['timestamp'] as Timestamp).toDate();
        final lastRisk = lastAlert['riskLevel'];
        
        // Only send if it's been more than 12 hours since the last alert OR risk level has changed
        if (DateTime.now().difference(lastTimestamp).inHours < 12 && lastRisk == forecast.riskLevel) {
          shouldSend = false;
        }
      }

      if (shouldSend) {
        await ref.read(notificationServiceProvider).sendClimateHealthAlert(
          userId: hospitalId,
          title: 'Pediatric Surge Risk: ${forecast.riskLevel}',
          body: forecast.insight,
          riskLevel: forecast.riskLevel,
          recommendation: forecast.recommendation,
        );
      }
    }

    return forecast;
  } catch (e) {
    print('Error in climateIntelligenceProvider: $e');
    return null;
  }
});
