import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String officeId;
  final String employeeCode;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool adminFlag;
  final String department;
  final String jobTitle;
  final String status;
  final bool isActive;
  final DateTime createdAt;
  final String? linkedClientId;
  final String? notes;
  final double rating;

  const UserModel({
    required this.uid,
    required this.officeId,
    required this.employeeCode,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.adminFlag,
    required this.department,
    required this.jobTitle,
    required this.status,
    required this.isActive,
    required this.createdAt,
    this.linkedClientId,
    this.notes,
    this.rating = 0,
  });

  // ── Role flags ─────────────────────────────────────────────────────────────
  bool get isAdmin => adminFlag || role == 'admin';
  bool get isTeamLeader => role == 'team_leader';
  bool get isReviewer => role == 'reviewer';
  bool get isEngineer => role == 'engineer';
  bool get isClient => role == 'client';
  bool get isManagement => role == 'management';
  bool get isAdministration => role == 'administration';
  bool get isDC => role == 'dc';

  /// Sees all projects/tasks regardless of assignment.
  /// Admin + QC + Management + DC + senior job titles
  bool get canSeeAllProjects =>
      isAdmin ||
      isReviewer ||
      isManagement ||
      isDC ||
      jobTitle == 'head_of_department' ||
      jobTitle == 'coo' ||
      jobTitle == 'principal_managing_partner' ||
      jobTitle == 'technical_office_manager';

  /// Can create/edit tasks (TL creates, Admin manages)
  /// ⚠️ Use isTeamLeader directly for TL-specific logic
  bool get canManageTasks => isAdmin || isTeamLeader;

  bool get canReview => isReviewer || isManagement;
  bool get canSeeTasks => !isClient && !isAdministration;
  bool get canOnlyAttendance => isAdministration;

  /// Who can see the Reports tab (project + task reports)
  bool get canSeeProjectReports =>
      isAdmin || isManagement || isReviewer ||
      jobTitle == 'head_of_department' ||
      jobTitle == 'coo' ||
      jobTitle == 'principal_managing_partner' ||
      jobTitle == 'technical_office_manager' ||
      isTeamLeader || isEngineer || isDC;

  /// Who can see sensitive employee/payroll reports
  bool get canSeeEmployeeReports =>
      isAdmin || isManagement ||
      jobTitle == 'head_of_department' ||
      jobTitle == 'coo' ||
      jobTitle == 'principal_managing_partner' ||
      jobTitle == 'technical_office_manager';

  /// Senior management for dashboard
  bool get isSeniorManagement =>
      isAdmin || isManagement ||
      jobTitle == 'coo' ||
      jobTitle == 'principal_managing_partner' ||
      jobTitle == 'technical_office_manager' ||
      jobTitle == 'head_of_department';

  String get roleLabel {
    switch (role) {
      case 'admin':          return 'Admin';
      case 'team_leader':    return 'Team Leader';
      case 'reviewer':       return 'Reviewer';
      case 'engineer':       return 'Engineer';
      case 'client':         return 'Client';
      case 'management':     return 'Management';
      case 'administration': return 'Administration';
      case 'dc':             return 'Document Controller';
      default:               return role;
    }
  }

  String get jobTitleLabel => JobTitles.labelOf(jobTitle);

  String jobTitleLabelFrom(Map<String, String>? customTitles) {
    if (customTitles != null && customTitles.containsKey(jobTitle)) {
      return customTitles[jobTitle]!;
    }
    return JobTitles.labelOf(jobTitle);
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid:          d['uid'] ?? doc.id,
      officeId:     d['officeId'] ?? '',
      employeeCode: d['employeeCode'] ?? '',
      name:         d['name'] ?? '',
      email:        d['email'] ?? '',
      phone:        d['phone'] ?? '',
      role:         d['role'] ?? 'engineer',
      adminFlag:    d['adminFlag'] ?? (d['role'] == 'admin'),
      department:   d['department'] ?? '',
      jobTitle:     d['jobTitle'] ?? '',
      status:       d['status'] ?? 'active',
      isActive:     d['isActive'] ?? true,
      createdAt:    (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      linkedClientId: d['linkedClientId'],
      notes:        d['notes'],
      rating:       ((d['rating'] ?? 0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'uid':          uid,
    'officeId':     officeId,
    'employeeCode': employeeCode,
    'name':         name,
    'email':        email,
    'phone':        phone,
    'role':         role,
    'adminFlag':    adminFlag,
    'department':   department,
    'jobTitle':     jobTitle,
    'status':       status,
    'isActive':     isActive,
    'createdAt':    Timestamp.fromDate(createdAt),
    'linkedClientId': linkedClientId,
    'notes':        notes ?? '',
    'rating':       rating,
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// Job Titles
// ══════════════════════════════════════════════════════════════════════════════

class JobTitleGroup {
  final String title;
  final Map<String, String> titles;
  const JobTitleGroup({required this.title, required this.titles});
}

class JobTitles {
  static const Map<String, String> executiveManagement = {
    'principal_managing_partner': 'Principal / Managing Partner',
    'coo':                        'Chief Operations Officer (COO)',
    'technical_office_manager':   'Technical Office Manager',
  };
  static const Map<String, String> middleManagement = {
    'project_manager':              'Project Manager (PM)',
    'head_of_department':           'Head of Department',
    'planning_scheduling_manager':  'Planning & Scheduling Manager',
  };
  static const Map<String, String> technicalStaff = {
    'senior_design_engineer': 'Senior Design Engineer',
    'design_engineer':        'Design Engineer',
    'site_engineer':          'Site Engineer',
    'site_supervisor':        'Site Supervisor',
    'junior_engineer':        'Junior Engineer',
  };
  static const Map<String, String> bimTechnical = {
    'bim_manager':     'BIM Manager',
    'bim_coordinator': 'BIM Coordinator',
    'chief_draftsman': 'Chief Draftsman',
    'cad_bim_modeler': 'CAD Technician / BIM Modeler',
  };
  static const Map<String, String> qualityCost = {
    'quantity_surveyor':    'Quantity Surveyor (QS)',
    'qc_engineer':          'Quality Control Engineer (QC)',
    'business_dev_engineer':'Business Development Engineer',
  };
  static const Map<String, String> nonEngineering = {
    'chief_accountant': 'Chief Accountant',
    'accountant':       'Accountant',
    'office_admin':     'Office Administrator',
    'hr':               'HR',
    'legal_officer':    'Legal Officer',
    'document_controll':'Document Controller',
  };

  static List<JobTitleGroup> get groups => [
    JobTitleGroup(title: 'Executive Management',   titles: executiveManagement),
    JobTitleGroup(title: 'Middle Management',       titles: middleManagement),
    JobTitleGroup(title: 'Technical Staff',         titles: technicalStaff),
    JobTitleGroup(title: 'BIM & Technical Support', titles: bimTechnical),
    JobTitleGroup(title: 'Quality & Cost Control',  titles: qualityCost),
    JobTitleGroup(title: 'Non-Engineering',         titles: nonEngineering),
  ];

  static Map<String, String> get all => {
    ...executiveManagement,
    ...middleManagement,
    ...technicalStaff,
    ...bimTechnical,
    ...qualityCost,
    ...nonEngineering,
  };

  static String labelOf(String key) => all[key] ?? key;
}
