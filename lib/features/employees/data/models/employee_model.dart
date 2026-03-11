import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../home/data/models/user_model.dart'; // للـ JobTitles class

class EmployeeModel {
  final String uid;
  final String officeId;
  final String employeeCode;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String role;
  final bool adminFlag;        // ✅ جديد
  final String department;
  final String jobTitle;       // key من JobTitles
  final String specialization;
  final int graduationYear;
  final DateTime joinDate;
  final String status;
  final double rating;
  final String notes;
  final bool isActive;
  final DateTime createdAt;

  const EmployeeModel({
    required this.uid,
    required this.officeId,
    required this.employeeCode,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.role,
    required this.adminFlag,
    required this.department,
    required this.jobTitle,
    required this.specialization,
    required this.graduationYear,
    required this.joinDate,
    required this.status,
    required this.rating,
    required this.notes,
    required this.isActive,
    required this.createdAt,
  });

  // ── Role helpers ───────────────────────────────────────────────────────────
  bool get isAdmin      => adminFlag || role == 'admin';
  bool get isEngineer   => role == 'engineer';
  bool get isTeamLeader => role == 'team_leader';
  bool get isReviewer   => role == 'reviewer';
  bool get isClient     => role == 'client';

  // ── Labels ─────────────────────────────────────────────────────────────────
  String get jobTitleLabel => JobTitles.labelOf(jobTitle);

  String get statusLabel {
    switch (status) {
      case 'active':    return 'Active';
      case 'suspended': return 'Suspended';
      case 'resigned':  return 'Resigned';
      default:          return status;
    }
  }

  String get roleLabel {
    switch (role) {
      case 'admin':        return 'Admin';
      case 'team_leader':  return 'Team Leader';
      case 'reviewer':     return 'Reviewer';
      case 'engineer':     return 'Engineer';
      case 'client':       return 'Client';
      default:             return role;
    }
  }

  String get departmentLabel => department;

  // ── Firestore ──────────────────────────────────────────────────────────────
  factory EmployeeModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return EmployeeModel(
      uid:            d['uid'] ?? doc.id,
      officeId:       d['officeId'] ?? '',
      employeeCode:   d['employeeCode'] ?? '',
      name:           d['name'] ?? '',
      email:          d['email'] ?? '',
      phone:          d['phone'] ?? '',
      address:        d['address'] ?? '',
      role:           d['role'] ?? 'engineer',
      adminFlag:      d['adminFlag'] ?? (d['role'] == 'admin'),
      department:     d['department'] ?? '',
      jobTitle:       d['jobTitle'] ?? '',
      specialization: d['specialization'] ?? '',
      graduationYear: d['graduationYear'] ?? 0,
      joinDate:       (d['joinDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status:         d['status'] ?? 'active',
      rating:         (d['rating'] ?? 0).toDouble(),
      notes:          d['notes'] ?? '',
      isActive:       d['isActive'] ?? true,
      createdAt:      (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'uid':            uid,
    'officeId':       officeId,
    'employeeCode':   employeeCode,
    'name':           name,
    'email':          email,
    'phone':          phone,
    'address':        address,
    'role':           role,
    'adminFlag':      adminFlag,
    'department':     department,
    'jobTitle':       jobTitle,
    'specialization': specialization,
    'graduationYear': graduationYear,
    'joinDate':       Timestamp.fromDate(joinDate),
    'status':         status,
    'rating':         rating,
    'notes':          notes,
    'isActive':       isActive,
    'createdAt':      Timestamp.fromDate(createdAt),
  };

  EmployeeModel copyWith({
    String? uid,
    String? officeId,
    String? employeeCode,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? role,
    bool? adminFlag,
    String? department,
    String? jobTitle,
    String? specialization,
    int? graduationYear,
    DateTime? joinDate,
    String? status,
    double? rating,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return EmployeeModel(
      uid:            uid ?? this.uid,
      officeId:       officeId ?? this.officeId,
      employeeCode:   employeeCode ?? this.employeeCode,
      name:           name ?? this.name,
      email:          email ?? this.email,
      phone:          phone ?? this.phone,
      address:        address ?? this.address,
      role:           role ?? this.role,
      adminFlag:      adminFlag ?? this.adminFlag,
      department:     department ?? this.department,
      jobTitle:       jobTitle ?? this.jobTitle,
      specialization: specialization ?? this.specialization,
      graduationYear: graduationYear ?? this.graduationYear,
      joinDate:       joinDate ?? this.joinDate,
      status:         status ?? this.status,
      rating:         rating ?? this.rating,
      notes:          notes ?? this.notes,
      isActive:       isActive ?? this.isActive,
      createdAt:      createdAt ?? this.createdAt,
    );
  }
}
