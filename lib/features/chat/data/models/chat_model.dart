import 'package:cloud_firestore/cloud_firestore.dart';

// ── Chat room ─────────────────────────────────────────────────────────────────
class ChatModel {
  final String id;
  final String projectId;
  final String officeId;
  final String createdBy;
  final DateTime createdAt;
  final String name;
  final List<String> members;
  /// lastSeen[userId] = last time that user read the chat
  final Map<String, DateTime> lastSeen;

  const ChatModel({
    required this.id,
    required this.projectId,
    required this.officeId,
    required this.createdBy,
    required this.createdAt,
    required this.name,
    required this.members,
    this.lastSeen = const {},
  });

  DateTime? lastSeenFor(String userId) => lastSeen[userId];

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawLastSeen = (d['lastSeen'] as Map<String, dynamic>?) ?? {};
    final lastSeen = rawLastSeen.map(
      (k, v) => MapEntry(
        k,
        v != null
            ? (v as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    return ChatModel(
      id: doc.id,
      projectId: d['projectId'] as String? ?? '',
      officeId: d['officeId'] as String? ?? '',
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      name: d['name'] as String? ?? '',
      members: List<String>.from(d['members'] ?? []),
      lastSeen: lastSeen,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'projectId': projectId,
    'officeId': officeId,
    'createdBy': createdBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'name': name,
    'members': members,
    'lastSeen': lastSeen.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
  };
}

// ── Chat message ──────────────────────────────────────────────────────────────
class ChatMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String? text;
  final String? fileUrl;
  final String? fileType; // 'image' | 'pdf' | 'other'
  final String? fileName;
  final DateTime timestamp;
  final bool isDeleted;

  const ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    this.text,
    this.fileUrl,
    this.fileType,
    this.fileName,
    required this.timestamp,
    this.isDeleted = false,
  });

  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChatMessageModel(
      id: doc.id,
      senderId: d['senderId'] as String? ?? '',
      senderName: d['senderName'] as String? ?? '',
      senderAvatar: d['senderAvatar'] as String?,
      text: d['text'] as String?,
      fileUrl: d['fileUrl'] as String?,
      fileType: d['fileType'] as String?,
      fileName: d['fileName'] as String?,
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: d['isDeleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'senderId': senderId,
    'senderName': senderName,
    if (senderAvatar != null) 'senderAvatar': senderAvatar,
    if (text != null && text!.isNotEmpty) 'text': text,
    if (fileUrl != null) 'fileUrl': fileUrl,
    if (fileType != null) 'fileType': fileType,
    if (fileName != null) 'fileName': fileName,
    'timestamp': FieldValue.serverTimestamp(),
    'isDeleted': isDeleted,
  };
}
