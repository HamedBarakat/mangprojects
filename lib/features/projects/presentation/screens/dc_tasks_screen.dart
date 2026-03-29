import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../home/presentation/controllers/home_providers.dart';
import '../../data/models/task_model.dart';
import '../controllers/task_providers.dart';
import '../widgets/task_attachments_widget.dart';
import 'task_details_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// DC TASKS SCREEN
//
// Document Controller sees tasks in client_review status.
// Workflow for DC:
//   1. QC approves → task enters client_review → DC gets notification
//   2. DC prepares official submittal documents (uploads attachments here)
//   3. DC marks task as "Sent to Client" (dcSentAt is recorded)
//   4. Task remains in client_review until client approves/rejects
//
// Tabs:
//   "Pending Dispatch"  — client_review + dcSentAt == null  (need to send)
//   "Sent to Client"    — client_review + dcSentAt != null  (already dispatched)
//   "All Tasks"         — full office view for oversight
// ══════════════════════════════════════════════════════════════════════════════

class DCTasksScreen extends ConsumerStatefulWidget {
  const DCTasksScreen({super.key});

  @override
  ConsumerState<DCTasksScreen> createState() => _DCTasksScreenState();
}

class _DCTasksScreenState extends ConsumerState<DCTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider).value;
    final tasksAsync = ref.watch(allVisibleTasksProvider);

    final pendingCount = tasksAsync.maybeWhen(
      data: (tasks) => tasks
          .where((t) =>
              t.status == 'client_review' && t.dcSentAt == null)
          .length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'DC Tasks',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pending Dispatch'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    _Badge(count: pendingCount, color: Colors.orange),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Sent to Client'),
            const Tab(text: 'All Tasks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DCTasksList(user: user, filter: _DCFilter.pendingDispatch),
          _DCTasksList(user: user, filter: _DCFilter.sentToClient),
          _DCTasksList(user: user, filter: _DCFilter.allActive),
        ],
      ),
    );
  }
}

// ── Filter enum ───────────────────────────────────────────────────────────────
enum _DCFilter { pendingDispatch, sentToClient, allActive }

// ══════════════════════════════════════════════════════════════════════════════
// Tasks List
// ══════════════════════════════════════════════════════════════════════════════

class _DCTasksList extends ConsumerWidget {
  final dynamic user;
  final _DCFilter filter;

