import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/controllers/home_providers.dart';
import '../../../projects/data/models/task_model.dart';
import '../../../projects/data/task_repository.dart';
import '../../../projects/presentation/controllers/task_providers.dart';

class MyTasksScreen extends ConsumerStatefulWidget {
  const MyTasksScreen({super.key});

  @override
  ConsumerState<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends ConsumerState<MyTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    final isReviewer = user?.isReviewer ?? false;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: const Text(
          'My Tasks',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: isReviewer
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'My Tasks'),
                  Tab(text: 'For Review'),
                ],
              )
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: _FilterBar(
                  selected: _statusFilter,
                  onChanged: (v) => setState(() => _statusFilter = v),
                ),
              ),
      ),
      body: isReviewer
          ? TabBarView(
              controller: _tabController,
              children: [
                _MyTasksList(statusFilter: _statusFilter, user: user),
                _ReviewTasksList(user: user),
              ],
            )
          : _MyTasksList(statusFilter: _statusFilter, user: user),
    );
  }
}

// ── Filter Bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _FilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filters = [
      ('all', 'All'),
      ('not_started', 'Not Started'),
      ('in_progress', 'In Progress'),
      ('under_review', 'Under Review'),
      ('completed', 'Completed'),
    ];

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: filters.map((f) {
          final isSelected = selected == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? cs.primary : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  f.$2,
                  style: TextStyle(
                    color: isSelected ? Colors.white : cs.onSurface,
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── My Tasks List ─────────────────────────────────────────────────────────────

class _MyTasksList extends ConsumerWidget {
  final String statusFilter;
  final dynamic user;

  const _MyTasksList({required this.statusFilter, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tasksAsync = user?.canManageTasks == true
        ? ref.watch(teamTasksProvider)
        : ref.watch(myTasksProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tasks) {
        final filtered = statusFilter == 'all'
            ? tasks
            : tasks.where((t) => t.status == statusFilter).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.task_outlined,
                  size: 64,
                  color: cs.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  statusFilter == 'all'
                      ? 'No tasks assigned yet'
                      : 'No ${_statusLabel(statusFilter)} tasks',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) =>
              _MyTaskCard(task: filtered[i], user: user, ref: ref),
        );
      },
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'not_started':
        return 'Not Started';
      case 'in_progress':
        return 'In Progress';
      case 'under_review':
        return 'Under Review';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }
}

// ── Review Tasks List ─────────────────────────────────────────────────────────

class _ReviewTasksList extends ConsumerWidget {
  final dynamic user;
  const _ReviewTasksList({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tasksAsync = ref.watch(tasksForReviewProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  size: 64,
                  color: cs.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'No tasks pending review',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _MyTaskCard(
            task: tasks[i],
            user: user,
            ref: ref,
            showReviewActions: true,
          ),
        );
      },
    );
  }
}

// ── Task Card ─────────────────────────────────────────────────────────────────

class _MyTaskCard extends StatelessWidget {
  final TaskModel task;
  final dynamic user;
  final WidgetRef ref;
  final bool showReviewActions;

  const _MyTaskCard({
    required this.task,
    required this.user,
    required this.ref,
    this.showReviewActions = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                _StatusBadge(status: task.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.business_center_outlined,
                  size: 13,
                  color: cs.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    task.projectName,
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _InfoChip(icon: Icons.category_outlined, label: task.category),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.engineering_outlined,
                  label: task.discipline,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 13,
                  color: cs.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '${task.actualHours.toStringAsFixed(1)}h / ${task.plannedHours.toStringAsFixed(1)}h',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.event_outlined,
                  size: 13,
                  color: cs.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '${task.endDate.day}/${task.endDate.month}/${task.endDate.year}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isOverdue()
                        ? Colors.red
                        : cs.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.plannedHours > 0
                    ? (task.actualHours / task.plannedHours).clamp(0.0, 1.0)
                    : 0,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  task.actualHours > task.plannedHours
                      ? Colors.orange
                      : cs.primary,
                ),
                minHeight: 5,
              ),
            ),
            if (task.approvalStatus != 'pending') ...[
              const SizedBox(height: 8),
              _ApprovalBadge(status: task.approvalStatus),
              if (task.approvalNotes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '📝 ${task.approvalNotes}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
            // ── Client Comments ───────────────────────────────────────
            if (task.clientComments.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              _ClientCommentsSection(comments: task.clientComments),
            ],
            if (_shouldShowActions()) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _buildActions(context),
            ],
          ],
        ),
      ),
    );
  }

  bool _isOverdue() {
    return task.endDate.isBefore(DateTime.now()) && task.status != 'completed';
  }

  bool _shouldShowActions() {
    if (showReviewActions && task.status == 'under_review') return true;
    if (!showReviewActions && task.status == 'not_started') return true;
    if (!showReviewActions && task.status == 'in_progress') return true;
    return false;
  }

  Widget _buildActions(BuildContext context) {
    if (showReviewActions) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _reviewTask(context, 'rejected'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: const Text('Reject'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _reviewTask(context, 'approved_with_comments'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
              ),
              child: const Text('With Comments'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: () => _reviewTask(context, 'approved'),
              child: const Text('Approve'),
            ),
          ),
        ],
      );
    }

    if (task.status == 'not_started') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _updateStatus(context, 'in_progress'),
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text('Start Task'),
        ),
      );
    }

    if (task.status == 'in_progress') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _submitForReview(context),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('Submit for Review'),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _updateStatus(BuildContext context, String status) async {
    await ref
        .read(taskRepositoryProvider)
        .updateTaskStatus(taskId: task.id, status: status);
  }

  Future<void> _submitForReview(BuildContext context) async {
    await ref.read(taskRepositoryProvider).submitForReview(task.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task submitted for review ✓')),
      );
    }
  }

  void _reviewTask(BuildContext context, String approvalStatus) {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          approvalStatus == 'approved'
              ? 'Approve Task'
              : approvalStatus == 'rejected'
              ? 'Reject Task'
              : 'Approve with Comments',
        ),
        content: TextField(
          controller: notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: approvalStatus == 'approved'
                ? 'Optional notes...'
                : 'Enter notes...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: approvalStatus == 'rejected'
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(taskRepositoryProvider)
                  .reviewTask(
                    taskId: task.id,
                    approvalStatus: approvalStatus,
                    notes: notesController.text.trim(),
                    reviewerId: user?.uid ?? '',
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Review submitted ✓')),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'not_started':
        color = Colors.grey;
        label = 'Not Started';
        break;
      case 'in_progress':
        color = Colors.blue;
        label = 'In Progress';
        break;
      case 'under_review':
        color = Colors.orange;
        label = 'Under Review';
        break;
      case 'completed':
        color = Colors.green;
        label = 'Completed';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ApprovalBadge extends StatelessWidget {
  final String status;
  const _ApprovalBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = Colors.green;
        label = '✓ Approved';
        break;
      case 'approved_with_comments':
        color = Colors.orange;
        label = '✓ Approved with Comments';
        break;
      case 'rejected':
        color = Colors.red;
        label = '✗ Rejected';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: cs.onSurface.withOpacity(0.5)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CLIENT COMMENTS SECTION
// ══════════════════════════════════════════════════════════════════════════════

class _ClientCommentsSection extends StatefulWidget {
  final List<Map<String, dynamic>> comments;
  const _ClientCommentsSection({required this.comments});

  @override
  State<_ClientCommentsSection> createState() => _ClientCommentsSectionState();
}

class _ClientCommentsSectionState extends State<_ClientCommentsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = widget.comments.length;
    final unread = widget.comments.where((c) => c['isRead'] == false).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header — قابل للضغط للتوسيع
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: unread > 0
                    ? Colors.orange.withOpacity(0.12)
                    : Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Icon(
                  Icons.comment_outlined,
                  size: 13,
                  color: unread > 0 ? Colors.orange : Colors.blue,
                ),
                const SizedBox(width: 5),
                Text(
                  unread > 0
                      ? 'Client Notes ($unread new)'
                      : 'Client Notes ($count)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: unread > 0 ? Colors.orange : Colors.blue,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: unread > 0 ? Colors.orange : Colors.blue,
                ),
              ]),
            ),
          ]),
        ),

        // Comments list — قابلة للتوسيع
        if (_expanded) ...[
          const SizedBox(height: 10),
          ...widget.comments.map((c) {
            final text      = c['text'] as String? ?? '';
            final isRead    = c['isRead'] as bool? ?? true;
            final createdAt = c['createdAt'];
            final dateStr   = _fmtTimestamp(createdAt);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isRead
                    ? cs.surfaceContainerHighest.withOpacity(0.5)
                    : Colors.orange.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isRead
                      ? Colors.transparent
                      : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline, size: 14, color: Colors.blue),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('Client',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (!isRead)
                          Container(
                            width: 7, height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 4),
                        Text(dateStr,
                            style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurface.withOpacity(0.4))),
                      ]),
                      const SizedBox(height: 4),
                      Text(text, style: const TextStyle(fontSize: 12)),
                    ],
                  )),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  String _fmtTimestamp(dynamic v) {
    if (v == null) return '';
    try {
      DateTime d;
      if (v is Timestamp) {
        d = v.toDate();
      } else {
        return '';
      }
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return '';
    }
  }
}
