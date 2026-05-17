
class AppUser {
  final String id;
  final String email;
  final String role;
  final String? specialization;

  AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.specialization,
  });

  factory AppUser.fromMap(String id, Map<String, dynamic> data) {
    return AppUser(
      id: id,
      email: data['email'] ?? '',
      role: data['role'] ?? 'patient',
      specialization: data['specialization'],
    );
  }
}
