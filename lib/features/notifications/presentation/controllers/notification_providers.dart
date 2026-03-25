import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/notification_model.dart';
import '../../data/notification_repository.dart';
import '../../../home/presentation/controllers/home_providers.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((_) {
  return NotificationRepository();
});

// ── Stream إشعاراتي ───────────────────────────────────────────────────────────
final myNotificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const Stream.empty();
  return ref
      .watch(notificationRepositoryProvider)
      .watchMyNotifications(user.uid);
});

// ── عدد الغير مقروءة (للـ badge) ────────────────────────────────────────────
final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value(0);
  return ref.watch(notificationRepositoryProvider).watchUnreadCount(user.uid);
});

// ── Helper: إرسال إشعار عند تغيّر حالة task ─────────────────────────────────
// بيستخدمه task_repository بعد كل workflow action
Future<void> sendTaskStatusNotification({
  required String officeId,
  required String taskId,
  required String taskTitle,
  required String projectId,
  required String projectName,
  required String newStatus,
  required String changedByName,
  // كل الـ stakeholders المرتبطين بالـ task
  required List<String> engineerIds,
  required String teamLeaderId,
  required String reviewerId,
  // stakeholders على مستوى المكتب (Admin + DC + Section Head + COO + Principal)
  required List<String> officeWideIds,
}) async {
  final repo = NotificationRepository();

  final statusLabel = _statusLabel(newStatus);
  final title = '📋 Task Status Updated';
  final body = '"$taskTitle" → $statusLabel\nBy $changedByName · $projectName';

  // اجمع كل المستفيدين
  final allRecipients = <String>{
    ...engineerIds,
    if (teamLeaderId.isNotEmpty) teamLeaderId,
    if (reviewerId.isNotEmpty) reviewerId,
    ...officeWideIds,
  };

  await repo.sendToMany(
    officeId: officeId,
    recipientIds: allRecipients.toList(),
    title: title,
    body: body,
    type: 'task_status_change',
    projectId: projectId,
    projectName: projectName,
    taskId: taskId,
    taskTitle: taskTitle,
  );
}

// ── Helper: إشعار إسناد task جديدة ──────────────────────────────────────────
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
  final repo = NotificationRepository();
  final allRecipients = <String>{
    ...engineerIds,
    if (reviewerId.isNotEmpty) reviewerId,
    if (teamLeaderId.isNotEmpty) teamLeaderId,
    ...officeWideIds,
  };

  await repo.sendToMany(
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
      return 'Completed ✅';
    default:
      return status;
  }
}

// ── Helper: اجلب officeWide stakeholders من Firestore ────────────────────────
// بيرجع UIDs لكل Admin + DC + Section Head + COO + Principal في المكتب
Future<List<String>> fetchOfficeWideStakeholders(String officeId) async {
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .where('officeId', isEqualTo: officeId)
      .where('isActive', isEqualTo: true)
      .get();

  final stakeholderRoles = {'admin', 'dc', 'management'};
  final stakeholderTitles = {
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
