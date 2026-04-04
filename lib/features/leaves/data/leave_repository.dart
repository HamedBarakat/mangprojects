import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/leave_request_model.dart';
import 'package:mang_projects/features/notifications/data/notification_repository.dart';

class LeaveRepository {
  final _db = FirebaseFirestore.instance;
  final _notif = NotificationRepository();

  // ── Approval chain map ────────────────────────────────────────────────────
  static List<String> approvalChainFor(String jobTitle) {
    switch (jobTitle) {
      case 'junior_engineer':
      case 'design_engineer':
      case 'cad_bim_modeler':
      case 'chief_draftsman':
        return ['senior_design_engineer', 'head_of_department', 'coo'];
      case 'senior_design_engineer':
        return ['head_of_department', 'coo'];
      case 'site_engineer':
      case 'site_supervisor':
      case 'quantity_surveyor':
        return ['project_manager', 'coo'];
      case 'bim_coordinator':
        return ['bim_manager', 'head_of_department', 'coo'];
      case 'bim_manager':
      case 'qc_engineer':
      case 'head_of_department':
      case 'project_manager':
      case 'technical_office_manager':
      case 'planning_scheduling_manager':
      case 'business_dev_engineer':
        return ['coo'];
      case 'dc':
      case 'hr':
      case 'chief_accountant':
        return ['coo'];
      case 'accountant':
        return ['chief_accountant', 'coo'];
      case 'office_admin':
        return ['hr'];
      case 'coo':
        return ['principal_managing_partner'];
      default:
        return ['coo'];
    }
  }

  static bool isApproverJobTitle(String jobTitle) {
    const approverTitles = {
      'senior_design_engineer',
      'head_of_department',
      'coo',
      'project_manager',
      'bim_manager',
      'principal_managing_partner',
      'hr',
      'chief_accountant',
    };
    return approverTitles.contains(jobTitle);
  }

  static String jobTitleLabel(String jobTitle) {
    const labels = {
      'junior_engineer': 'Junior Engineer',
      'design_engineer': 'Design Engineer',
      'senior_design_engineer': 'Senior Design Engineer',
      'site_engineer': 'Site Engineer',
      'site_supervisor': 'Site Supervisor',
      'cad_bim_modeler': 'CAD/BIM Modeler',
      'bim_coordinator': 'BIM Coordinator',
      'bim_manager': 'BIM Manager',
      'chief_draftsman': 'Chief Draftsman',
      'quantity_surveyor': 'Quantity Surveyor',
      'qc_engineer': 'QC Engineer',
      'business_dev_engineer': 'Business Development Engineer',
      'dc': 'Document Controller',
      'accountant': 'Accountant',
      'chief_accountant': 'Chief Accountant',
      'hr': 'HR Manager',
      'office_admin': 'Office Admin',
      'technical_office_manager': 'Technical Office Manager',
      'planning_scheduling_manager': 'Planning & Scheduling Manager',
      'head_of_department': 'Head of Department',
      'project_manager': 'Project Manager',
      'coo': 'COO',
      'principal_managing_partner': 'Principal Managing Partner',
    };
    return labels[jobTitle] ?? jobTitle;
  }

