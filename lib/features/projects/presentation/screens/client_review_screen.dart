import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/controllers/home_providers.dart';
import '../../../projects/data/models/task_model.dart';
import '../../../projects/presentation/controllers/task_providers.dart';
import '../widgets/task_attachments_widget.dart';
import 'task_details_screen.dart';

// ── Screen ────────────────────────────────────────────────────────────────────
// يُفتح من شاشة المشروع بتمرير projectId و projectName
class ClientReviewScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String projectName;

  const ClientReviewScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  ConsumerState<ClientReviewScreen> createState() => _ClientReviewScreenState();
}

class _ClientReviewScreenState extends ConsumerState<ClientReviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

    // badge: عدد التاسكات في انتظار رد العميل
    final pendingCount = ref.watch(
      pendingClientReviewCountProvider(widget.projectId),
    );

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Client Review',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              widget.projectName,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Awaiting Client'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    _BadgeDot(count: pendingCount, color: Colors.orange),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Client Approved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: تاسكات عند العميل للمراجعة
          _AwaitingClientTab(
            projectId: widget.projectId,
            projectName: widget.projectName,
          ),
          // Tab 2: تاسكات اعتمدها العميل
          _ClientApprovedTab(projectId: widget.projectId),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Awaiting Client
// ══════════════════════════════════════════════════════════════════════════════

class _AwaitingClientTab extends ConsumerWidget {
  final String projectId;
  final String projectName;