  const _DCTasksList({required this.user, required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allVisibleTasksProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tasks) {
        List<TaskModel> filtered;

        switch (filter) {
          case _DCFilter.pendingDispatch:
            // Ready to send: QC approved, not yet dispatched by DC
            filtered = tasks
                .where((t) =>
                    t.status == 'client_review' && t.dcSentAt == null)
                .toList()
              ..sort((a, b) =>
                  (a.submittedToClientAt ?? a.endDate)
                      .compareTo(b.submittedToClientAt ?? b.endDate));
          case _DCFilter.sentToClient:
            // Already dispatched — waiting for client decision
            filtered = tasks
                .where((t) =>
                    t.status == 'client_review' && t.dcSentAt != null)
                .toList()
              ..sort((a, b) =>
                  (b.dcSentAt ?? b.endDate)
                      .compareTo(a.dcSentAt ?? a.endDate));
          case _DCFilter.allActive:
            // All non-completed tasks for oversight
            filtered = tasks
                .where((t) => t.status != 'completed')
                .toList()
              ..sort((a, b) => a.endDate.compareTo(b.endDate));
        }

        if (filtered.isEmpty) {
          final msg = switch (filter) {
            _DCFilter.pendingDispatch => 'No tasks pending dispatch',
            _DCFilter.sentToClient => 'No tasks sent to client yet',
            _DCFilter.allActive => 'No active tasks',
          };
          return _EmptyState(
            icon: filter == _DCFilter.pendingDispatch
                ? Icons.outbox_outlined
                : Icons.mark_email_read_outlined,
            message: msg,
          );
        }

        // Group by project
        final byProject = <String, List<TaskModel>>{};
        for (final t in filtered) {
          byProject.putIfAbsent(t.projectName, () => []).add(t);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: byProject.entries.map((entry) {
            return _ProjectGroup(
              projectName: entry.key,
              tasks: entry.value,
              user: user,
              filter: filter,
            );
          }).toList(),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Project Group
// ══════════════════════════════════════════════════════════════════════════════

class _ProjectGroup extends StatefulWidget {
  final String projectName;
  final List<TaskModel> tasks;
  final dynamic user;
  final _DCFilter filter;

  const _ProjectGroup({
    required this.projectName,
    required this.tasks,
    required this.user,
    required this.filter,
  });

  @override
  State<_ProjectGroup> createState() => _ProjectGroupState();
}

class _ProjectGroupState extends State<_ProjectGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = widget.tasks.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.business_center_outlined, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.projectName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '$count task${count > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: cs.onSurface.withOpacity(0.4),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            ...widget.tasks.asMap().entries.map((e) {
              final isLast = e.key == widget.tasks.length - 1;
              return Column(
                children: [
                  _DCTaskCard(
                    task: e.value,
                    user: widget.user,
                    filter: widget.filter,
                  ),
                  if (!isLast) const Divider(height: 1, indent: 16),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DC Task Card
// ══════════════════════════════════════════════════════════════════════════════

class _DCTaskCard extends ConsumerWidget {
  final TaskModel task;
  final dynamic user;
  final _DCFilter filter;

  const _DCTaskCard({
    required this.task,
    required this.user,
    required this.filter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isPending = filter == _DCFilter.pendingDispatch;
    final isSent = task.dcSentAt != null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TaskDetailsScreen(
            taskId: task.id,
            projectId: task.projectId,
            officeId: task.officeId,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title + Status ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isSent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mark_email_read_outlined,
                            size: 11, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'Sent',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.outbox_outlined,
                            size: 11, color: Colors.orange),
                        SizedBox(width: 4),
                        Text(
                          'Pending Dispatch',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Info row ───────────────────────────────────────────
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Info(
                    icon: Icons.person_outline,
                    label: task.assignedEngineerNames.join(', ')),
                _Info(
                    icon: Icons.supervisor_account_outlined,
                    label: task.teamLeaderName),
                _Info(
                    icon: Icons.verified_user_outlined,
                    label: 'QC: ${task.reviewerName}'),
              ],
            ),
            const SizedBox(height: 6),

            // ── Submission info ────────────────────────────────────
            if (task.submittedToClientAt != null)
              _InfoRow(
                icon: Icons.send_rounded,
                label:
                    'QC submitted: ${_fmt(task.submittedToClientAt!)}  •  Round ${task.clientReviewRound}',
                color: Colors.purple,
              ),

            if (task.qcReviewNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _NoteChip(
                label: 'QC Note',
                note: task.qcReviewNotes,
                color: Colors.purple,
                icon: Icons.rate_review_outlined,
              ),
            ],

            // ── DC Sent timestamp ──────────────────────────────────
            if (isSent) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.mark_email_read_outlined,
                label:
                    'Sent by ${task.dcSentByName} on ${_fmt(task.dcSentAt!)}',
                color: Colors.green,
              ),
            ],

            // ── Attachments ────────────────────────────────────────
            const SizedBox(height: 10),
            TaskAttachmentsWidget(
              taskId: task.id,
              projectId: task.projectId,
              officeId: task.officeId,
              isReadOnly: false, // DC can always upload submittal docs
            ),

            // ── Action button (only on pending) ────────────────────
            if (isPending && !isSent) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _confirmSent(context, ref),
                  icon:
                      const Icon(Icons.mark_email_read_outlined, size: 18),
                  label: const Text(
                    'Mark as Sent to Client',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],

            // ── Already sent — awaiting client ─────────────────────
            if (isSent && task.status == 'client_review') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_bottom_rounded,
                        size: 14,
                        color: cs.onSurface.withOpacity(0.5)),
                    const SizedBox(width: 8),
                    Text(
                      'Awaiting client decision',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmSent(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mark_email_read_outlined, color: Colors.teal),
            SizedBox(width: 8),
            Text('Confirm Dispatch'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${task.title}"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Confirm that this task has been officially sent to the client via formal submittal.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              Navigator.pop(context);
              final dcName =
                  ref.read(currentUserProvider).value?.name ?? 'DC';
              try {
                await ref
                    .read(taskRepositoryProvider)
                    .markTaskSentByDC(taskId: task.id, dcName: dcName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Task marked as sent to client ✓'),
                      backgroundColor: Colors.teal,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Confirm Sent'),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ══════════════════════════════════════════════════════════════════════════════
// Reusable Widgets
// ══════════════════════════════════════════════════════════════════════════════

class _Badge extends StatelessWidget {
  final int count;
  final Color color;
  const _Badge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Info({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: cs.onSurface.withOpacity(0.4)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoRow(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 13, color: color.withOpacity(0.8)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
}

class _NoteChip extends StatelessWidget {
  final String label, note;
  final Color color;
  final IconData icon;
  const _NoteChip(
      {required this.label,
      required this.note,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(note, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: cs.onSurface.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
        ],
      ),
    );
  }
}
