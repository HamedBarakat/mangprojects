import 'package:cloud_firestore/cloud_firestore.dart';

class TaskComment {
  final String id;
  final String taskId;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String text;
  final String? imageUrl;   // Firebase Storage URL
  final DateTime createdAt;

  const TaskComment({
    required this.id,
    required this.taskId,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.text,
    this.imageUrl,
    required this.createdAt,
  });

  factory TaskComment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TaskComment(
      id:         doc.id,
      taskId:     d['taskId'] ?? '',
      authorId:   d['authorId'] ?? '',
      authorName: d['authorName'] ?? '',
      authorRole: d['authorRole'] ?? '',
      text:       d['text'] ?? '',
      imageUrl:   d['imageUrl'] as String?,
      createdAt:  (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'taskId':     taskId,
    'authorId':   authorId,
    'authorName': authorName,
    'authorRole': authorRole,
    'text':       text,
    if (imageUrl != null) 'imageUrl': imageUrl,
    'createdAt':  Timestamp.fromDate(createdAt),
  };
}