  const _AwaitingClientTab({
    required this.projectId,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref
        .watch(projectTasksProvider(projectId))
        .maybeWhen(
          data: (allTasks) =>
              allTasks.where((t) => t.status == 'client_review').toList(),
          orElse: () => [],
        );

    if (tasks.isEmpty) {
      return const _EmptyState(
        icon: Icons.send_outlined,
        message: 'No tasks awaiting client review',
      );
    }

    // تجميع التاسكات بالـ discipline
    final byDiscipline = <String, List<TaskModel>>{};
    for (final t in tasks) {
      byDiscipline.putIfAbsent(t.discipline, () => []).add(t);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: byDiscipline.entries.map((entry) {
        return _DisciplineSection(
          discipline: entry.key,
          tasks: entry.value,
          mode: _ReviewMode.awaitingClient,
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Client Approved
// ══════════════════════════════════════════════════════════════════════════════

class _ClientApprovedTab extends ConsumerWidget {
  final String projectId;

  const _ClientApprovedTab({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(projectTasksProvider(projectId));

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tasks) {
        final approved = tasks.where((t) => t.status == 'completed').toList();

        if (approved.isEmpty) {
          return const _EmptyState(
            icon: Icons.check_circle_outline,
            message: 'No client-approved tasks yet',
          );
        }

        final byDiscipline = <String, List<TaskModel>>{};
        for (final t in approved) {
          byDiscipline.putIfAbsent(t.discipline, () => []).add(t);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: byDiscipline.entries.map((entry) {
            return _DisciplineSection(
              discipline: entry.key,
              tasks: entry.value,
              mode: _ReviewMode.viewOnly,
            );
          }).toList(),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Discipline Section (مجموعة تاسكات لكل قسم)
// ══════════════════════════════════════════════════════════════════════════════

enum _ReviewMode { awaitingClient, viewOnly }

class _DisciplineSection extends StatefulWidget {
  final String discipline;
  final List<TaskModel> tasks;
  final _ReviewMode mode;

  const _DisciplineSection({
    required this.discipline,
    required this.tasks,
    required this.mode,
  });

  @override
  State<_DisciplineSection> createState() => _DisciplineSectionState();
}

class _DisciplineSectionState extends State<_DisciplineSection> {
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
          // ── Section Header ─────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.discipline,
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count task${count > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const Spacer(),
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

          // ── Task Cards ─────────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1),
            ...widget.tasks.asMap().entries.map((entry) {
              final i = entry.key;
              final task = entry.value;
              final isLast = i == widget.tasks.length - 1;
              return Column(
                children: [
                  _ClientReviewCard(task: task, mode: widget.mode),
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
// Client Review Card
// ══════════════════════════════════════════════════════════════════════════════

class _ClientReviewCard extends ConsumerWidget {
  final TaskModel task;
  final _ReviewMode mode;

  const _ClientReviewCard({required this.task, required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskDetailsScreen(
              taskId: task.id,
              projectId: task.projectId,
              officeId: task.officeId,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title + Round ────────────────────────────────────────
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
                if (task.status == 'completed')
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await ref
                          .read(taskRepositoryProvider)
                          .deleteTask(task.id);
                    },
                  ),
                _StatusBadge(status: task.status),
              ],
            ),

            const SizedBox(height: 6),

            // ── Meta ─────────────────────────────────────────────────
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _MetaItem(
                  icon: Icons.person_outline,
                  label: task.assignedEngineerNames.join(', '),
                ),
                _MetaItem(
                  icon: Icons.supervisor_account_outlined,
                  label: task.teamLeaderName,
                ),
                if (task.submittedToClientAt != null)
                  _MetaItem(
                    icon: Icons.send_rounded,
                    label: _fmtDate(task.submittedToClientAt!),
                  ),
              ],
            ),

            // ── Reviewer Notes ────────────────────────────────────────
            if (task.qcReviewNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _NoteBox(
                label: 'Reviewer notes',
                note: task.qcReviewNotes,
                color: Colors.purple,
                icon: Icons.rate_review_outlined,
              ),
            ],

            // ── Previous Client Comments ──────────────────────────────
            if (task.clientComments.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PreviousCommentsWidget(comments: task.clientComments),
            ],

            // ── Actions (Awaiting mode only) ──────────────────────────
            if (mode == _ReviewMode.awaitingClient &&
                task.status == 'client_review') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showClientFeedback(context, ref, reject: true),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Client Rejected'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _showClientFeedback(context, ref, reject: false),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Client Approved'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ── Approved stamp ────────────────────────────────────────
            if (mode == _ReviewMode.viewOnly &&
                task.clientReviewedAt != null &&
                task.status == 'completed') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    size: 14,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Approved ${_fmtDate(task.clientReviewedAt!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showClientFeedback(
    BuildContext context,
    WidgetRef ref, {
    required bool reject,
  }) {
    final container = ProviderScope.containerOf(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: _ClientFeedbackSheet(
          task: task,
          reject: reject,
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ══════════════════════════════════════════════════════════════════════════════
// Client Feedback BottomSheet — with Attachments support
// ══════════════════════════════════════════════════════════════════════════════

class _ClientFeedbackSheet extends ConsumerStatefulWidget {
  final TaskModel task;
  final bool reject;

  const _ClientFeedbackSheet({required this.task, required this.reject});

  @override
  ConsumerState<_ClientFeedbackSheet> createState() =>
      _ClientFeedbackSheetState();
}

class _ClientFeedbackSheetState extends ConsumerState<_ClientFeedbackSheet> {
  late final TextEditingController _notesController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reject = widget.reject;
    final task = widget.task;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final actionColor = reject ? Colors.red : Colors.green;
    final actionLabel = reject ? 'Confirm Rejection' : 'Confirm Approval';
    final actionIcon =
        reject ? Icons.cancel_outlined : Icons.check_circle_outline;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Column(
              children: [
                // ── Handle ──────────────────────────────────────────
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                // ── Header ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Row(
                    children: [
                      Icon(actionIcon, color: actionColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reject ? 'Client Rejected' : 'Client Approved',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: actionColor,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ── Scrollable body ──────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Task title
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          task.projectName,
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Reject warning
                        if (reject) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Task will return to QC for revision.',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Attachments ──────────────────────────────
                        Text(
                          'Attachments',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TaskAttachmentsWidget(
                          taskId: task.id,
                          projectId: task.projectId,
                          officeId: task.officeId,
                          isReadOnly: false, // Client can upload attachments
                        ),
                        const SizedBox(height: 20),

                        // ── Notes ────────────────────────────────────
                        Text(
                          reject ? 'Rejection Notes' : 'Approval Notes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _notesController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: reject
                                ? 'Enter rejection comments...'
                                : 'Optional approval notes...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // ── Action buttons ───────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border(
                      top: BorderSide(
                          color: cs.outlineVariant.withOpacity(0.4)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: actionColor),
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(actionIcon, size: 16),
                          label: Text(actionLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final userName =
        ref.read(currentUserProvider).value?.name ?? 'Client';
    final repo = ref.read(taskRepositoryProvider);
    try {
      debugPrint('[ClientFeedback] submitting reject=${widget.reject} taskId=${widget.task.id}');
      if (widget.reject) {
        await repo.clientRejectToQc(
          taskId: widget.task.id,
          notes: _notesController.text.trim(),
          userName: userName,
        );
      } else {
        await repo.clientApproveTask(
          taskId: widget.task.id,
          notes: _notesController.text.trim(),
          userName: userName,
        );
      }
      debugPrint('[ClientFeedback] SUCCESS');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.reject
                  ? 'Returned to QC for revision ✓'
                  : 'Task approved ✓',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Previous Comments Widget (collapsed by default)
// ══════════════════════════════════════════════════════════════════════════════

class _PreviousCommentsWidget extends StatefulWidget {
  final List<Map<String, dynamic>> comments;
  const _PreviousCommentsWidget({required this.comments});

  @override
  State<_PreviousCommentsWidget> createState() =>
      _PreviousCommentsWidgetState();
}

class _PreviousCommentsWidgetState extends State<_PreviousCommentsWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = widget.comments.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 13,
                color: cs.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 4),
              Text(
                'Previous client comments ($count)',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withOpacity(0.6),
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: cs.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          ...widget.comments.map((c) {
            final text = c['text'] as String? ?? '';
            final round = c['round'] as int? ?? 0;
            final type = c['type'] as String? ?? '';
            final createdAt = c['createdAt'];
            final isRejected = type == 'rejected';

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isRejected
                    ? Colors.red.withOpacity(0.05)
                    : Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isRejected
                      ? Colors.red.withOpacity(0.2)
                      : Colors.green.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isRejected
                            ? Icons.cancel_outlined
                            : Icons.check_circle_outline,
                        size: 12,
                        color: isRejected ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isRejected ? 'Rejected' : 'Approved'} — Round $round',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isRejected ? Colors.red : Colors.green,
                        ),
                      ),
                      const Spacer(),
                      if (createdAt is Timestamp)
                        Text(
                          _fmtTs(createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurface.withOpacity(0.4),
                          ),
                        ),
                    ],
                  ),
                  if (text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(text, style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  String _fmtTs(Timestamp ts) {
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Reusable Widgets
// ══════════════════════════════════════════════════════════════════════════════

class _BadgeDot extends StatelessWidget {
  final int count;
  final Color color;
  const _BadgeDot({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
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
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    late Color color;
    late String label;

    switch (status) {
      case 'in_progress':
        color = Colors.grey;
        label = 'In Progress';
        break;
      case 'team_leader_review':
        color = Colors.blue;
        label = 'Team Leader Review';
        break;
      case 'qc_review':
        color = Colors.orange;
        label = 'QC Review';
        break;
      case 'client_review':
        color = Colors.purple;
        label = 'Client Review';
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
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

class _RoundBadge extends StatelessWidget {
  final int round;
  const _RoundBadge({required this.round});

  @override
  Widget build(BuildContext context) {
    final color = round == 1
        ? Colors.blue
        : round == 2
        ? Colors.orange
        : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        'Round $round',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaItem({required this.icon, required this.label});

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
          style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
        ),
      ],
    );
  }
}

class _NoteBox extends StatelessWidget {
  final String label;
  final String note;
  final Color color;
  final IconData icon;

  const _NoteBox({
    required this.label,
    required this.note,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(note, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
          Text(message, style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
        ],
      ),
    );
  }
}
