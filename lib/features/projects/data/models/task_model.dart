import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String officeId;
  final String projectId;
  final String projectName;

  // ── Task Info ──────────────────────────────────────────────────────────────
  final String title;
  final String description;
  final String category;      // من office_settings: taskCategories
  final String discipline;    // من office_settings: disciplines

  // ── Assignment ─────────────────────────────────────────────────────────────
  final String assignedTo;        // uid المهندس المنفذ
  final String assignedToName;    // اسمه للعرض
  final String teamLeaderId;      // uid الـ Team Leader
  final String teamLeaderName;
  final String reviewerId;        // uid الـ Reviewer
  final String reviewerName;

  // ── Dates ──────────────────────────────────────────────────────────────────
  final DateTime startDate;
  final DateTime endDate;

  // ── Hours ──────────────────────────────────────────────────────────────────
  final double plannedHours;
  final double actualHours;   // بيتحسب تلقائي من الـ daily_logs

  // ── Status ─────────────────────────────────────────────────────────────────
  // not_started / in_progress / under_review / completed
  final String status;

  // ── Approval ───────────────────────────────────────────────────────────────
  // pending / approved / approved_with_comments / rejected
  final String approvalStatus;
  final String approvalNotes;
  final DateTime? approvedAt;

  // ── Client Comments ────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> clientComments;

  // ── Meta ───────────────────────────────────────────────────────────────────
  final String createdBy;
  final DateTime createdAt;
  final String notes;

  const TaskModel({
    required this.id,
    required this.officeId,
    required this.projectId,
    required this.projectName,
    required this.title,
    required this.description,
    required this.category,
    required this.discipline,
    required this.assignedTo,
    required this.assignedToName,
    required this.teamLeaderId,
    required this.teamLeaderName,
    required this.reviewerId,
    required this.reviewerName,
    required this.startDate,
    required this.endDate,
    required this.plannedHours,
    required this.actualHours,
    required this.status,
    required this.approvalStatus,
    required this.approvalNotes,
    required this.approvedAt,
    required this.createdBy,
    required this.createdAt,
    required this.notes,
    this.clientComments = const [],
  });

  // ── Computed ───────────────────────────────────────────────────────────────
  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get isUnderReview => status == 'under_review';
  bool get isPendingApproval => approvalStatus == 'pending';
  bool get isApproved => approvalStatus == 'approved';
  bool get isRejected => approvalStatus == 'rejected';

  String get statusLabel {
    switch (status) {
      case 'not_started':       return 'Not Started';
      case 'in_progress':       return 'In Progress';
      case 'under_review':      return 'Under Review';
      case 'completed':         return 'Completed';
      default:                  return status;
    }
  }

  String get approvalLabel {
    switch (approvalStatus) {
      case 'pending':                 return 'Pending';
      case 'approved':                return 'Approved';
      case 'approved_with_comments':  return 'Approved with Comments';
      case 'rejected':                return 'Rejected';
      default:                        return approvalStatus;
    }
  }

  // ── Firestore ──────────────────────────────────────────────────────────────
  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id:                 doc.id,
      officeId:           d['officeId'] ?? '',
      projectId:          d['projectId'] ?? '',
      projectName:        d['projectName'] ?? '',
      title:              d['title'] ?? '',
      description:        d['description'] ?? '',
      category:           d['category'] ?? '',
      discipline:         d['discipline'] ?? '',
      assignedTo:         d['assignedTo'] ?? '',
      assignedToName:     d['assignedToName'] ?? '',
      teamLeaderId:       d['teamLeaderId'] ?? '',
      teamLeaderName:     d['teamLeaderName'] ?? '',
      reviewerId:         d['reviewerId'] ?? '',
      reviewerName:       d['reviewerName'] ?? '',
      startDate:          (d['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate:            (d['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      plannedHours:       (d['plannedHours'] ?? 0).toDouble(),
      actualHours:        (d['actualHours'] ?? 0).toDouble(),
      status:             d['status'] ?? 'not_started',
      approvalStatus:     d['approvalStatus'] ?? 'pending',
      approvalNotes:      d['approvalNotes'] ?? '',
      approvedAt:         (d['approvedAt'] as Timestamp?)?.toDate(),
      createdBy:          d['createdBy'] ?? '',
      createdAt:          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes:              d['notes'] ?? '',
      clientComments:     List<Map<String, dynamic>>.from(
                            (d['clientComments'] as List?)?.map((e) =>
                              Map<String, dynamic>.from(e as Map)) ?? [],
                          ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'officeId':         officeId,
      'projectId':        projectId,
      'projectName':      projectName,
      'title':            title,
      'description':      description,
      'category':         category,
      'discipline':       discipline,
      'assignedTo':       assignedTo,
      'assignedToName':   assignedToName,
      'teamLeaderId':     teamLeaderId,
      'teamLeaderName':   teamLeaderName,
      'reviewerId':       reviewerId,
      'reviewerName':     reviewerName,
      'startDate':        Timestamp.fromDate(startDate),
      'endDate':          Timestamp.fromDate(endDate),
      'plannedHours':     plannedHours,
      'actualHours':      actualHours,
      'status':           status,
      'approvalStatus':   approvalStatus,
      'approvalNotes':    approvalNotes,
      'approvedAt':       approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'createdBy':        createdBy,
      'createdAt':        Timestamp.fromDate(createdAt),
      'notes':            notes,
      'clientComments':   clientComments,
    };
  }

  // ── copyWith ───────────────────────────────────────────────────────────────
  TaskModel copyWith({
    String? title,
    String? description,
    String? category,
    String? discipline,
    String? assignedTo,
    String? assignedToName,
    String? teamLeaderId,
    String? teamLeaderName,
    String? reviewerId,
    String? reviewerName,
    DateTime? startDate,
    DateTime? endDate,
    double? plannedHours,
    double? actualHours,
    String? status,
    String? approvalStatus,
    String? approvalNotes,
    DateTime? approvedAt,
    String? notes,
    List<Map<String, dynamic>>? clientComments,
  }) {
    return TaskModel(
      id:                 id,
      officeId:           officeId,
      projectId:          projectId,
      projectName:        projectName,
      title:              title ?? this.title,
      description:        description ?? this.description,
      category:           category ?? this.category,
      discipline:         discipline ?? this.discipline,
      assignedTo:         assignedTo ?? this.assignedTo,
      assignedToName:     assignedToName ?? this.assignedToName,
      teamLeaderId:       teamLeaderId ?? this.teamLeaderId,
      teamLeaderName:     teamLeaderName ?? this.teamLeaderName,
      reviewerId:         reviewerId ?? this.reviewerId,
      reviewerName:       reviewerName ?? this.reviewerName,
      startDate:          startDate ?? this.startDate,
      endDate:            endDate ?? this.endDate,
      plannedHours:       plannedHours ?? this.plannedHours,
      actualHours:        actualHours ?? this.actualHours,
      status:             status ?? this.status,
      approvalStatus:     approvalStatus ?? this.approvalStatus,
      approvalNotes:      approvalNotes ?? this.approvalNotes,
      approvedAt:         approvedAt ?? this.approvedAt,
      createdBy:          createdBy,
      createdAt:          createdAt,
      notes:              notes ?? this.notes,
      clientComments:     clientComments ?? this.clientComments,
    );
  }
}
