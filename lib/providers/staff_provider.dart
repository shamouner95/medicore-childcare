import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final staffProvider = StreamProvider.family<List<Map<String, dynamic>>, String?>((ref, hospitalId) {
  final id = hospitalId ?? FirebaseAuth.instance.currentUser?.uid;
  if (id == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'doctor')
      .where('hospitalId', isEqualTo: id)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
});

final staffRequestsProvider = StreamProvider.family<List<Map<String, dynamic>>, String?>((ref, hospitalId) {
  final id = hospitalId ?? FirebaseAuth.instance.currentUser?.uid;
  if (id == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('hospital_requests')
      .where('toId', isEqualTo: id)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
});

final sentInvitationsProvider = StreamProvider.family<List<Map<String, dynamic>>, String?>((ref, hospitalId) {
  final id = hospitalId ?? FirebaseAuth.instance.currentUser?.uid;
  if (id == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('hospital_requests')
      .where('fromId', isEqualTo: id)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
});
