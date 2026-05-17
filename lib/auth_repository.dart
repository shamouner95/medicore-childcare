import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider));
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

class AuthRepository {
  final FirebaseAuth _auth;
  final _db = FirebaseFirestore.instance;

  AuthRepository(this._auth);

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String role,
    String? speciality, // For doctors or hospitals (comma separated for hospitals)
    String? profileImageUrl,
    Map<String, dynamic>? extraData,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;

    // Generate a shorter, human-readable Unique ID (e.g., MED-12345)
    String prefix = 'PAT';
    if (role == 'doctor') prefix = 'DOC';
    if (role == 'hospital') prefix = 'HSP';
    if (role == 'health_worker') prefix = 'HWK';
    
    final String uniqueId = '$prefix-${uid.substring(0, 5).toUpperCase()}';
    
    final userData = {
      'uid': uid,
      'uniqueId': uniqueId,
      'name': name,
      'email': email,
      'role': role,
      'speciality': speciality,
      'profileImageUrl': profileImageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (extraData != null) {
      userData.addAll(extraData);
    }

    await _db.collection('users').doc(uid).set(userData);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
