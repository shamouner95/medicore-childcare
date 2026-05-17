import 'package:cloud_firestore/cloud_firestore.dart';

class TestResult {
  final String id;
  final String title;
  final DateTime date;
  final String status;
  final bool isNormal;
  final String labName;
  final String? reportUrl;

  TestResult({
    required this.id,
    required this.title,
    required this.date,
    required this.status,
    required this.isNormal,
    required this.labName,
    this.reportUrl,
  });

  factory TestResult.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TestResult(
      id: doc.id,
      title: data['title'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      status: data['status'] ?? '',
      isNormal: data['isNormal'] ?? true,
      labName: data['labName'] ?? '',
      reportUrl: data['reportUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'date': Timestamp.fromDate(date),
      'status': status,
      'isNormal': isNormal,
      'labName': labName,
      'reportUrl': reportUrl,
    };
  }
}
