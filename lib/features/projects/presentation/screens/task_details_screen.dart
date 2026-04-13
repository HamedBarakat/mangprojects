import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/task_providers.dart';
import '../widgets/task_attachments_widget.dart';
import '../widgets/task_activity_widget.dart';
import '../../../home/presentation/controllers/home_providers.dart';

class TaskDetailsScreen extends ConsumerStatefulWidget {
  final String taskId;
  final String projectId;
  final String officeId;

  const TaskDetailsScreen({
    super.key,
    required this.taskId,
    required this.projectId,
    required this.officeId,
  });

  @override
  ConsumerState<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends ConsumerState<TaskDetailsScreen> {
  bool _deleting = false;

  Future<void> _confirmAndDelete(String taskId, String taskTitle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task Permanently?'),
        content: Text(
          '"$taskTitle"\n\nThis cannot be undone. All attachments and activity history will be erased.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final ctrl = ref.read(deleteTaskAttachmentControllerProvider);
      final firestore = FirebaseFirestore.instance;
      final taskRef = firestore.collection('tasks').doc(taskId);

      // 1. Fetch & delete all attachments (Supabase Storage + Firestore docs)
      final attachSnap = await taskRef.collection('attachments').get();
      for (final doc in attachSnap.docs) {
        final storagePath = (doc.data()['storagePath'] as String?) ?? '';
        await ctrl.submit(
          officeId: widget.officeId,
          projectId: widget.projectId,
          taskId: taskId,
          attachmentId: doc.id,
          storagePath: storagePath,
        );
      }

      // 2. Delete comments subcollection
      final commentsSnap = await taskRef.collection('comments').get();
      // 3. Delete task_activities subcollection
      final activitiesSnap = await taskRef.collection('task_activities').get();

      final batch = firestore.batch();
      for (final doc in commentsSnap.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in activitiesSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // 4. Delete the main task document
      await taskRef.delete();

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete task: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final taskAsync = ref.watch(taskByIdProvider(widget.taskId));
    final isAdmin = ref.watch(currentUserProvider).value?.isAdmin ?? false;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Task Details'),
          actions: [
            if (isAdmin)
              taskAsync.maybeWhen(
                data: (task) => task == null
                    ? const SizedBox.shrink()
                    : _deleting
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete Task',
                            color: cs.error,
                            onPressed: () =>
                                _confirmAndDelete(task.id, task.title),
                          ),
                orElse: () => const SizedBox.shrink(),
              ),
          ],
        ),
        body: taskAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),

          error: (e, _) {
            final errorText = e.toString();
            final match = RegExp(r'https://[^\s]+').firstMatch(errorText);
            final url = match?.group(0);

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 48, color: Colors.orange),
                    const SizedBox(height: 12),
                    const Text(
                      'Firestore Index Required',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A database index needs to be created before this view can load.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (url != null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Create Index in Firebase Console'),
                        onPressed: () async {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                  ],
                ),
              ),
            );
          },

          data: (task) {
            if (task == null) {
              return const Center(child: Text('Task not found'));
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Text(
                            task.projectName,
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 12),

                          _StatusBadge(status: task.status),

                          const SizedBox(height: 16),

                          const Text("Progress"),
                          const SizedBox(height: 6),

                          LinearProgressIndicator(
                            value: task.normalizedProgress / 100,
                          ),
                        ],
                      ),
                    ),

                    const TabBar(
                      tabs: [
                        Tab(text: "Overview"),
                        Tab(text: "Attachments"),
                        Tab(text: "Activity"),
                      ],
                    ),

                    Expanded(
                      child: TabBarView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Task Info",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text("Title: ${task.title}"),
                                Text("Project: ${task.projectName}"),
                                Text("Status: ${task.status}"),
                                Text("Progress: ${task.normalizedProgress}%"),
                              ],
                            ),
                          ),

                          SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: TaskAttachmentsWidget(
                                taskId: task.id,
                                projectId: task.projectId,
                                officeId: task.officeId,
                                isReadOnly: true,
                              ),
                            ),
                          ),

                          TaskActivityWidget(taskId: task.id),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'not_started' => (Colors.grey, 'Not Started'),
      'in_progress' => (Colors.blue, 'In Progress'),
      'team_leader_review' => (Colors.teal, 'Team Leader Review'),
      'qc_review' => (Colors.orange, 'QC Review'),
      'client_review' => (Colors.purple, 'Client Review'),
      'completed' => (Colors.green, 'Completed'),
      _ => (Colors.grey, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
