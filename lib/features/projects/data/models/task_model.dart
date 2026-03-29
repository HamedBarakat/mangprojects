import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String officeId;
  final String projectId;
  final String projectName;
  final String clientId; // NEW

  // ── Basic Info ─────────────────────────────────────────────────────────────
  final String title;
  final String description;
  final String category;
  final String discipline;

  // ── Assignment ─────────────────────────────────────────────────────────────
  final List<String> assignedEngineerIds;
  final List<String> assignedEngineerNames;

  final String teamLeaderId;
  final String teamLeaderName;

  final String reviewerId;
  final String reviewerName;

  // ── Dates ──────────────────────────────────────────────────────────────────
  final DateTime startDate;
  final DateTime endDate;

  // ── Hours ──────────────────────────────────────────────────────────────────
  final double plannedHours;
  final double actualHours;

  // ── Workflow ───────────────────────────────────────────────────────────────
  // not_started
  // in_progress
  // team_leader_review
  // qc_review
  // client_review
  // completed
  final String status;

  // Progress Rules:
  // not_started        => 0
  // in_progress        => 0..60   (set by Team Leader)
  // team_leader_review => 70
  // qc_review          => 80
  // client_review      => 90
  // completed          => 100
  final double progress;

  // ── Review Notes ───────────────────────────────────────────────────────────
  final String teamLeaderReviewNotes;
  final DateTime? teamLeaderReviewedAt;

  final String qcReviewNotes;
  final DateTime? qcReviewedAt;

  final String clientReviewNotes;
  final DateTime? clientReviewedAt;

  // ── Client Cycle Info ──────────────────────────────────────────────────────
  final int clientReviewRound;
  final DateTime? submittedToClientAt;

  // ── DC (Document Controller) Dispatch ─────────────────────────────────────
  // Set when DC confirms the task was officially sent to client
  final DateTime? dcSentAt;
  final String dcSentByName;

  // ── Client Comments History ────────────────────────────────────────────────
  final List<Map<String, dynamic>> clientComments;
  final List<Map<String, dynamic>> attachments;
  final List<Map<String, dynamic>> activityLog;

  // ── Meta ───────────────────────────────────────────────────────────────────
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final String notes;
  final String taskLink;

  const TaskModel({
    required this.id,
    required this.officeId,
    required this.projectId,
    required this.projectName,
    required this.clientId,
    required this.title,
    required this.description,
    required this.category,
    required this.discipline,
    required this.assignedEngineerIds,
    required this.assignedEngineerNames,
    required this.teamLeaderId,
    required this.teamLeaderName,
    required this.reviewerId,
    required this.reviewerName,
    required this.startDate,
    required this.endDate,
    required this.plannedHours,
    required this.actualHours,
    required this.status,
    required this.progress,
    required this.teamLeaderReviewNotes,
    required this.teamLeaderReviewedAt,
    required this.qcReviewNotes,
    required this.qcReviewedAt,
    required this.clientReviewNotes,
    required this.clientReviewedAt,
    required this.clientReviewRound,
    required this.submittedToClientAt,
    this.dcSentAt,
    this.dcSentByName = '',
    required this.clientComments,
    required this.attachments,
    required this.activityLog,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    required this.notes,
    required this.taskLink,
  });

  // ── Computed ───────────────────────────────────────────────────────────────
  bool get isCompleted => status == 'completed';
  bool get isNotStarted => status == 'not_started';
  bool get isInProgress => status == 'in_progress';
  bool get isTeamLeaderReview => status == 'team_leader_review';
  bool get isQcReview => status == 'qc_review';
  bool get isClientReview => status == 'client_review';

  bool get isOverdue => DateTime.now().isAfter(endDate) && !isCompleted;

  String get statusLabel {
    switch (status) {
      case 'not_started':
        return 'Not Started';
      case 'in_progress':
        return 'In Progress';
      case 'team_leader_review':
        return 'Team Leader Review';
      case 'qc_review':
        return 'QC Review';
      case 'client_review':
        return 'Client Review';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  double get normalizedProgress {
    if (progress < 0) return 0;
    if (progress > 100) return 100;
    return progress;
  }

  // ── Firestore ──────────────────────────────────────────────────────────────
  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    return TaskModel(
      id: doc.id,
      officeId: d['officeId'] ?? '',
      projectId: d['projectId'] ?? '',
      projectName: d['projectName'] ?? '',
      clientId: d['clientId'] ?? '',
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      category: d['category'] ?? '',
      discipline: d['discipline'] ?? '',
      assignedEngineerIds: List<String>.from(
        d['assignedEngineerIds'] ?? const [],
      ),
      assignedEngineerNames: List<String>.from(
        d['assignedEngineerNames'] ?? const [],
      ),
      teamLeaderId: d['teamLeaderId'] ?? '',
      teamLeaderName: d['teamLeaderName'] ?? '',
      reviewerId: d['reviewerId'] ?? '',
      reviewerName: d['reviewerName'] ?? '',
      startDate: (d['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (d['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      plannedHours: (d['plannedHours'] ?? 0).toDouble(),
      actualHours: (d['actualHours'] ?? 0).toDouble(),
      status: d['status'] ?? 'not_started',
      progress: (d['progress'] ?? 0).toDouble(),
      teamLeaderReviewNotes: d['teamLeaderReviewNotes'] ?? '',
      teamLeaderReviewedAt: (d['teamLeaderReviewedAt'] as Timestamp?)?.toDate(),
      qcReviewNotes: d['qcReviewNotes'] ?? '',
      qcReviewedAt: (d['qcReviewedAt'] as Timestamp?)?.toDate(),
      clientReviewNotes: d['clientReviewNotes'] ?? '',
      clientReviewedAt: (d['clientReviewedAt'] as Timestamp?)?.toDate(),
      clientReviewRound: d['clientReviewRound'] ?? 0,
      submittedToClientAt: (d['submittedToClientAt'] as Timestamp?)?.toDate(),
      dcSentAt: (d['dcSentAt'] as Timestamp?)?.toDate(),
      dcSentByName: d['dcSentByName'] ?? '',
      clientComments: List<Map<String, dynamic>>.from(
        (d['clientComments'] as List?)?.map(
              (e) => Map<String, dynamic>.from(e as Map),
            ) ??
            [],
      ),
      // 👇 ضيف دول هنا
      attachments: List<Map<String, dynamic>>.from(
        (d['attachments'] as List?)?.map(
              (e) => Map<String, dynamic>.from(e as Map),
            ) ??
            [],
      ),
      activityLog: List<Map<String, dynamic>>.from(
        (d['activityLog'] as List?)?.map(
              (e) => Map<String, dynamic>.from(e as Map),
            ) ??
            [],
      ),
      createdBy: d['createdBy'] ?? '',
      createdByName: d['createdByName'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: d['notes'] ?? '',
      taskLink: d['taskLink'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'officeId': officeId,
      'projectId': projectId,
      'projectName': projectName,
      'clientId': clientId,
      'title': title,
      'description': description,
      'category': category,
      'discipline': discipline,
      'assignedEngineerIds': assignedEngineerIds,
      'assignedEngineerNames': assignedEngineerNames,
      'teamLeaderId': teamLeaderId,
      'teamLeaderName': teamLeaderName,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'plannedHours': plannedHours,
      'actualHours': actualHours,
      'status': status,
      'progress': progress,
      'teamLeaderReviewNotes': teamLeaderReviewNotes,
      'teamLeaderReviewedAt': teamLeaderReviewedAt != null
          ? Timestamp.fromDate(teamLeaderReviewedAt!)
          : null,
      'qcReviewNotes': qcReviewNotes,
      'qcReviewedAt': qcReviewedAt != null
          ? Timestamp.fromDate(qcReviewedAt!)
          : null,
      'clientReviewNotes': clientReviewNotes,
      'clientReviewedAt': clientReviewedAt != null
          ? Timestamp.fromDate(clientReviewedAt!)
          : null,
      'clientReviewRound': clientReviewRound,
      'submittedToClientAt': submittedToClientAt != null
          ? Timestamp.fromDate(submittedToClientAt!)
          : null,
      'dcSentAt': dcSentAt != null ? Timestamp.fromDate(dcSentAt!) : null,
      'dcSentByName': dcSentByName,
      'clientComments': clientComments,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
      'taskLink': taskLink,
    };
  }

  TaskModel copyWith({
    String? id,
    String? officeId,
    String? projectId,
    String? projectName,
    String? clientId,
    String? title,
    String? description,
    String? category,
    String? discipline,
    List<String>? assignedEngineerIds,
    List<String>? assignedEngineerNames,
    String? teamLeaderId,
    String? teamLeaderName,
    String? reviewerId,
    String? reviewerName,
    DateTime? startDate,
    DateTime? endDate,
    double? plannedHours,
    double? actualHours,
    String? status,
    double? progress,
    String? teamLeaderReviewNotes,
    DateTime? teamLeaderReviewedAt,
    String? qcReviewNotes,
    DateTime? qcReviewedAt,
    String? clientReviewNotes,
    DateTime? clientReviewedAt,
    int? clientReviewRound,
    DateTime? submittedToClientAt,
    DateTime? dcSentAt,
    String? dcSentByName,
    List<Map<String, dynamic>>? clientComments,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    String? notes,
    String? taskLink,
    List<Map<String, dynamic>>? attachments,
    List<Map<String, dynamic>>? activityLog,
  }) {
    return TaskModel(
      id: id ?? this.id,
      officeId: officeId ?? this.officeId,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      clientId: clientId ?? this.clientId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      discipline: discipline ?? this.discipline,
      assignedEngineerIds: assignedEngineerIds ?? this.assignedEngineerIds,
      assignedEngineerNames:
          assignedEngineerNames ?? this.assignedEngineerNames,
      teamLeaderId: teamLeaderId ?? this.teamLeaderId,
      teamLeaderName: teamLeaderName ?? this.teamLeaderName,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      plannedHours: plannedHours ?? this.plannedHours,
      actualHours: actualHours ?? this.actualHours,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      teamLeaderReviewNotes:
          teamLeaderReviewNotes ?? this.teamLeaderReviewNotes,
      teamLeaderReviewedAt: teamLeaderReviewedAt ?? this.teamLeaderReviewedAt,
      qcReviewNotes: qcReviewNotes ?? this.qcReviewNotes,
      qcReviewedAt: qcReviewedAt ?? this.qcReviewedAt,
      clientReviewNotes: clientReviewNotes ?? this.clientReviewNotes,
      clientReviewedAt: clientReviewedAt ?? this.clientReviewedAt,
      clientReviewRound: clientReviewRound ?? this.clientReviewRound,
      submittedToClientAt: submittedToClientAt ?? this.submittedToClientAt,
      dcSentAt: dcSentAt ?? this.dcSentAt,
      dcSentByName: dcSentByName ?? this.dcSentByName,
      clientComments: clientComments ?? this.clientComments,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      taskLink: taskLink ?? this.taskLink,
      attachments: attachments ?? this.attachments,
      activityLog: activityLog ?? this.activityLog,
    );
  }
}
