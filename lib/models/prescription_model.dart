import 'package:cloud_firestore/cloud_firestore.dart';

class Prescription {
  final String id;
  final String patientId;
  final String doctorId;
  final String doctorName;
  final String diagnosis;
  final List<String> medicines;
  final DateTime date;

  Prescription({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    required this.diagnosis,
    required this.medicines,
    required this.date,
  });

  factory Prescription.fromMap(String id, Map<String, dynamic> map) {
    return Prescription(
      id: id,
      patientId: map['patientId'] ?? '',
      doctorId: map['doctorId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      diagnosis: map['diagnosis'] ?? '',
      medicines: List<String>.from(map['medicines'] ?? []),
      date: (map['date'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'diagnosis': diagnosis,
      'medicines': medicines,
      'date': Timestamp.fromDate(date),
    };
  }
}
