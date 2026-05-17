import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';
import '../core/services/gemini_ai_service.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_provider.dart';

final appointmentProvider =
    StateNotifierProvider<AppointmentController, List<Appointment>>(
  (ref) => AppointmentController(ref),
);

class AppointmentController extends StateNotifier<List<Appointment>> {
  final Ref ref;
  AppointmentController(this.ref) : super([]) {
    _init();
  }

  final _db = FirebaseFirestore.instance;

  void _init() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _db.collection('appointments')
      .where(Filter.or(
        Filter('patientId', isEqualTo: user.uid),
        Filter('doctorId', isEqualTo: user.uid)
      ))
      .snapshots()
      .listen((snapshot) {
        final appointments = snapshot.docs
            .map((doc) => Appointment.fromMap(doc.id, doc.data()))
            .toList();
        
        // Sort by dateTime (soonest first)
        appointments.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        
        state = appointments;
      });
  }

  Future<void> create(String doctorId, String symptoms, DateTime date, String time, {String country = "Global"}) async {
    final user = FirebaseAuth.instance.currentUser!;
    final patientId = user.uid;

    // Fetch patient name
    final patientDoc = await _db.collection('users').doc(patientId).get();
    final patientName = patientDoc.data()?['name'] ?? 'Patient';

    // Fetch doctor's hospitalId and speciality
    final doctorDoc = await _db.collection('users').doc(doctorId).get();
    final doctorData = doctorDoc.data();
    final doctorName = doctorData?['name'] ?? 'Doctor';
    final hospitalId = doctorData?['hospitalId'];
    final speciality = doctorData?['speciality'] ?? 'General Consultation';

    final ai = GeminiAIService();
    final result = await ai.analyzeSymptoms(symptoms, country: country);

    final appointmentDateStr = DateFormat('yyyy-MM-dd').format(date);
    
    // Create a combined DateTime for easier sorting
    // time is usually "09:00 AM"
    final timeFormat = DateFormat('hh:mm a');
    final parsedTime = timeFormat.parse(time);
    final combinedDateTime = DateTime(date.year, date.month, date.day, parsedTime.hour, parsedTime.minute);

    final docRef = await _db.collection('appointments').add({
      'patientId': patientId,
      'userName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'hospitalId': hospitalId,
      'symptoms': symptoms,
      'type': speciality,
      'appointmentDate': appointmentDateStr,
      'appointmentTime': time,
      'date': DateFormat('MMM d, yyyy').format(date),
      'time': time,
      'dateTime': Timestamp.fromDate(combinedDateTime),
      'aiSummary': result.summary,
      'urgency': result.urgency,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'country': country,
    });

    // Send notification to doctor
    await ref.read(notificationServiceProvider).sendNotification(
      userId: doctorId,
      title: 'New Appointment Request',
      body: '$patientName has requested an appointment for $appointmentDateStr at $time',
      type: 'appointment',
      relatedId: docRef.id,
    );
  }

  Future<void> updateStatus(String id, String status, {String? reason}) async {
    await _db.collection('appointments').doc(id).update({
      'status': status,
      if (reason != null) 'rejectionReason': reason,
    });

    final appointment = state.firstWhere((a) => a.id == id);
    final isApproved = status == 'approved';
    
    await ref.read(notificationServiceProvider).sendNotification(
      userId: appointment.patientId,
      title: isApproved ? 'Appointment Approved' : 'Appointment Rejected',
      body: isApproved 
          ? 'Your appointment with Dr. ${appointment.doctorName} has been approved.'
          : 'Your appointment with Dr. ${appointment.doctorName} was rejected. Reason: ${reason ?? "No reason provided"}',
      type: 'appointment_status',
      relatedId: id,
    );
  }
}
