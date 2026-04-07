import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../home/data/models/user_model.dart';

class EmployeeModel {
  final String uid;
  final String officeId;
  final String employeeCode;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String role;
  final bool adminFlag;
  final String department;
  final String jobTitle;
  final String specialization;
  final int graduationYear;
  final DateTime joinDate;
  final String status;
  final double rating;
  final String notes;
  final bool isActive;
  final DateTime createdAt;
  final String? linkedClientId;

  // ── Schedule & Leave Settings ──────────────────────────────────────────────
  final int annualLeaveDays;
  final bool hasCustomSchedule;
  final List<String> customWorkDays;
  final String customStartTime;
  final String customEndTime;
  final Map<String, Map<String, String>> dayOverrides;
  final bool exemptFromRules;

  // ── Reporting Chain ────────────────────────────────────────────────────────
  final String? reportToUserId;
  final String? reportToName;
  final String? reportToJobTitle;

  // ── HR Fields ──────────────────────────────────────────────────────────────
  // contractType: 'permanent' | 'contract' | 'part_time'
  final String contractType;
  final DateTime? contractEndDate; // null للعقود الدائمة
  final String emergencyContact;
  final String nationalId;

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
    this.linkedClientId,
    this.annualLeaveDays = 21,
    this.hasCustomSchedule = false,
    this.customWorkDays = const [],
    this.customStartTime = '',
    this.customEndTime = '',
    this.dayOverrides = const {},
    this.exemptFromRules = false,
    this.reportToUserId,
    this.reportToName,
    this.reportToJobTitle,
    this.contractType = 'permanent',
    this.contractEndDate,
    this.emergencyContact = '',
    this.nationalId = '',
  });

  bool get isAdmin => adminFlag || role == 'admin';

  /// true إذا كان العقد سينتهي خلال 60 يوم القادمة
  bool get isContractExpiringSoon {
    if (contractEndDate == null) return false;
    final daysLeft = contractEndDate!.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 60;
  }

  /// true إذا كان العقد منتهياً
  bool get isContractExpired {
    if (contractEndDate == null) return false;
    return contractEndDate!.isBefore(DateTime.now());
  }
  bool get isEngineer => role == 'engineer';
  bool get isTeamLeader => role == 'team_leader';
  bool get isReviewer => role == 'reviewer';
  bool get isClient => role == 'client';

  String get jobTitleLabel => JobTitles.labelOf(jobTitle);

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Active';
      case 'suspended':
        return 'Suspended';
      case 'resigned':
        return 'Resigned';
      default:
        return status;
    }
  }

  String get roleLabel {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'team_leader':
        return 'Team Leader';
      case 'reviewer':
        return 'Reviewer';
      case 'engineer':
        return 'Engineer';
      case 'client':
        return 'Client';
      default:
        return role;
    }
  }

  String get departmentLabel => department;

  factory EmployeeModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return EmployeeModel(
      uid: d['uid'] ?? doc.id,
      officeId: d['officeId'] ?? '',
      employeeCode: d['employeeCode'] ?? '',
      name: d['name'] ?? '',
      email: d['email'] ?? '',
      phone: d['phone'] ?? '',
      address: d['address'] ?? '',
      role: d['role'] ?? 'engineer',
      adminFlag: d['adminFlag'] ?? (d['role'] == 'admin'),
      department: d['department'] ?? '',
      jobTitle: d['jobTitle'] ?? '',
      specialization: d['specialization'] ?? '',
      graduationYear: d['graduationYear'] ?? 0,
      joinDate: (d['joinDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: d['status'] ?? 'active',
      rating: (d['rating'] ?? 0).toDouble(),
      notes: d['notes'] ?? '',
      isActive: d['isActive'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      linkedClientId: d['linkedClientId'] as String?,
      annualLeaveDays: (d['annualLeaveDays'] as num?)?.toInt() ?? 21,
      hasCustomSchedule: d['hasCustomSchedule'] as bool? ?? false,
      customWorkDays: List<String>.from(d['customWorkDays'] ?? []),
      customStartTime: d['customStartTime'] as String? ?? '',
      customEndTime: d['customEndTime'] as String? ?? '',
      dayOverrides: _parseDayOverrides(d['dayOverrides']),
      exemptFromRules: d['exemptFromRules'] as bool? ?? false,
      reportToUserId: d['reportToUserId'] as String?,
      reportToName: d['reportToName'] as String?,
      reportToJobTitle: d['reportToJobTitle'] as String?,
      contractType: d['contractType'] as String? ?? 'permanent',
      contractEndDate: (d['contractEndDate'] as Timestamp?)?.toDate(),
      emergencyContact: d['emergencyContact'] as String? ?? '',
      nationalId: d['nationalId'] as String? ?? '',
    );
  }

  static Map<String, Map<String, String>> _parseDayOverrides(dynamic raw) {
    if (raw == null) return {};
    final m = raw as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(k, Map<String, String>.from(v as Map)));
  }

  Map<String, dynamic> toFirestore() => {
    'uid': uid,
    'officeId': officeId,
    'employeeCode': employeeCode,
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'role': role,
    'adminFlag': adminFlag,
    'department': department,
    'jobTitle': jobTitle,
    'specialization': specialization,
    'graduationYear': graduationYear,
    'joinDate': Timestamp.fromDate(joinDate),
    'status': status,
    'rating': rating,
    'notes': notes,
    'isActive': isActive,
    'createdAt': Timestamp.fromDate(createdAt),
    if (linkedClientId != null && linkedClientId!.isNotEmpty)
      'linkedClientId': linkedClientId,
    'annualLeaveDays': annualLeaveDays,
    'hasCustomSchedule': hasCustomSchedule,
    'customWorkDays': customWorkDays,
    'customStartTime': customStartTime,
    'customEndTime': customEndTime,
    'dayOverrides': dayOverrides,
    'exemptFromRules': exemptFromRules,
    if (reportToUserId != null && reportToUserId!.isNotEmpty)
      'reportToUserId': reportToUserId,
    if (reportToName != null && reportToName!.isNotEmpty)
      'reportToName': reportToName,
    if (reportToJobTitle != null && reportToJobTitle!.isNotEmpty)
      'reportToJobTitle': reportToJobTitle,
    'contractType': contractType,
    if (contractEndDate != null)
      'contractEndDate': Timestamp.fromDate(contractEndDate!),
    'emergencyContact': emergencyContact,
    'nationalId': nationalId,
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
    String? linkedClientId,
    int? annualLeaveDays,
    bool? hasCustomSchedule,
    List<String>? customWorkDays,
    String? customStartTime,
    String? customEndTime,
    Map<String, Map<String, String>>? dayOverrides,
    bool? exemptFromRules,
    String? reportToUserId,
    String? reportToName,
    String? reportToJobTitle,
    bool clearReportTo = false,
    String? contractType,
    DateTime? contractEndDate,
    bool clearContractEndDate = false,
    String? emergencyContact,
    String? nationalId,
  }) {
    return EmployeeModel(
      uid: uid ?? this.uid,
      officeId: officeId ?? this.officeId,
      employeeCode: employeeCode ?? this.employeeCode,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      role: role ?? this.role,
      adminFlag: adminFlag ?? this.adminFlag,
      department: department ?? this.department,
      jobTitle: jobTitle ?? this.jobTitle,
      specialization: specialization ?? this.specialization,
      graduationYear: graduationYear ?? this.graduationYear,
      joinDate: joinDate ?? this.joinDate,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      linkedClientId: linkedClientId ?? this.linkedClientId,
      annualLeaveDays: annualLeaveDays ?? this.annualLeaveDays,
      hasCustomSchedule: hasCustomSchedule ?? this.hasCustomSchedule,
      customWorkDays: customWorkDays ?? this.customWorkDays,
      customStartTime: customStartTime ?? this.customStartTime,
      customEndTime: customEndTime ?? this.customEndTime,
      dayOverrides: dayOverrides ?? this.dayOverrides,
      exemptFromRules: exemptFromRules ?? this.exemptFromRules,
      reportToUserId: clearReportTo ? null : (reportToUserId ?? this.reportToUserId),
      reportToName: clearReportTo ? null : (reportToName ?? this.reportToName),
      reportToJobTitle: clearReportTo ? null : (reportToJobTitle ?? this.reportToJobTitle),
      contractType: contractType ?? this.contractType,
      contractEndDate: clearContractEndDate ? null : (contractEndDate ?? this.contractEndDate),
      emergencyContact: emergencyContact ?? this.emergencyContact,
      nationalId: nationalId ?? this.nationalId,
    );
  }
}
