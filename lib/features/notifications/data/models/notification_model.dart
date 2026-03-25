import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String officeId;
  final String recipientId; // uid الشخص اللي المفروض يوصله الإشعار
  final String title;
  final String body;
  final String type; // task_status_change | task_assigned | task_comment | task_submitted
  final String? projectId;
  final String? projectName;
  final String? taskId;
  final String? taskTitle;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.officeId,
    required this.recipientId,
    required this.title,
    required this.body,
    required this.type,
    this.projectId,
    this.projectName,
    this.taskId,
    this.taskTitle,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      officeId: d['officeId'] ?? '',
      recipientId: d['recipientId'] ?? '',
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      type: d['type'] ?? '',
      projectId: d['projectId'],
      projectName: d['projectName'],
      taskId: d['taskId'],
      taskTitle: d['taskTitle'],
      isRead: d['isRead'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'officeId': officeId,
    'recipientId': recipientId,
    'title': title,
    'body': body,
    'type': type,
    if (projectId != null) 'projectId': projectId,
    if (projectName != null) 'projectName': projectName,
    if (taskId != null) 'taskId': taskId,
    if (taskTitle != null) 'taskTitle': taskTitle,
    'isRead': isRead,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