  // ── Submit new leave request ───────────────────────────────────────────────
  Future<String> submitLeaveRequest({
    required String officeId,
    required String employeeId,
    required String employeeName,
    required String employeeJobTitle,
    required String type,
    required DateTime startDate,
    required DateTime endDate,
    required double durationDays,
    double durationHours = 0,
    required String reason,
    required int annualBalance,
    required int balanceUsed,
    required int balanceRemaining,
  }) async {
    final now = DateTime.now();
    final chainTitles = approvalChainFor(employeeJobTitle);
    final approvalChain = chainTitles
        .map((jt) => LeaveApprovalStep(jobTitle: jt, action: 'pending'))
        .toList();
    final currentApproverJobTitle =
        chainTitles.isNotEmpty ? chainTitles[0] : '';

    final doc = await _db.collection('leave_requests').add({
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
      'status': 'pending',
      'currentApproverJobTitle': currentApproverJobTitle,
      'approvalChain': approvalChain.map((s) => s.toMap()).toList(),
      'hrOverride': false,
      'hrOverrideNote': '',
      'employeeAnnualBalance': annualBalance,
      'employeeBalanceUsed': balanceUsed,
      'employeeBalanceRemaining': balanceRemaining,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    // Notify first approvers
    if (currentApproverJobTitle.isNotEmpty) {
      final firstApprovers =
          await _fetchUsersByJobTitle(officeId, currentApproverJobTitle);
      if (firstApprovers.isNotEmpty) {
        await _notif.sendToMany(
          officeId: officeId,
          recipientIds: firstApprovers,
          title: 'New Leave Request',
          body:
              '$employeeName has submitted a ${_typeLabel(type)} request requiring your approval.',
          type: 'leave_approval_required',
        );
      }
    }

    return doc.id;
  }

  // ── Approve ───────────────────────────────────────────────────────────────
  Future<void> approveRequest({
    required String requestId,
    required String officeId,
    required String approverId,
    required String approverName,
    required String approverJobTitle,
    required bool isAdmin,
    String notes = '',
  }) async {
    final doc = await _db.collection('leave_requests').doc(requestId).get();
    if (!doc.exists) throw Exception('Leave request not found');

    final leave = LeaveRequestModel.fromFirestore(doc);
    final now = DateTime.now();

    if (isAdmin) {
      // Admin approves all pending steps at once
      final chain = leave.approvalChain.map((s) {
        if (s.action == 'pending') {
          return LeaveApprovalStep(
            jobTitle: s.jobTitle,
            approverId: approverId,
            approverName: approverName,
            action: 'approved',
            timestamp: now,
            notes: notes,
          );
        }
        return s;
      }).toList();

      await _db.collection('leave_requests').doc(requestId).update({
        'status': 'approved_final',
        'currentApproverJobTitle': '',
        'approvalChain': chain.map((s) => s.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(now),
      });

      await _notif.sendToUser(
        officeId: officeId,
        recipientId: leave.employeeId,
        title: 'Leave Request Approved',
        body: 'Your ${leave.typeLabel} request has been fully approved.',
        type: 'leave_approved',
      );
    } else {
      // Advance one step in the chain
      final chain = leave.approvalChain.toList();
      String newStatus = leave.status;
      String nextApproverJobTitle = '';
      bool found = false;

      for (int i = 0; i < chain.length; i++) {
        if (chain[i].action == 'pending') {
          chain[i] = LeaveApprovalStep(
            jobTitle: chain[i].jobTitle,
            approverId: approverId,
            approverName: approverName,
            action: 'approved',
            timestamp: now,
            notes: notes,
          );
          // Check if there's another pending step
          final nextPendingIdx = chain.indexWhere(
              (s) => s.action == 'pending', i + 1);
          if (nextPendingIdx >= 0) {
            nextApproverJobTitle = chain[nextPendingIdx].jobTitle;
            newStatus = 'approved_l${i + 1}';
          } else {
            newStatus = 'approved_final';
          }
          found = true;
          break;
        }
      }

      if (!found) throw Exception('No pending approval step found');

      await _db.collection('leave_requests').doc(requestId).update({
        'status': newStatus,
        'currentApproverJobTitle': nextApproverJobTitle,
        'approvalChain': chain.map((s) => s.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(now),
      });

      if (newStatus == 'approved_final') {
        await _notif.sendToUser(
          officeId: officeId,
          recipientId: leave.employeeId,
          title: 'Leave Request Approved',
          body: 'Your ${leave.typeLabel} request has been fully approved.',
          type: 'leave_approved',
        );
      } else {
        // Notify the next approver(s)
        final nextApprovers =
            await _fetchUsersByJobTitle(officeId, nextApproverJobTitle);
        if (nextApprovers.isNotEmpty) {
          await _notif.sendToMany(
            officeId: officeId,
            recipientIds: nextApprovers,
            title: 'Leave Approval Required',
            body:
                '${leave.employeeName}\'s ${leave.typeLabel} request is now awaiting your approval.',
            type: 'leave_approval_required',
          );
        }
      }
    }
  }

  // ── Reject ────────────────────────────────────────────────────────────────
  Future<void> rejectRequest({
    required String requestId,
    required String officeId,
    required String approverId,
    required String approverName,
    required String approverJobTitle,
    required String reason, // mandatory
  }) async {
    final doc = await _db.collection('leave_requests').doc(requestId).get();
    if (!doc.exists) throw Exception('Leave request not found');

    final leave = LeaveRequestModel.fromFirestore(doc);
    final now = DateTime.now();

    // Mark all pending steps as rejected
    final chain = leave.approvalChain.map((s) {
      if (s.action == 'pending') {
        return LeaveApprovalStep(
          jobTitle: s.jobTitle,
          approverId: approverId,
          approverName: approverName,
          action: 'rejected',
          timestamp: now,
          notes: reason,
        );
      }
      return s;
    }).toList();

    await _db.collection('leave_requests').doc(requestId).update({
      'status': 'rejected',
      'currentApproverJobTitle': '',
      'approvalChain': chain.map((s) => s.toMap()).toList(),
      'updatedAt': Timestamp.fromDate(now),
    });

    await _notif.sendToUser(
      officeId: officeId,
      recipientId: leave.employeeId,
      title: 'Leave Request Rejected',
      body:
          'Your ${leave.typeLabel} request was rejected by $approverName. Reason: $reason',
      type: 'leave_rejected',
    );
  }

  // ── Cancel (by employee) ──────────────────────────────────────────────────
  Future<void> cancelLeave(String requestId) async {
    await _db.collection('leave_requests').doc(requestId).update({
      'status': 'cancelled',
      'currentApproverJobTitle': '',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ── Streams ───────────────────────────────────────────────────────────────
  Stream<List<LeaveRequestModel>> watchMyLeaves(String employeeId) {
    return _db
        .collection('leave_requests')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => LeaveRequestModel.fromFirestore(d)).toList());
  }

  /// For admin: see all pending requests in office
  Stream<List<LeaveRequestModel>> watchPendingApprovals(String officeId) {
    return _db
        .collection('leave_requests')
        .where('officeId', isEqualTo: officeId)
        .where('status', whereIn: ['pending', 'approved_l1', 'approved_l2'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => LeaveRequestModel.fromFirestore(d)).toList());
  }

  /// For non-admin approvers: only requests waiting for THEIR job title
  Stream<List<LeaveRequestModel>> watchPendingApprovalsForJobTitle(
      String officeId, String myJobTitle) {
    return _db
        .collection('leave_requests')
        .where('officeId', isEqualTo: officeId)
        .where('currentApproverJobTitle', isEqualTo: myJobTitle)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => LeaveRequestModel.fromFirestore(d)).toList());
  }

  Stream<List<LeaveRequestModel>> watchAllLeaves(String officeId) {
    return _db
        .collection('leave_requests')
        .where('officeId', isEqualTo: officeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => LeaveRequestModel.fromFirestore(d)).toList());
  }

  // ── Annual balance ────────────────────────────────────────────────────────
  Future<Map<String, int>> getLeaveBalance(String employeeId, int year) async {
    final snap = await _db
        .collection('leave_requests')
        .where('employeeId', isEqualTo: employeeId)
        .get();

    final approved = snap.docs
        .map((d) => LeaveRequestModel.fromFirestore(d))
        .where((r) =>
            r.isApproved &&
            r.type == 'annual_leave' &&
            r.startDate.year == year)
        .toList();

    final used =
        approved.fold<double>(0, (acc, r) => acc + r.durationDays).ceil();
    const total = 21;
    return {
      'total': total,
      'used': used,
      'remaining': (total - used).clamp(0, total),
    };
  }

  // ── Private helpers ───────────────────────────────────────────────────────
  Future<List<String>> _fetchUsersByJobTitle(
      String officeId, String jobTitle) async {
    final snap = await _db
        .collection('users')
        .where('officeId', isEqualTo: officeId)
        .where('jobTitle', isEqualTo: jobTitle)
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs.map((d) => d.id).toList();
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'annual_leave': return 'Annual Leave';
      case 'sick_leave':   return 'Sick Leave';
      case 'permission':   return 'Permission';
      case 'emergency':    return 'Emergency Leave';
      default:             return type;
    }
  }
}
