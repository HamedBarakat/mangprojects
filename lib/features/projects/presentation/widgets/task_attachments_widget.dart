import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../home/presentation/controllers/home_providers.dart';
import '../../data/models/task_attachment_model.dart';
import '../controllers/task_providers.dart';

class TaskAttachmentsWidget extends ConsumerStatefulWidget {
  final String taskId;
  final String projectId;
  final String officeId;

  /// ✅ NEW (safe addition)
  final bool isReadOnly;

  const TaskAttachmentsWidget({
    super.key,
    required this.taskId,
    required this.projectId,
    required this.officeId,
    this.isReadOnly = false, // ✅ default keeps old behavior
  });

  @override
  ConsumerState<TaskAttachmentsWidget> createState() =>
      _TaskAttachmentsWidgetState();
}

class _TaskAttachmentsWidgetState extends ConsumerState<TaskAttachmentsWidget> {
  bool _uploading = false;
  late final TaskScope _scope;

  void _log(String message) {
    debugPrint('[TaskAttachmentsWidget] $message');
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

  Future<void> _pickAndUploadFile() async {
    try {
      _log('pickAndUploadFile START taskId=${widget.taskId}');

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final picked = result.files.first;

      setState(() => _uploading = true);

      final user = await ref.read(currentUserProvider.future);
      if (user == null) throw Exception('User not loaded');

      if (kIsWeb) {
        await ref
            .read(uploadTaskAttachmentControllerProvider)
            .submit(
              officeId: widget.officeId,
              projectId: widget.projectId,
              taskId: widget.taskId,
              user: user,
              bytes: picked.bytes!,
              fileName: picked.name,
            );
      } else {
        await ref
            .read(uploadTaskAttachmentControllerProvider)
            .submit(
              officeId: widget.officeId,
              projectId: widget.projectId,
              taskId: widget.taskId,
              user: user,
              file: File(picked.path!),
              fileName: picked.name,
            );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openAttachment(TaskAttachment attachment) async {
    final uri = Uri.parse(attachment.downloadUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool _isImage(TaskAttachment a) {
    final t = a.fileType.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(t);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final attachmentsAsync = ref.watch(taskAttachmentsProvider(_scope));
    final user = ref.watch(currentUserProvider).value;

    bool canUpload = false;
    if (user != null) {
      if (user.role == 'engineer') canUpload = true;
      if (user.canManageTasks) canUpload = true;
      if (user.isReviewer) canUpload = true;

      // ✅ أضف ده
      if (user.role == 'client') canUpload = true;
    }

    /// ✅ IMPORTANT FIX
    final showUpload = canUpload && !widget.isReadOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.attach_file, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              'Attachments',
              style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
            ),
            const Spacer(),

            /// ✅ Upload hidden in read-only mode
            if (showUpload)
              TextButton.icon(
                onPressed: _uploading ? null : _pickAndUploadFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Upload'),
              ),
          ],
        ),

        const SizedBox(height: 8),

        attachmentsAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (list) {
            if (list.isEmpty) return const Text('No attachments');

            final images = list.where(_isImage).toList();
            final others = list.where((e) => !_isImage(e)).toList();

            return Column(
              children: [
                // ───────── Images Grid ─────────
                if (images.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: images.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                    itemBuilder: (_, i) {
                      final image = images[i];

                      return Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                image.downloadUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          // 🔥 Delete Button
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: widget.isReadOnly
                                  ? null
                                  : () async {
                                      await _deleteAttachment(image.id);
                                    },
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
                      );
                    },
                  ),

                const SizedBox(height: 10),

                // ───────── Other Files ─────────
                ...others.map(
                  (a) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(a.fileName),

                    // فتح الملف
                    onTap: () => _openAttachment(a),

                    // 🔥 Delete Button
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: widget.isReadOnly
                          ? null
                          : () async {
                              await _deleteAttachment(a.id);
                            },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _deleteAttachment(String attachmentId) async {
    await ref
        .read(taskRepositoryProvider)
        .deleteAttachment(taskId: widget.taskId, attachmentId: attachmentId);
  }
}
