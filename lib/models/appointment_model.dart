import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String id;
  final String patientId;
  final String userName;
  final String doctorId;
  final String doctorName;
  final String symptoms;
  final String type; // Speciality
  final String appointmentDate; // yyyy-MM-dd
  final String appointmentTime; // hh:mm a
  final DateTime dateTime; // Combined date and time
  final String aiSummary;
  final String urgency;
  final String status;
  final String? rejectionReason;
  final String? prescription;
  final List<String>? labReports;
  final String? hospitalId;
  final String country;
  final DateTime? createdAt;

  Appointment({
    required this.id,
    required this.patientId,
    required this.userName,
    required this.doctorId,
    required this.doctorName,
    required this.symptoms,
    required this.type,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.dateTime,
    required this.aiSummary,
    required this.urgency,
    required this.status,
    this.rejectionReason,
    this.prescription,
    this.labReports,
    this.hospitalId,
    required this.country,
    this.createdAt,
  });

  factory Appointment.fromMap(String id, Map<String, dynamic> data) {
    return Appointment(
      id: id,
      patientId: data['patientId'] ?? '',
      userName: data['userName'] ?? 'Patient',
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? 'Doctor',
      symptoms: data['symptoms'] ?? '',
      type: data['type'] ?? 'General Consultation',
      appointmentDate: data['appointmentDate'] ?? '',
      appointmentTime: data['appointmentTime'] ?? '',
      dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      aiSummary: data['aiSummary'] ?? '',
      urgency: data['urgency'] ?? 'Low',
      status: data['status'] ?? 'pending',
      rejectionReason: data['rejectionReason'],
      prescription: data['prescription'],
      labReports: (data['labReports'] as List?)?.map((e) => e as String).toList(),
      hospitalId: data['hospitalId'],
      country: data['country'] ?? 'Global',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
