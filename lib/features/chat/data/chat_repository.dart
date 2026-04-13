import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/chat_model.dart';

class ChatRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  CollectionReference get _chats => _db.collection('chats');

  // ── Watch chat for project ──────────────────────────────────────────────────
  Stream<ChatModel?> watchChatForProject(String projectId, String officeId) {
    return _chats
        .where('projectId', isEqualTo: projectId)
        .where('officeId', isEqualTo: officeId)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          return ChatModel.fromFirestore(snap.docs.first);
        });
  }

  // ── Create chat ─────────────────────────────────────────────────────────────
  Future<String> createChat({
    required String projectId,
    required String officeId,
    required String createdBy,
    required String name,
    required List<String> members,
  }) async {
    final doc = _chats.doc();
    await doc.set({
      'projectId': projectId,
      'officeId': officeId,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'name': name,
      'members': members,
      'lastSeen': {},
    });
    return doc.id;
  }

  // ── Watch messages ──────────────────────────────────────────────────────────
  Stream<List<ChatMessageModel>> watchMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map(ChatMessageModel.fromFirestore)
            .toList());
  }

  // ── Send message ────────────────────────────────────────────────────────────
  Future<void> sendMessage(
    String chatId, {
    required String senderId,
    required String senderName,
    String? text,
    String? fileUrl,
    String? fileType,
    String? fileName,
  }) async {
    await _chats.doc(chatId).collection('messages').add({
      'senderId': senderId,
      'senderName': senderName,
      if (text != null && text.isNotEmpty) 'text': text,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileType != null) 'fileType': fileType,
      if (fileName != null) 'fileName': fileName,
      'timestamp': FieldValue.serverTimestamp(),
      'isDeleted': false,
    });
  }

  // ── Upload file to Supabase Storage ────────────────────────────────────────
  Future<String> uploadFile(
    String chatId,
    Uint8List bytes,
    String fileName,
  ) async {
    final path = 'chats/$chatId/$fileName';
    await _supabase.storage
        .from('task-attachments')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () =>
              throw Exception('Upload timed out — check connection'),
        );
    return _supabase.storage
        .from('task-attachments')
        .getPublicUrl(path);
  }

  // ── Soft delete message ─────────────────────────────────────────────────────
  Future<void> softDeleteMessage(String chatId, String messageId) async {
    await _chats
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'isDeleted': true});
  }

  // ── Update members list ─────────────────────────────────────────────────────
  Future<void> updateMembers(String chatId, List<String> memberIds) async {
    await _chats.doc(chatId).update({'members': memberIds});
  }

  // ── Update lastSeen for a user ──────────────────────────────────────────────
  Future<void> updateLastSeen(String chatId, String userId) async {
    try {
      await _chats.doc(chatId).update({
        'lastSeen.$userId': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // ignore if chat doc not found
    }
  }

  // ── Delete entire chat (messages + doc) ────────────────────────────────────
  Future<void> deleteChat(String chatId) async {
    const batchSize = 400;
    QuerySnapshot snap;
    do {
      snap = await _chats
          .doc(chatId)
          .collection('messages')
          .limit(batchSize)
          .get();
      if (snap.docs.isNotEmpty) {
        final batch = _db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } while (snap.docs.length == batchSize);
    await _chats.doc(chatId).delete();
  }
}
