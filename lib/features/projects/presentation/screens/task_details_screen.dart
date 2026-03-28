import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/task_providers.dart';
import '../widgets/task_attachments_widget.dart';
import '../widgets/task_activity_widget.dart';

class TaskDetailsScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final taskAsync = ref.watch(taskByIdProvider(taskId));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: const Text('Task Details')),
        body: taskAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),

          /// ✅ FIXED: Clickable Firebase link
          error: (e, _) {
            final errorText = e.toString();

            // 🔥 طباعة الخطأ كامل في Terminal
            debugPrint('🔥 FIRESTORE ERROR START');
            debugPrint(errorText);
            debugPrint('🔥 FIRESTORE ERROR END');

            // 🔍 استخراج اللينك من النص
            String? url;
            final match = RegExp(r'https://[^\s]+').firstMatch(errorText);
            if (match != null) {
              url = match.group(0);
            }

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '⚠ Firestore Index Required',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (url != null)
                    ElevatedButton(
                      onPressed: () {
                        debugPrint('👉 OPEN THIS LINK: $url');
                      },
                      child: const Text('Print Index Link in Terminal'),
                    ),
                ],
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

                          /// ✅ FIXED: Read-only attachments
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

String _extractUrl(String text) {
  final regex = RegExp(r'https://[^\s]+');
  final match = regex.firstMatch(text);
  return match?.group(0) ?? '';
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
