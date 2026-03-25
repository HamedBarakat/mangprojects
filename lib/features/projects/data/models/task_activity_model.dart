import 'package:cloud_firestore/cloud_firestore.dart';

class TaskActivity {
  final String id;
  final String taskId;
  final String officeId; // ✅ NEW
  final String type;
  final String message;
  final String userName;
  final String userRole; // ✅ NEW
  final DateTime createdAt;

  TaskActivity({
    required this.id,
    required this.taskId,
    required this.officeId, // ✅ NEW
    required this.type,
    required this.message,
    required this.userName,
    required this.userRole, // ✅ NEW
    required this.createdAt,
  });

  factory TaskActivity.fromMap(String id, Map<String, dynamic> data) {
    return TaskActivity(
      id: id,
      taskId: data['taskId'] ?? '',
      officeId: data['officeId'] ?? '', // ✅ NEW
      type: data['type'] ?? '',
      message: data['message'] ?? '',
      userName: data['userName'] ?? '',
      userRole: data['userRole'] ?? '', // ✅ NEW
      createdAt: (data['createdAt'] as Timestamp).toDate(), // ✅ FIXED
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'officeId': officeId, // ✅ NEW
      'type': type,
      'message': message,
      'userName': userName,
      'userRole': userRole, // ✅ NEW
      'createdAt': Timestamp.fromDate(createdAt), // ✅ FIXED
    };
  }
}
