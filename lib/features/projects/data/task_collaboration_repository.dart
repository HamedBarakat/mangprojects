import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/task_attachment_model.dart';
import '../data/models/task_comment_model.dart';

class TaskCollaborationRepository {
  final FirebaseFirestore _firestore;
  final SupabaseClient _supabase;

  TaskCollaborationRepository({
    FirebaseFirestore? firestore,
    SupabaseClient? supabase,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _supabase = supabase ?? Supabase.instance.client;

  void _log(String message) {
    debugPrint('[TaskCollabRepo] $message');
  }

  CollectionReference<Map<String, dynamic>> _commentsRef(String taskId) {
    return _firestore.collection('tasks').doc(taskId).collection('comments');
  }

  CollectionReference<Map<String, dynamic>> _attachmentsRef(String taskId) {
    return _firestore.collection('tasks').doc(taskId).collection('attachments');
  }

  // ================= WATCH =================

  Stream<List<TaskComment>> watchTaskComments({
    required String officeId,
    required String projectId,
    required String taskId,
  }) {
    _log('watchTaskComments START taskId=$taskId');

    return _commentsRef(taskId).orderBy('createdAt').snapshots().map((
      snapshot,
    ) {
      _log('watchTaskComments DATA docs=${snapshot.docs.length}');
      return snapshot.docs.map(TaskComment.fromFirestore).toList();
    });
  }

  Stream<List<TaskAttachment>> watchTaskAttachments({
    required String officeId,
    required String projectId,
    required String taskId,
  }) {
    _log('watchTaskAttachments START taskId=$taskId');

    return _attachmentsRef(
      taskId,
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      _log('watchTaskAttachments DATA docs=${snapshot.docs.length}');
      return snapshot.docs.map(TaskAttachment.fromFirestore).toList();
    });
  }

  // ================= UPLOAD =================

  Future<void> uploadAttachment({
    required String officeId,
    required String projectId,
    required String taskId,
    File? file,
    Uint8List? bytes,
    String? fileName,
    required String uploadedBy,
    required String uploaderName,
    required String uploaderRole,
  }) async {
    _log('🚀 uploadAttachment START taskId=$taskId');

    try {
      if (file == null && (bytes == null || fileName == null)) {
        throw Exception('No file data provided');
      }

      Uint8List data;
      String name;

      if (file != null) {
        data = await file.readAsBytes();
        name = p.basename(file.path);
      } else {
        data = bytes!;
        name = fileName!;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storedName = '${timestamp}_$name';
      final path = 'tasks/$taskId/$storedName';

      _log('📂 Uploading to Supabase path=$path size=${data.length}');

      await _supabase.storage
          .from('task-attachments')
          .uploadBinary(
            path,
            data,
            fileOptions: const FileOptions(upsert: true),
          );

      _log('✅ Upload DONE');

      final publicUrl = _supabase.storage
          .from('task-attachments')
          .getPublicUrl(path);

      _log('🌍 URL=$publicUrl');

      final doc = _attachmentsRef(taskId).doc();

      final model = TaskAttachment(
        id: doc.id,
        taskId: taskId,
        fileName: name,
        fileType: p.extension(name).replaceAll('.', ''),
        fileSize: data.length,
        downloadUrl: publicUrl,
        storagePath: path,
        uploadedBy: uploadedBy,
        uploaderName: uploaderName,
        uploaderRole: uploaderRole,
        hash: '',
        createdAt: DateTime.now(),
      );

      await doc.set(model.toFirestore());

      _log('🔥 Firestore SAVED docId=${doc.id}');
    } catch (e, st) {
      _log('❌ uploadAttachment ERROR: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  // ================= DELETE =================

  Future<void> deleteAttachment({
    required String officeId,
    required String projectId,
    required String taskId,
    required String attachmentId,
    required String storagePath,
  }) async {
    try {
      await _supabase.storage.from('task-attachments').remove([storagePath]);
      await _attachmentsRef(taskId).doc(attachmentId).delete();

      _log('🗑️ Attachment deleted');
    } catch (e) {
      _log('❌ deleteAttachment ERROR: $e');
      rethrow;
    }
  }

  // ================= COMMENT =================

  Future<void> addComment({
    required String officeId,
    required String projectId,
    required String taskId,
    required String authorId,
    required String authorName,
    required String authorRole,
    required String text,
  }) async {
    final doc = _commentsRef(taskId).doc();

    final model = TaskComment(
      id: doc.id,
      taskId: taskId,
      authorId: authorId,
      authorName: authorName,
      authorRole: authorRole,
      text: text.trim(),
      createdAt: DateTime.now(),
    );

    await doc.set(model.toFirestore());
  }
}
