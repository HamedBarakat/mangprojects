import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/notification_model.dart';

class NotificationRepository {
  final _ref = FirebaseFirestore.instance.collection('notifications');

  // ── Stream إشعارات الشخص الحالي ──────────────────────────────────────────
  Stream<List<NotificationModel>> watchMyNotifications(String uid) {
    return _ref
        .where('recipientId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(NotificationModel.fromFirestore).toList());
  }

  // ── عدد الغير مقروءة ─────────────────────────────────────────────────────
  Stream<int> watchUnreadCount(String uid) {
    return _ref
        .where('recipientId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // ── إرسال إشعار لشخص واحد ────────────────────────────────────────────────
  Future<void> sendToUser({
    required String officeId,
    required String recipientId,
    required String title,
    required String body,
    required String type,
    String? projectId,
    String? projectName,
    String? taskId,
    String? taskTitle,
  }) async {
    if (recipientId.isEmpty) return;
    await _ref.add(NotificationModel(
      id: '',
      officeId: officeId,
      recipientId: recipientId,
      title: title,
      body: body,
      type: type,
      projectId: projectId,
      projectName: projectName,
      taskId: taskId,
      taskTitle: taskTitle,
      isRead: false,
      createdAt: DateTime.now(),
    ).toFirestore());
  }

  // ── إرسال إشعار لمجموعة (batch) ─────────────────────────────────────────
  Future<void> sendToMany({
    required String officeId,
    required List<String> recipientIds,
    required String title,
    required String body,
    required String type,
    String? projectId,
    String? projectName,
    String? taskId,
    String? taskTitle,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    final unique = recipientIds.where((id) => id.isNotEmpty).toSet().toList();

    for (final uid in unique) {
      final doc = _ref.doc();
      batch.set(doc, NotificationModel(
        id: '',
        officeId: officeId,
        recipientId: uid,
        title: title,
        body: body,
        type: type,
        projectId: projectId,
        projectName: projectName,
        taskId: taskId,
        taskTitle: taskTitle,
        isRead: false,
        createdAt: DateTime.now(),
      ).toFirestore());
    }
    await batch.commit();
  }

  // ── تحديد كمقروء ─────────────────────────────────────────────────────────
  Future<void> markAsRead(String notificationId) async {
    await _ref.doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllAsRead(String uid) async {
    final snap = await _ref
        .where('recipientId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String id) async {
    await _ref.doc(id).delete();
  }

  // ── اجلب stakeholders المكتب (Admin + DC + Section Head + COO + Principal) ─
  Future<List<String>> fetchOfficeWideStakeholders(String officeId) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('officeId', isEqualTo: officeId)
        .where('isActive', isEqualTo: true)
        .get();

    const stakeholderRoles = {'admin', 'dc', 'management'};
    const stakeholderTitles = {
      'coo',
      'principal_managing_partner',
      'technical_office_manager',
      'head_of_department',
    };

    return snap.docs
        .where((doc) {
          final d = doc.data();
          final role = d['role'] as String? ?? '';
          final jobTitle = d['jobTitle'] as String? ?? '';
          final adminFlag = d['adminFlag'] as bool? ?? false;
          return adminFlag ||
              stakeholderRoles.contains(role) ||
              stakeholderTitles.contains(jobTitle);
        })
        .map((doc) => doc.id)
        .toList();
  }

  // ── إشعار تغيّر حالة task ────────────────────────────────────────────────
  Future<void> sendTaskStatusNotification({
    required String officeId,
    required String taskId,
    required String taskTitle,
    required String projectId,
    required String projectName,
    required String newStatus,
    required String changedByName,
    required List<String> engineerIds,
    required String teamLeaderId,
    required String reviewerId,
    required List<String> officeWideIds,
  }) async {
    final statusLabel = _statusLabel(newStatus);
    final body =
        '"$taskTitle" → $statusLabel\nBy $changedByName · $projectName';

    final allRecipients = <String>{
      ...engineerIds,
      if (teamLeaderId.isNotEmpty) teamLeaderId,
      if (reviewerId.isNotEmpty) reviewerId,
      ...officeWideIds,
    };

    await sendToMany(
      officeId: officeId,
      recipientIds: allRecipients.toList(),
      title: '📋 Task Status Updated',
      body: body,
      type: 'task_status_change',
      projectId: projectId,
      projectName: projectName,
      taskId: taskId,
      taskTitle: taskTitle,
    );
  }

  // ── إشعار إسناد task جديدة ───────────────────────────────────────────────
  Future<void> sendTaskAssignedNotification({
    required String officeId,
    required String taskId,
    required String taskTitle,
    required String projectId,
    required String projectName,
    required List<String> engineerIds,
    required String reviewerId,
    required String teamLeaderId,
    required List<String> officeWideIds,
    required String assignedByName,
  }) async {
    final allRecipients = <String>{
      ...engineerIds,
      if (reviewerId.isNotEmpty) reviewerId,
      if (teamLeaderId.isNotEmpty) teamLeaderId,
      ...officeWideIds,
    };

    await sendToMany(
      officeId: officeId,
      recipientIds: allRecipients.toList(),
      title: '🆕 New Task Assigned',
      body: '"$taskTitle" has been created in $projectName\nBy $assignedByName',
      type: 'task_assigned',
      projectId: projectId,
      projectName: projectName,
      taskId: taskId,
      taskTitle: taskTitle,
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'not_started':      return 'Not Started';
      case 'in_progress':      return 'In Progress';
      case 'team_leader_review': return 'Team Leader Review';
      case 'qc_review':        return 'QC Review';
      case 'client_review':    return 'Client Review';
      case 'completed':        return 'Completed ✅';
      default:                 return status;
    }
  }
}
