class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final String specialization;
  final String officeId;
  final bool isActive;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.specialization,
    required this.officeId,
    required this.isActive,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      role: map['role'] ?? 'engineer',
      specialization: map['specialization'] ?? '',
      officeId: map['officeId'] ?? '',
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role,
      'specialization': specialization,
      'officeId': officeId,
      'isActive': isActive,
    };
  }
}