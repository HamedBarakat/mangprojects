import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../controllers/project_providers.dart';
import '../controllers/task_providers.dart';
import '../../../home/presentation/controllers/home_providers.dart';
import '../../../office/presentation/controllers/office_settings_providers.dart';
import '../../../employees/presentation/controllers/employee_providers.dart';
import 'add_edit_project_screen.dart';

class ProjectDetailsScreen extends ConsumerStatefulWidget {
  final ProjectModel project;
  const ProjectDetailsScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectDetailsScreen> createState() =>
      _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends ConsumerState<ProjectDetailsScreen>
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
    final user = ref.watch(currentUserProvider).value;
    final isAdmin = user?.isAdmin ?? false;
    final isTeamLeader = user?.role == 'team_leader';
    final isReviewer = user?.role == 'reviewer';
    final canAddTask = isAdmin || isTeamLeader;

    // ── Real-time project (يتحدث فور تغيير completionPercentage في Firestore) ──
    final projectAsync = ref.watch(singleProjectProvider(widget.project.id));
    final project = projectAsync.value ?? widget.project;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withOpacity(0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        if (isAdmin)
                          IconButton(
                            icon: const Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AddEditProjectScreen(project: project),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _WhiteChip(project.projectCode),
                            const SizedBox(width: 8),
                            _WhiteChip(project.typeLabel),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          project.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          project.clientName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: project.completionPercentage / 100,
                                  backgroundColor: Colors.white.withOpacity(
                                    0.3,
                                  ),
                                  valueColor: const AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${project.completionPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.6),
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Tasks'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(project: project),
                _TasksTab(
                  project: project,
                  canAddTask: canAddTask,
                  isReviewer: isReviewer,
                  currentUser: user,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  final ProjectModel project;
  const _OverviewTab({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Client',
            value: project.clientName,
          ),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: project.location,
          ),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Start',
            value:
                '${project.startDate.day}/${project.startDate.month}/${project.startDate.year}',
          ),
          _InfoRow(
            icon: Icons.event_outlined,
            label: 'End',
            value:
                '${project.endDate.day}/${project.endDate.month}/${project.endDate.year}',
          ),
          _InfoRow(
            icon: Icons.flag_outlined,
            label: 'Status',
            value: project.statusLabel,
          ),
          const SizedBox(height: 20),
          Text(
            'Disciplines',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: project.disciplines
                .map(
                  (d) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      d,
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          if (project.notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Notes',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(project.notes),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tasks Tab ─────────────────────────────────────────────────────────────────

class _TasksTab extends ConsumerWidget {
  final ProjectModel project;
  final bool canAddTask;
  final bool isReviewer;
  final dynamic currentUser;

  const _TasksTab({
    required this.project,
    required this.canAddTask,
    required this.isReviewer,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tasksAsync = ref.watch(projectTasksProvider(project.id));
    final stats = ref.watch(projectTaskStatsProvider(project.id));

    return Scaffold(
      backgroundColor: cs.surface,
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tasks) {
          if (tasks.isEmpty) {
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
                    'No tasks yet',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                  ),
                  if (canAddTask) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _showAddTaskSheet(context, ref),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Task'),
                    ),
                  ],
                ],
              ),
            );
          }

          final Map<String, List<TaskModel>> grouped = {};
          for (final task in tasks) {
            grouped.putIfAbsent(task.discipline, () => []).add(task);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              if (stats.isNotEmpty) _StatsRow(stats: stats),
              const SizedBox(height: 16),
              ...grouped.entries.map(
                (entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${entry.value.length})',
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...entry.value.map(
                      (task) => _TaskCard(
                        task: task,
                        canAddTask: canAddTask,
                        isReviewer: isReviewer,
                        currentUser: currentUser,
                        project: project,
                        ref: ref,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: canAddTask
          ? FloatingActionButton(
              onPressed: () => _showAddTaskSheet(context, ref),
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  void _showAddTaskSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddEditTaskSheet(project: project),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
          label: 'Total',
          value: stats['total'] ?? 0,
          color: Colors.grey,
        ),
        const SizedBox(width: 8),
        _StatChip(
          label: 'In Progress',
          value: stats['in_progress'] ?? 0,
          color: Colors.blue,
        ),
        const SizedBox(width: 8),
        _StatChip(
          label: 'Review',
          value: stats['under_review'] ?? 0,
          color: Colors.orange,
        ),
        const SizedBox(width: 8),
        _StatChip(
          label: 'Done',
          value: stats['completed'] ?? 0,
          color: Colors.green,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Task Card ─────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final bool canAddTask;
  final bool isReviewer;
  final dynamic currentUser;
  final ProjectModel project;
  final WidgetRef ref;

  const _TaskCard({
    required this.task,
    required this.canAddTask,
    required this.isReviewer,
    required this.currentUser,
    required this.project,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                      fontSize: 14,
                    ),
                  ),
                ),
                _StatusChip(status: task.status),
                if (canAddTask) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _showEditSheet(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 13,
                  color: cs.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  task.category,
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.engineering_outlined,
                  size: 13,
                  color: cs.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  task.discipline,
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (task.assignedToName.isNotEmpty)
              Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 13,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    task.assignedToName,
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: cs.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '${task.actualHours.toStringAsFixed(1)}h / ${task.plannedHours.toStringAsFixed(1)}h',
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '${task.endDate.day}/${task.endDate.month}/${task.endDate.year}',
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            if (task.approvalStatus != 'pending') ...[
              const SizedBox(height: 8),
              _ApprovalChip(status: task.approvalStatus),
            ],
            // ── Client Comments ───────────────────────────────────────
            if (task.clientComments.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              _ClientCommentsSection(comments: task.clientComments),
            ],
            if (_showActions()) ...[
              const Divider(height: 16),
              _buildActions(context),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddEditTaskSheet(project: project, task: task),
    );
  }

  bool _showActions() {
    if (canAddTask && task.status == 'in_progress') return true;
    if (isReviewer && task.status == 'under_review') return true;
    return false;
  }

  Widget _buildActions(BuildContext context) {
    if (isReviewer && task.status == 'under_review') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showReviewDialog(context, 'rejected'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Reject'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () =>
                  _showReviewDialog(context, 'approved_with_comments'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
              icon: const Icon(Icons.comment_outlined, size: 16),
              label: const Text('Comments'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _showReviewDialog(context, 'approved'),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Approve'),
            ),
          ),
        ],
      );
    }
    if (canAddTask && task.status == 'in_progress') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _submitForReview(context),
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Submit for Review'),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _submitForReview(BuildContext context) async {
    await ref.read(taskRepositoryProvider).submitForReview(task.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task submitted for review')),
      );
    }
  }

  void _showReviewDialog(BuildContext context, String approvalStatus) {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_reviewTitle(approvalStatus)),
        content: TextField(
          controller: notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: approvalStatus == 'approved'
                ? 'Optional notes...'
                : 'Enter your notes...',
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
                    reviewerId: currentUser?.uid ?? '',
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Task ${_reviewTitle(approvalStatus)}'),
                  ),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  String _reviewTitle(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'approved_with_comments':
        return 'Approved with Comments';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }
}

// ── Add / Edit Task Sheet ─────────────────────────────────────────────────────

class _AddEditTaskSheet extends ConsumerStatefulWidget {
  final ProjectModel project;
  final TaskModel? task;

  const _AddEditTaskSheet({required this.project, this.task});

  @override
  ConsumerState<_AddEditTaskSheet> createState() => _AddEditTaskSheetState();
}

class _AddEditTaskSheetState extends ConsumerState<_AddEditTaskSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _notesController;
  late final TextEditingController _hoursController;

  String? _selectedCategory;
  String? _selectedDiscipline;
  String? _selectedEngineer;
  String? _selectedEngineerName;
  String? _selectedReviewer;
  String? _selectedReviewerName;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _saving = false;
  String? _errorMessage;

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController = TextEditingController(text: t?.title ?? '');
    _descController = TextEditingController(text: t?.description ?? '');
    _notesController = TextEditingController(text: t?.notes ?? '');
    _hoursController = TextEditingController(
      text: t != null ? t.plannedHours.toStringAsFixed(0) : '',
    );
    _selectedCategory = t?.category;
    _selectedDiscipline = t?.discipline;
    _selectedEngineer = t?.assignedTo.isEmpty == true ? null : t?.assignedTo;
    _selectedEngineerName = t?.assignedToName;
    _selectedReviewer = t?.reviewerId.isEmpty == true ? null : t?.reviewerId;
    _selectedReviewerName = t?.reviewerName;
    _startDate = t?.startDate ?? DateTime.now();
    _endDate = t?.endDate ?? DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _notesController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final categories = ref.watch(taskCategoriesProvider);
    final disciplines = ref.watch(disciplinesProvider);
    final user = ref.watch(currentUserProvider).value;
    final employeesAsync = ref.watch(employeesProvider);

    final engineers =
        employeesAsync.value
            ?.where((e) => e.role == 'engineer' || e.role == 'team_leader')
            .toList() ??
        [];
    final reviewers =
        employeesAsync.value?.where((e) => e.role == 'reviewer').toList() ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  _isEdit ? 'Edit Task' : 'Add Task',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isEdit)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    onPressed: () => _confirmDelete(context),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _Field(
                  controller: _titleController,
                  label: 'Task Title *',
                  hint: 'e.g. Lighting Panel Design',
                  onChanged: (_) => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _descController,
                  label: 'Description',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DropdownField(
                        label: 'Category *',
                        value: _selectedCategory,
                        items: categories,
                        onChanged: (v) => setState(() {
                          _selectedCategory = v;
                          _errorMessage = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DropdownField(
                        label: 'Discipline *',
                        value: _selectedDiscipline,
                        items: disciplines,
                        onChanged: (v) => setState(() {
                          _selectedDiscipline = v;
                          _errorMessage = null;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedEngineer,
                  decoration: _inputDecoration('Assign Engineer *', cs),
                  items: engineers
                      .map(
                        (e) =>
                            DropdownMenuItem(value: e.uid, child: Text(e.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    final eng = engineers.firstWhere((e) => e.uid == v);
                    setState(() {
                      _selectedEngineer = v;
                      _selectedEngineerName = eng.name;
                      _errorMessage = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedReviewer,
                  decoration: _inputDecoration('Assign Reviewer', cs),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No Reviewer'),
                    ),
                    ...reviewers.map(
                      (e) =>
                          DropdownMenuItem(value: e.uid, child: Text(e.name)),
                    ),
                  ],
                  onChanged: (v) {
                    final rev = v != null
                        ? reviewers.firstWhere((e) => e.uid == v)
                        : null;
                    setState(() {
                      _selectedReviewer = v;
                      _selectedReviewerName = rev?.name ?? '';
                    });
                  },
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _hoursController,
                  label: 'Planned Hours *',
                  hint: 'e.g. 8',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DatePicker(
                        label: 'Start Date',
                        date: _startDate,
                        onTap: () => _pickDate(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DatePicker(
                        label: 'End Date',
                        date: _endDate,
                        onTap: () => _pickDate(isStart: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _notesController,
                  label: 'Notes',
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: Theme.of(context).colorScheme.error,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _save(user),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _isEdit ? Icons.save_rounded : Icons.add_rounded,
                          ),
                    label: Text(
                      _saving
                          ? 'Saving...'
                          : _isEdit
                          ? 'Save Changes'
                          : 'Add Task',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          _startDate = picked;
        else
          _endDate = picked;
      });
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text(
          'Are you sure you want to delete "${widget.task!.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context);
              await ref
                  .read(taskRepositoryProvider)
                  .deleteTask(widget.task!.id);
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Task deleted')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(user) async {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Task title is required');
      return;
    }
    if (_selectedCategory == null) {
      setState(() => _errorMessage = 'Please select a category');
      return;
    }
    if (_selectedDiscipline == null) {
      setState(() => _errorMessage = 'Please select a discipline');
      return;
    }
    if (_selectedEngineer == null) {
      setState(() => _errorMessage = 'Please assign an engineer');
      return;
    }
    if (_hoursController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Planned hours is required');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      if (_isEdit) {
        final updated = TaskModel(
          id: widget.task!.id,
          officeId: widget.task!.officeId,
          projectId: widget.task!.projectId,
          projectName: widget.task!.projectName,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          category: _selectedCategory!,
          discipline: _selectedDiscipline!,
          assignedTo: _selectedEngineer!,
          assignedToName: _selectedEngineerName ?? '',
          teamLeaderId: widget.task!.teamLeaderId,
          teamLeaderName: widget.task!.teamLeaderName,
          reviewerId: _selectedReviewer ?? '',
          reviewerName: _selectedReviewerName ?? '',
          startDate: _startDate,
          endDate: _endDate,
          plannedHours: double.tryParse(_hoursController.text) ?? 0,
          actualHours: widget.task!.actualHours,
          status: widget.task!.status,
          approvalStatus: widget.task!.approvalStatus,
          approvalNotes: widget.task!.approvalNotes,
          approvedAt: widget.task!.approvedAt,
          createdBy: widget.task!.createdBy,
          createdAt: widget.task!.createdAt,
          notes: _notesController.text.trim(),
        );
        await ref.read(taskRepositoryProvider).updateTask(updated);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Task updated ✓')));
        }
      } else {
        final task = TaskModel(
          id: '',
          officeId: user?.officeId ?? '',
          projectId: widget.project.id,
          projectName: widget.project.name,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          category: _selectedCategory!,
          discipline: _selectedDiscipline!,
          assignedTo: _selectedEngineer!,
          assignedToName: _selectedEngineerName ?? '',
          teamLeaderId: user?.uid ?? '',
          teamLeaderName: user?.name ?? '',
          reviewerId: _selectedReviewer ?? '',
          reviewerName: _selectedReviewerName ?? '',
          startDate: _startDate,
          endDate: _endDate,
          plannedHours: double.tryParse(_hoursController.text) ?? 0,
          actualHours: 0,
          status: 'not_started',
          approvalStatus: 'pending',
          approvalNotes: '',
          approvedAt: null,
          createdBy: user?.uid ?? '',
          createdAt: DateTime.now(),
          notes: _notesController.text.trim(),
        );
        await ref.read(taskRepositoryProvider).createTask(task);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task added successfully ✓')),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _inputDecoration(String label, ColorScheme cs) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DatePicker({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhiteChip extends StatelessWidget {
  final String label;
  const _WhiteChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ApprovalChip extends StatelessWidget {
  final String status;
  const _ApprovalChip({required this.status});

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              color: cs.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
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
    final cs    = Theme.of(context).colorScheme;
    final count  = widget.comments.length;
    final unread = widget.comments.where((c) => c['isRead'] == false).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                Icon(Icons.comment_outlined, size: 13,
                    color: unread > 0 ? Colors.orange : Colors.blue),
                const SizedBox(width: 5),
                Text(
                  unread > 0 ? 'Client Notes ($unread new)' : 'Client Notes ($count)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: unread > 0 ? Colors.orange : Colors.blue,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: unread > 0 ? Colors.orange : Colors.blue,
                ),
              ]),
            ),
          ]),
        ),
        if (_expanded) ...[
          const SizedBox(height: 10),
          ...widget.comments.map((c) {
            final text   = c['text'] as String? ?? '';
            final isRead = c['isRead'] as bool? ?? true;
            final dateStr = _fmtTs(c['createdAt']);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isRead
                    ? cs.surfaceContainerHighest.withOpacity(0.5)
                    : Colors.orange.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isRead ? Colors.transparent : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.person_outline, size: 14, color: Colors.blue),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('Client',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (!isRead)
                      Container(width: 7, height: 7,
                          decoration: const BoxDecoration(
                              color: Colors.orange, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(dateStr,
                        style: TextStyle(
                            fontSize: 10, color: cs.onSurface.withOpacity(0.4))),
                  ]),
                  const SizedBox(height: 4),
                  Text(text, style: const TextStyle(fontSize: 12)),
                ])),
              ]),
            );
          }),
        ],
      ],
    );
  }

  String _fmtTs(dynamic v) {
    if (v == null) return '';
    try {
      final d = (v as Timestamp).toDate();
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')} '
          '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
  }
}
