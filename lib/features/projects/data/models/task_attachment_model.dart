import 'package:cloud_firestore/cloud_firestore.dart';

class TaskAttachment {
  final String id;
  final String taskId;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String downloadUrl;
  final String storagePath;

  final String uploadedBy;
  final String uploaderName;
  final String uploaderRole;

  final String hash;
  final DateTime createdAt;

  const TaskAttachment({
    required this.id,
    required this.taskId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.downloadUrl,
    required this.storagePath,
    required this.uploadedBy,
    required this.uploaderName,
    required this.uploaderRole,
    required this.hash,
    required this.createdAt,
  });

  factory TaskAttachment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    return TaskAttachment(
      id: doc.id,
      taskId: d['taskId'] ?? '',
      fileName: d['fileName'] ?? '',
      fileType: d['fileType'] ?? '',
      fileSize: d['fileSize'] ?? 0,
      downloadUrl: d['downloadUrl'] ?? '',
      storagePath: d['storagePath'] ?? '',
      uploadedBy: d['uploadedBy'] ?? '',
      uploaderName: d['uploaderName'] ?? '',
      uploaderRole: d['uploaderRole'] ?? '',
      hash: d['hash'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'taskId': taskId,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'downloadUrl': downloadUrl,
      'storagePath': storagePath,
      'uploadedBy': uploadedBy,
      'uploaderName': uploaderName,
      'uploaderRole': uploaderRole,
      'hash': hash,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
