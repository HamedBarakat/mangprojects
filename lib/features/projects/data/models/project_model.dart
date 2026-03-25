import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectModel {
  final String id;
  final String officeId;
  final String projectCode;
  final String name;
  final String type;
  final String status;
  final String clientId;
  final String clientName;
  final String? clientContactId; // ✅ جديد
  final String? clientContactName; // ✅ جديد

  // ── Project Team ───────────────────────────────────────────────────────────
  final String? teamLeaderId;
  final String? teamLeaderName;
  final String? qcId;
  final String? qcName;
  final String? pmId;
  final String? pmName;

  final String location;
  final List<String> disciplines;
  final DateTime startDate;
  final DateTime endDate;
  final double completionPercentage;
  final String createdBy;
  final DateTime createdAt;
  final String notes;

  const ProjectModel({
    required this.id,
    required this.officeId,
    required this.projectCode,
    required this.name,
    required this.type,
    required this.status,
    required this.clientId,
    required this.clientName,
    this.clientContactId, // ✅ optional
    this.clientContactName, // ✅ optional
    this.teamLeaderId,
    this.teamLeaderName,
    this.qcId,
    this.qcName,
    this.pmId,
    this.pmName,
    required this.location,
    required this.disciplines,
    required this.startDate,
    required this.endDate,
    required this.completionPercentage,
    required this.createdBy,
    required this.createdAt,
    required this.notes,
  });

  String get typeLabel {
    switch (type) {
      case 'design':
        return 'Design';
      case 'executive_drawings':
        return 'Executive Drawings';
      case 'supervision':
        return 'Supervision';
      default:
        return type;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'suspended':
        return 'Suspended';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  factory ProjectModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ProjectModel(
      id: doc.id,
      officeId: d['officeId'] ?? '',
      projectCode: d['projectCode'] ?? '',
      name: d['name'] ?? '',
      type: d['type'] ?? 'design',
      status: d['status'] ?? 'active',
      clientId: d['clientId'] ?? '',
      clientName: d['clientName'] ?? '',
      clientContactId: d['clientContactId'] as String?, // ✅ جديد
      clientContactName: d['clientContactName'] as String?, // ✅ جديد
      teamLeaderId: d['teamLeaderId'] as String?,
      teamLeaderName: d['teamLeaderName'] as String?,
      qcId: d['qcId'] as String?,
      qcName: d['qcName'] as String?,
      pmId: d['pmId'] as String?,
      pmName: d['pmName'] as String?,
      location: d['location'] ?? '',
      disciplines: List<String>.from(d['disciplines'] ?? []),
      startDate: (d['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (d['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completionPercentage: (d['completionPercentage'] ?? 0).toDouble(),
      createdBy: d['createdBy'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: d['notes'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'officeId': officeId,
      'projectCode': projectCode,
      'name': name,
      'type': type,
      'status': status,
      'clientId': clientId,
      'clientName': clientName,
      if (clientContactId != null) 'clientContactId': clientContactId, // ✅ جديد
      if (clientContactName != null)
        'clientContactName': clientContactName, // ✅ جديد
      if (teamLeaderId != null) 'teamLeaderId': teamLeaderId,
      if (teamLeaderName != null) 'teamLeaderName': teamLeaderName,
      if (qcId != null) 'qcId': qcId,
      if (qcName != null) 'qcName': qcName,
      if (pmId != null) 'pmId': pmId,
      if (pmName != null) 'pmName': pmName,
      'location': location,
      'disciplines': disciplines,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'completionPercentage': completionPercentage,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
    };
  }

  ProjectModel copyWith({
    String? id,
    String? officeId,
    String? projectCode,
    String? name,
    String? type,
    String? status,
    String? clientId,
    String? clientName,
    String? clientContactId, // ✅ جديد
    String? clientContactName, // ✅ جديد
    String? teamLeaderId,
    String? teamLeaderName,
    String? qcId,
    String? qcName,
    String? pmId,
    String? pmName,
    String? location,
    List<String>? disciplines,
    DateTime? startDate,
    DateTime? endDate,
    double? completionPercentage,
    String? createdBy,
    DateTime? createdAt,
    String? notes,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      officeId: officeId ?? this.officeId,
      projectCode: projectCode ?? this.projectCode,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientContactId: clientContactId ?? this.clientContactId, // ✅ جديد
      clientContactName: clientContactName ?? this.clientContactName, // ✅ جديد
      teamLeaderId: teamLeaderId ?? this.teamLeaderId,
      teamLeaderName: teamLeaderName ?? this.teamLeaderName,
      qcId: qcId ?? this.qcId,
      qcName: qcName ?? this.qcName,
      pmId: pmId ?? this.pmId,
      pmName: pmName ?? this.pmName,
      location: location ?? this.location,
      disciplines: disciplines ?? this.disciplines,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
    );
  }
}
