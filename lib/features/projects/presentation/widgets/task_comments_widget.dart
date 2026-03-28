import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../home/presentation/controllers/home_providers.dart';
import '../../data/models/task_comment_model.dart';
import '../controllers/task_providers.dart';
import 'task_attachments_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/task_comment_model.dart';
import '../../data/models/task_activity_model.dart';
import '../controllers/task_activity_providers.dart';

class TaskCommentsSection extends ConsumerStatefulWidget {
  final String taskId;
  final String projectId;
  final String officeId;

  const TaskCommentsSection({
    super.key,
    required this.taskId,
    required this.projectId,
    required this.officeId,
  });

  @override
  ConsumerState<TaskCommentsSection> createState() =>
      _TaskCommentsSectionState();
}

class _TaskCommentsSectionState extends ConsumerState<TaskCommentsSection> {
  final _textCtrl = TextEditingController();
  File? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _sending = false;
  late final TaskScope _scope;

  void _log(String message) {
    debugPrint('[TaskCommentsSection] $message');
  }

  @override
  void initState() {
    super.initState();
    _scope = TaskScope(
      officeId: widget.officeId,
      projectId: widget.projectId,
      taskId: widget.taskId,
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      _log('pickImage START taskId=${widget.taskId}');

      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 75,
      );

      if (picked == null) {
        _log('pickImage CANCELLED');
        return;
      }

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = picked.name;
          _selectedImageFile = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _selectedImageFile = File(picked.path);
          _selectedImageBytes = null;
          _selectedImageName = picked.name;
        });
      }

      _log('pickImage SELECTED name=${picked.name}');
    } catch (e, st) {
      _log('pickImage ERROR taskId=${widget.taskId} error=$e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر اختيار الصورة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearSelectedImage() {
    setState(() {
      _selectedImageFile = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    final hasImage = _selectedImageFile != null || _selectedImageBytes != null;

    if (text.isEmpty && !hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب تعليقًا أو اختر صورة أولًا.')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) {
        throw Exception('Current user is not loaded.');
      }

      var finalText = text;

      if (hasImage) {
        final imageName = _selectedImageName ?? 'comment_image';
        await ref
            .read(uploadTaskAttachmentControllerProvider)
            .submit(
              officeId: widget.officeId,
              projectId: widget.projectId,
              taskId: widget.taskId,
              user: user,
              file: _selectedImageFile,
              bytes: _selectedImageBytes,
              fileName: imageName,
            );
        await ref
            .read(taskActivityRepositoryProvider)
            .addActivity(
              TaskActivity(
                id: '',
                taskId: widget.taskId,
                officeId: widget.officeId,
                type: 'attachment',
                message: 'Uploaded image: $imageName',
                userName: user.name,
                userRole: user.role,
                createdAt: DateTime.now(),
              ),
            );
        if (finalText.isEmpty) {
          finalText = 'Image attached: $imageName';
        } else {
          finalText = '$finalText\n[Image attached: $imageName]';
        }
      }

      await ref
          .read(addTaskCommentControllerProvider)
          .submit(
            officeId: widget.officeId,
            projectId: widget.projectId,
            taskId: widget.taskId,
            text: finalText,
            user: user,
          );
      await ref
          .read(taskActivityRepositoryProvider)
          .addActivity(
            TaskActivity(
              id: '',
              taskId: widget.taskId,
              officeId: widget.officeId,
              type: 'comment',
              message: finalText,
              userName: user.name,
              userRole: user.role,
              createdAt: DateTime.now(),
            ),
          );
      _textCtrl.clear();
      _clearSelectedImage();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إرسال التعليق بنجاح.')));
    } catch (e, st) {
      _log('send ERROR taskId=${widget.taskId} error=$e');
      debugPrintStack(stackTrace: st);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل إرسال التعليق: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final commentsAsync = ref.watch(taskCommentsProvider(_scope));
    final currentUser = ref.watch(currentUserProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ───────── Title ─────────
        Row(
          children: [
            Icon(Icons.comment_outlined, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              'Comments',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: cs.primary,
              ),
            ),
            commentsAsync.when(
              data: (comments) => comments.isEmpty
                  ? const SizedBox()
                  : Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${comments.length}',
                        style: TextStyle(
                          color: cs.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ───────── 🔥 Input أول حاجة ─────────
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: CircleAvatar(
                backgroundColor: _sending
                    ? cs.primary.withOpacity(0.6)
                    : cs.primary,
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ───────── Image Preview ─────────
        if (_selectedImageFile != null || _selectedImageBytes != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb
                    ? Image.memory(
                        _selectedImageBytes!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        _selectedImageFile!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: _sending ? null : _clearSelectedImage,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedImageName != null) ...[
            const SizedBox(height: 6),
            Text(
              _selectedImageName!,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withOpacity(0.7),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],

        // ───────── Comments List ─────────
        commentsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text(
            'Comments error: $e',
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
          data: (comments) {
            final sortedComments = [...comments];
            sortedComments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (sortedComments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No comments yet. Be the first to comment.',
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.5),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedComments.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, index) => _CommentBubble(
                comment: sortedComments[index],
                isMe: sortedComments[index].authorId == currentUser?.uid,
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // ───────── Attachments ─────────
        TaskAttachmentsWidget(
          taskId: widget.taskId,
          projectId: widget.projectId,
          officeId: widget.officeId,
        ),
      ],
    );
  }
}

class _CommentBubble extends StatelessWidget {
  final TaskComment comment;
  final bool isMe;

  const _CommentBubble({required this.comment, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe
              ? cs.primary.withOpacity(0.1)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              comment.authorName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            if (comment.authorRole.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  comment.authorRole,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withOpacity(0.55),
                  ),
                ),
              ),
            if (comment.imageUrl != null && comment.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  comment.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 120,
                    width: 220,
                    alignment: Alignment.center,
                    color: cs.surfaceContainerHighest,
                    child: const Text('Failed to load image'),
                  ),
                ),
              ),
            ],
            if (comment.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: GestureDetector(
                  onTap: () async {
                    final uri = Uri.tryParse(comment.text);
                    if (uri != null && (comment.text.startsWith('http'))) {
                      await launchUrl(uri);
                    }
                  },
                  child: Text(
                    comment.text,
                    style: comment.text.startsWith('http')
                        ? const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
