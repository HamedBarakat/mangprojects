import 'package:cloud_firestore/cloud_firestore.dart';

// ── Approval step ──────────────────────────────────────────────────────────────
class LeaveApprovalStep {
  final String jobTitle;
  final String approverId;
  final String approverName;
  final String action; // 'pending' | 'approved' | 'rejected'
  final DateTime? timestamp;
  final String notes;

  const LeaveApprovalStep({
    required this.jobTitle,
    this.approverId = '',
    this.approverName = '',
    required this.action,
    this.timestamp,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
    'jobTitle': jobTitle,
    'approverId': approverId,
    'approverName': approverName,
    'action': action,
    if (timestamp != null) 'timestamp': Timestamp.fromDate(timestamp!),
    'notes': notes,
  };

  factory LeaveApprovalStep.fromMap(Map<String, dynamic> m) => LeaveApprovalStep(
    jobTitle: m['jobTitle'] as String? ?? '',
    approverId: m['approverId'] as String? ?? '',
    approverName: m['approverName'] as String? ?? '',
    action: m['action'] as String? ?? 'pending',
    timestamp: m['timestamp'] != null ? (m['timestamp'] as Timestamp).toDate() : null,
    notes: m['notes'] as String? ?? '',
  );
}

// ── Leave request ─────────────────────────────────────────────────────────────
class LeaveRequestModel {
  final String id;
  final String officeId;
  final String employeeId;
  final String employeeName;
  final String employeeJobTitle;
  final String type; // 'annual_leave' | 'sick_leave' | 'permission' | 'emergency'
  final DateTime startDate;
  final DateTime endDate;
  final double durationDays;
  final double durationHours; // for permission
  final String reason;
  final String status; // 'pending'|'approved_l1'|'approved_l2'|'approved_final'|'rejected'|'cancelled'
  final String currentApproverJobTitle; // job title of next required approver
  final List<LeaveApprovalStep> approvalChain;
  final bool hrOverride;
  final String hrOverrideNote;
  final int employeeAnnualBalance;
  final int employeeBalanceUsed;
  final int employeeBalanceRemaining;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LeaveRequestModel({
    required this.id,
    required this.officeId,
    required this.employeeId,
    required this.employeeName,
    required this.employeeJobTitle,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.durationDays = 0,
    this.durationHours = 0,
    required this.reason,
    required this.status,
    required this.currentApproverJobTitle,
    required this.approvalChain,
    this.hrOverride = false,
    this.hrOverrideNote = '',
    this.employeeAnnualBalance = 21,
    this.employeeBalanceUsed = 0,
    this.employeeBalanceRemaining = 21,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Derived ─────────────────────────────────────────────────────────────────
  String get typeLabel => switch (type) {
    'annual_leave' => 'Annual Leave',
    'sick_leave' => 'Sick Leave',
    'permission' => 'Permission',
    'emergency' => 'Emergency Leave',
    _ => type,
  };

  String get statusLabel => switch (status) {
    'pending' => 'Pending',
    'approved_l1' || 'approved_l2' => 'Partially Approved',
    'approved_final' => 'Approved',
    'rejected' => 'Rejected',
    'cancelled' => 'Cancelled',
    _ => status,
  };

  bool get isActive =>
      status == 'pending' || status == 'approved_l1' || status == 'approved_l2';
  bool get isApproved => status == 'approved_final';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';

  String get durationLabel {
    if (type == 'permission') {
      return '${durationHours.toStringAsFixed(1)}h';
    }
    return durationDays == durationDays.truncate()
        ? '${durationDays.toInt()} day${durationDays != 1 ? 's' : ''}'
        : '${durationDays.toStringAsFixed(1)} days';
  }

  // ── Firestore ────────────────────────────────────────────────────────────────
  factory LeaveRequestModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LeaveRequestModel(
      id: doc.id,
      officeId: d['officeId'] as String? ?? '',
      employeeId: d['employeeId'] as String? ?? '',
      employeeName: d['employeeName'] as String? ?? '',
      employeeJobTitle: d['employeeJobTitle'] as String? ?? '',
      type: d['type'] as String? ?? 'annual_leave',
      startDate: (d['startDate'] as Timestamp).toDate(),
      endDate: (d['endDate'] as Timestamp).toDate(),
      durationDays: ((d['durationDays'] ?? 0) as num).toDouble(),
      durationHours: ((d['durationHours'] ?? 0) as num).toDouble(),
      reason: d['reason'] as String? ?? '',
      status: d['status'] as String? ?? 'pending',
      currentApproverJobTitle: d['currentApproverJobTitle'] as String? ?? '',
      approvalChain: ((d['approvalChain'] as List<dynamic>?) ?? [])
          .map((e) => LeaveApprovalStep.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      hrOverride: d['hrOverride'] as bool? ?? false,
      hrOverrideNote: d['hrOverrideNote'] as String? ?? '',
      employeeAnnualBalance: (d['employeeAnnualBalance'] as num?)?.toInt() ?? 21,
      employeeBalanceUsed: (d['employeeBalanceUsed'] as num?)?.toInt() ?? 0,
      employeeBalanceRemaining: (d['employeeBalanceRemaining'] as num?)?.toInt() ?? 21,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'officeId': officeId,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'employeeJobTitle': employeeJobTitle,
    'type': type,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'durationDays': durationDays,
    'durationHours': durationHours,
    'reason': reason,
    'status': status,
    'currentApproverJobTitle': currentApproverJobTitle,
    'approvalChain': approvalChain.map((s) => s.toMap()).toList(),
    'hrOverride': hrOverride,
    'hrOverrideNote': hrOverrideNote,
    'employeeAnnualBalance': employeeAnnualBalance,
    'employeeBalanceUsed': employeeBalanceUsed,
    'employeeBalanceRemaining': employeeBalanceRemaining,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}
