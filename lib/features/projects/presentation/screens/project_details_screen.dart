import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;

import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../controllers/project_providers.dart';
import '../controllers/task_providers.dart';
import '../../../home/presentation/controllers/home_providers.dart';
import '../../../employees/data/models/employee_model.dart';
import '../../../employees/presentation/controllers/employee_providers.dart';
import 'add_edit_project_screen.dart';
import '../../../office/presentation/controllers/office_settings_providers.dart';
import 'client_review_screen.dart';
import 'project_report_screen.dart';
import '../../../reports/presentation/screens/report_export_stub.dart'
    if (dart.library.html) '../../../reports/presentation/screens/report_export_web.dart'
    if (dart.library.io) '../../../reports/presentation/screens/report_export_mobile.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../notifications/presentation/controllers/notification_providers.dart';
import '../../../../core/widgets/employee_picker_dropdown.dart';

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
    _tabController = TabController(length: 4, vsync: this);
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
    final isTeamLeader = user?.isTeamLeader == true; // FIX: canManageTasks includes Admin — use isTeamLeader
    final canAddTask = isAdmin || isTeamLeader;

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
                        const NotificationBellIcon(),
                        IconButton(
                          icon: const Icon(
                            Icons.bar_chart_rounded,
                            color: Colors.white,
                          ),
                          tooltip: 'Project Report',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProjectReportScreen(project: project),
                            ),
                          ),
                        ),
                        if (isAdmin) ...[
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.mark_email_read_outlined,
                                  color: Colors.white,
                                ),
                                tooltip: 'Client Review',
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ClientReviewScreen(
                                      projectId: project.id,
                                      projectName: project.name,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Consumer(
                                  builder: (_, ref, _) {
                                    final count = ref.watch(
                                      pendingClientReviewCountProvider(
                                        project.id,
                                      ),
                                    );
                                    if (count == 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '$count',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
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
                      Tab(
                        icon: Icon(Icons.comment_outlined, size: 16),
                        text: 'My Notes',
                      ),
                      Tab(
                        icon: Icon(Icons.bar_chart_rounded, size: 16),
                        text: 'Report',
                      ),
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
                  currentUser: user,
                ),
                _NotesTab(projectId: project.id),
                _ReportTab(projectId: project.id, projectName: project.name),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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

class _TasksTab extends ConsumerWidget {
  final ProjectModel project;
  final bool canAddTask;
  final dynamic currentUser;

  const _TasksTab({
    required this.project,
    required this.canAddTask,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tasksAsync = ref.watch(projectTasksProvider(project.id));
    final statsAsync = ref.watch(projectTaskStatsProvider(project.id));

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
                      onPressed: () => _showAddTaskSheet(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Task'),
                    ),
                  ],
                ],
              ),
            );
          }

          // Serial numbers: sort all tasks by createdAt → assign global 1-based numbers
          final sortedForNumbering = [...tasks]
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          final taskNumbers = <String, int>{
            for (var i = 0; i < sortedForNumbering.length; i++)
              sortedForNumbering[i].id: i + 1,
          };

          final Map<String, List<TaskModel>> grouped = {};
          for (final task in tasks) {
            grouped.putIfAbsent(task.discipline, () => []).add(task);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              statsAsync.when(
                data: (stats) => stats.isNotEmpty
                    ? _StatsRow(stats: stats)
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
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
                        currentUser: currentUser,
                        project: project,
                        ref: ref,
                        taskNumber: taskNumbers[task.id] ?? 0,
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
              onPressed: () => _showAddTaskSheet(context),
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  void _showAddTaskSheet(BuildContext context) {
    final container = ProviderScope.containerOf(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => UncontrolledProviderScope(
        container: container,
        child: _AddEditTaskSheet(project: project),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatChip(
          label: 'Total',
          value: stats['total'] ?? 0,
          color: Colors.grey,
        ),
        _StatChip(
          label: 'Not Started',
          value: stats['not_started'] ?? 0,
          color: Colors.grey,
        ),
        _StatChip(
          label: 'In Prog',
          value: stats['in_progress'] ?? 0,
          color: Colors.blue,
        ),
        _StatChip(
          label: 'TL Review',
          value: stats['team_leader_review'] ?? 0,
          color: Colors.teal,
        ),
        _StatChip(
          label: 'QC',
          value: stats['qc_review'] ?? 0,
          color: Colors.orange,
        ),
        _StatChip(
          label: 'Client',
          value: stats['client_review'] ?? 0,
          color: Colors.purple,
        ),
        _StatChip(
          label: 'Done',
          value: stats['completed'] ?? 0,
          color: Colors.green,
        ),
        if ((stats['overdue'] ?? 0) > 0)
          _StatChip(
            label: 'Overdue',
            value: stats['overdue'] ?? 0,
            color: Colors.red,
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
    return Container(
      width: 78,
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
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final bool canAddTask;
  final dynamic currentUser;
  final ProjectModel project;
  final WidgetRef ref;

  final int taskNumber;

  const _TaskCard({
    required this.task,
    required this.canAddTask,
    required this.currentUser,
    required this.project,
    required this.ref,
    this.taskNumber = 0,
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
                if (taskNumber > 0) ...[
                  Container(
                    width: taskNumber > 9 ? 34 : 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '$taskNumber',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
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
            if (task.assignedEngineerNames.join(', ').isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 13,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      task.assignedEngineerNames.join(', '),
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            if (task.reviewerName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 13,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Reviewer: ${task.reviewerName}',
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
                    color: task.isOverdue
                        ? Colors.red
                        : cs.onSurface.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            if (task.teamLeaderReviewNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ReviewNoteChip(
                label: 'TL Note: ${task.teamLeaderReviewNotes}',
                color: Colors.teal,
              ),
            ],
            if (task.qcReviewNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ReviewNoteChip(
                label: 'Reviewer Note: ${task.qcReviewNotes}',
                color: Colors.orange,
              ),
            ],
            if (task.clientReviewNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ReviewNoteChip(
                label: 'Client Note: ${task.clientReviewNotes}',
                color: Colors.purple,
              ),
            ],
            if (task.taskLink.isNotEmpty) ...[
              const SizedBox(height: 8),
              _TaskLinkWidget(link: task.taskLink),
            ],
            if (task.clientComments.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              _ClientCommentsSection(comments: task.clientComments),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    final container = ProviderScope.containerOf(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => UncontrolledProviderScope(
        container: container,
        child: _AddEditTaskSheet(project: project, task: task),
      ),
    );
  }
}

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
  late final TextEditingController _linkController;
  late final TextEditingController _hoursController;

  String? _selectedCategory;
  String? _selectedDiscipline;
  String? _selectedReviewer;
  String? _selectedReviewerName;
  final Set<String> _selectedEngineerIds = {};
  final List<String> _selectedEngineerNames = [];
  late DateTime _startDate;
  late DateTime _endDate;
  bool _saving = false;
  // منع تعبئة الـ discipline أكثر من مرة
  bool _disciplineInitialized = false;
  String? _errorMessage;

  String _priority = 'normal';

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;

    _titleController = TextEditingController(text: t?.title ?? '');
    _descController = TextEditingController(text: t?.description ?? '');
    _notesController = TextEditingController(text: t?.notes ?? '');
    _linkController = TextEditingController(text: t?.taskLink ?? '');
    _hoursController = TextEditingController(
      text: t != null ? t.plannedHours.toStringAsFixed(0) : '',
    );

    _priority = t?.priority ?? 'normal';
    _selectedCategory = t?.category;
    _selectedDiscipline = t?.discipline;
    _selectedReviewer = (t?.reviewerId.isNotEmpty ?? false)
        ? t!.reviewerId
        : null;
    _selectedReviewerName = t?.reviewerName ?? '';

    // ── Auto-fill defaults when creating a new task ───────────────────────
    if (t == null) {
      final project = widget.project;

      // Auto-fill QC Reviewer from project settings
      if (project.qcId != null && project.qcId!.isNotEmpty) {
        _selectedReviewer = project.qcId;
        _selectedReviewerName = project.qcName ?? '';
      }

      // Auto-fill Discipline from current user's department
      // Will be refined in didChangeDependencies once providers are ready
    }

    if (t != null) {
      _selectedEngineerIds.addAll(t.assignedEngineerIds);
      _selectedEngineerNames.addAll(t.assignedEngineerNames);
    }
    _startDate = t?.startDate ?? DateTime.now();
    _endDate = t?.endDate ?? DateTime.now().add(const Duration(days: 5));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _notesController.dispose();
    _linkController.dispose();
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

    final employees = employeesAsync.value ?? [];

    final engineers = employees
        .where(
          (e) =>
              e.role.toLowerCase() == 'engineer' ||
              e.role.toLowerCase() == 'team_leader',
        )
        .toList();

    final reviewers = employees
        .where((e) => e.role.toLowerCase() == 'reviewer')
        .toList();

    // ── Discipline-based filtering ─────────────────────────────────────────────
    final isDisciplineSelected =
        _selectedDiscipline != null && _selectedDiscipline!.isNotEmpty;

    List<EmployeeModel> filteredEngineers;
    bool engineerFallback = false;
    if (isDisciplineSelected) {
      final disc = _selectedDiscipline!.toLowerCase();
      final fl = engineers.where((e) {
        final isLeaderOrReviewer =
            e.role == 'team_leader' || e.role == 'reviewer';
        if (isLeaderOrReviewer) return true;
        final dept = e.department.toLowerCase();
        final spec = e.specialization.toLowerCase();
        return dept == disc ||
            spec.contains(disc) ||
            (disc.contains(spec) && spec.isNotEmpty);
      }).toList();
      if (fl.isEmpty) {
        filteredEngineers = engineers;
        engineerFallback = true;
      } else {
        filteredEngineers = fl;
      }
    } else {
      filteredEngineers = engineers;
    }

    final List<EmployeeModel> filteredReviewers;
    if (isDisciplineSelected) {
      final disc = _selectedDiscipline!.toLowerCase();
      final fl = reviewers.where((e) {
        if (e.uid == _selectedReviewer) return true; // keep current
        final dept = e.department.toLowerCase();
        final spec = e.specialization.toLowerCase();
        return dept == disc ||
            spec.contains(disc) ||
            (disc.contains(spec) && spec.isNotEmpty);
      }).toList();
      filteredReviewers = fl.isEmpty ? reviewers : fl;
    } else {
      filteredReviewers = reviewers;
    }

    // ── Auto-fill Discipline من department المستخدم (مرة واحدة فقط) ──────────
    if (!_isEdit &&
        !_disciplineInitialized &&
        user != null &&
        disciplines.isNotEmpty) {
      final userDept = user.department.toLowerCase().trim();
      // نبحث عن discipline مطابق لـ department المستخدم (case-insensitive)
      final match = disciplines.firstWhere(
        (d) => d.toLowerCase().trim() == userDept,
        orElse: () => '',
      );
      if (match.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedDiscipline = match;
              _disciplineInitialized = true;
            });
          }
        });
      } else {
        // حتى لو ما لقينا match، نمنع إعادة المحاولة
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _disciplineInitialized = true);
        });
      }
    }

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
                        onChanged: (v) {
                          final prev = _selectedDiscipline;
                          if (v != null && v.isNotEmpty && v != prev) {
                            _clearEngineersNotMatchingDiscipline(
                                v, employees);
                          }
                          setState(() {
                            _selectedDiscipline = v;
                            _errorMessage = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── Engineers (multi-select) ─────────────────────────────
                if (isDisciplineSelected && engineerFallback)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'No engineers in ${_selectedDiscipline!} — showing all',
                      style: const TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                EmployeePickerDropdown(
                  label: 'Assign Engineers *',
                  prefixIcon: Icons.engineering_outlined,
                  employees: filteredEngineers,
                  selectedIds: _selectedEngineerIds.toList(),
                  multiSelect: true,
                  onChanged: (ids, names) {
                    setState(() {
                      _selectedEngineerIds
                        ..clear()
                        ..addAll(ids);
                      _selectedEngineerNames
                        ..clear()
                        ..addAll(names);
                      _errorMessage = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // ── Reviewer (single-select) ──────────────────────────────
                EmployeePickerDropdown(
                  label: 'Assign Reviewer',
                  prefixIcon: Icons.verified_outlined,
                  employees: filteredReviewers,
                  selectedIds: _selectedReviewer != null &&
                          filteredReviewers.any((e) => e.uid == _selectedReviewer)
                      ? [_selectedReviewer!]
                      : [],
                  multiSelect: false,
                  hint: 'No Reviewer',
                  onChanged: (ids, names) {
                    setState(() {
                      if (ids.isEmpty) {
                        _selectedReviewer = null;
                        _selectedReviewerName = '';
                      } else {
                        _selectedReviewer = ids.first;
                        _selectedReviewerName = names.first;
                      }
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
                // ── Priority selector ────────────────────────────────────
                _PrioritySelector(
                  value: _priority,
                  onChanged: (v) => setState(() => _priority = v),
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
                const SizedBox(height: 12),
                _Field(
                  controller: _linkController,
                  label: 'Task Link (URL)',
                  hint: 'https://... or \\serverpath',
                  prefixIcon: Icons.link_rounded,
                  keyboardType: TextInputType.url,
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
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
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
    if (_selectedEngineerIds.isEmpty) {
      setState(() => _errorMessage = 'Please assign at least one engineer');
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
        final old = widget.task!;
        final updated = old.copyWith(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          category: _selectedCategory!,
          discipline: _selectedDiscipline!,
          assignedEngineerIds: _selectedEngineerIds.toList(),
          assignedEngineerNames: _selectedEngineerNames.toList(),
          reviewerId: _selectedReviewer ?? '',
          reviewerName: _selectedReviewerName ?? '',
          startDate: _startDate,
          endDate: _endDate,
          plannedHours: double.tryParse(_hoursController.text) ?? 0,
          notes: _notesController.text.trim(),
          taskLink: _linkController.text.trim(),
          priority: _priority,
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
          clientId: widget.project.clientId,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          category: _selectedCategory!,
          discipline: _selectedDiscipline!,
          assignedEngineerIds: _selectedEngineerIds.toList(),
          assignedEngineerNames: _selectedEngineerNames.toList(),
          // ── Team Leader: من المشروع لو موجود، وإلا من الـ current user ──
          teamLeaderId: widget.project.teamLeaderId?.isNotEmpty == true
              ? widget.project.teamLeaderId!
              : user?.uid ?? '',
          teamLeaderName: widget.project.teamLeaderName?.isNotEmpty == true
              ? widget.project.teamLeaderName!
              : user?.name ?? '',
          // ── Reviewer (QC): auto-filled من project.qcId في initState ──
          reviewerId: _selectedReviewer ?? '',
          reviewerName: _selectedReviewerName ?? '',
          startDate: _startDate,
          endDate: _endDate,
          plannedHours: double.tryParse(_hoursController.text) ?? 0,
          actualHours: 0,
          progress: 0,
          status: 'not_started',
          clientReviewNotes: '',
          clientReviewRound: 0,
          submittedToClientAt: null,
          clientComments: const [],
          createdBy: user?.uid ?? '',
          createdByName: user?.name ?? '',
          createdAt: DateTime.now(),
          notes: _notesController.text.trim(),
          taskLink: _linkController.text.trim(),
          teamLeaderReviewNotes: '',
          qcReviewNotes: '',
          teamLeaderReviewedAt: null,
          qcReviewedAt: null,
          clientReviewedAt: null,
          attachments: const [],
          activityLog: const [],
          priority: _priority,
        );

        await ref
            .read(taskRepositoryProvider)
            .createTask(task, createdByName: user?.name ?? '');

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task added successfully ✓')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// Removes previously selected engineers that don't match the new discipline.
  /// Team leaders and reviewers are always kept.
  void _clearEngineersNotMatchingDiscipline(
      String discipline, List<EmployeeModel> allEmployees) {
    final disc = discipline.toLowerCase();
    final toRemoveIds = <String>[];
    for (final id in List<String>.from(_selectedEngineerIds)) {
      final matches = allEmployees.where((e) => e.uid == id);
      if (matches.isEmpty) continue;
      final emp = matches.first;
      final isLeaderOrReviewer =
          emp.role == 'team_leader' || emp.role == 'reviewer';
      if (isLeaderOrReviewer) continue;
      final dept = emp.department.toLowerCase();
      final spec = emp.specialization.toLowerCase();
      final matches_ = dept == disc ||
          spec.contains(disc) ||
          (disc.contains(spec) && spec.isNotEmpty);
      if (!matches_) toRemoveIds.add(id);
    }
    for (final id in toRemoveIds) {
      final empList = allEmployees.where((e) => e.uid == id);
      if (empList.isNotEmpty) _selectedEngineerNames.remove(empList.first.name);
      _selectedEngineerIds.remove(id);
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

// ── Priority Selector ──────────────────────────────────────────────────────────
class _PrioritySelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _PrioritySelector({required this.value, required this.onChanged});

  static const _priorities = [
    ('urgent', 'Urgent',  Color(0xFFE53935)),
    ('high',   'High',    Color(0xFFFF7043)),
    ('normal', 'Normal',  Color(0xFF1E88E5)),
    ('low',    'Low',     Color(0xFF90A4AE)),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _priorities.map(((String key, String label, Color color) p) {
            final selected = value == p.$1;
            return InkWell(
              onTap: () => onChanged(p.$1),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? p.$3.withValues(alpha: 0.15) : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? p.$3 : cs.outlineVariant,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: p.$3,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      p.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        color: selected ? p.$3 : cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;

  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.prefixIcon,
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
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: cs.primary, size: 20)
            : null,
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
      initialValue: value,
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
      case 'team_review':
        color = Colors.teal;
        label = 'TL Review';
        break;
      case 'under_review':
        color = Colors.orange;
        label = 'QC Review';
        break;
      case 'client_review':
        color = Colors.purple;
        label = 'Client Review';
        break;
      case 'client_approved':
        color = Colors.green;
        label = 'Client Approved';
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

class _ReviewNoteChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ReviewNoteChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
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
// TASK LINK WIDGET — فتح ونسخ الـ links (web + local server paths)
// ══════════════════════════════════════════════════════════════════════════════

class _TaskLinkWidget extends StatelessWidget {
  final String link;
  const _TaskLinkWidget({required this.link});

  // هل الـ link مسار محلي (UNC أو drive letter)؟
  bool get _isLocalPath =>
      link.startsWith('\\\\') ||
      link.startsWith('//') ||
      RegExp(r'^[A-Za-z]:\\').hasMatch(link) ||
      RegExp(r'^[A-Za-z]:/').hasMatch(link);

  bool get _isWebUrl =>
      link.startsWith('http://') || link.startsWith('https://');

  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard ✓'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openWebUrl(BuildContext context) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // أيقونة ولون بحسب نوع الـ link
    final icon = _isLocalPath
        ? Icons.storage_rounded
        : _isWebUrl
        ? Icons.open_in_new_rounded
        : Icons.link_rounded;

    final color = _isLocalPath ? Colors.orange.shade700 : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),

          // نص الـ link
          Expanded(
            child: Text(
              link,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                decoration: _isWebUrl ? TextDecoration.underline : null,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),

          const SizedBox(width: 4),

          // ── أزرار الـ action ──────────────────────────────────────
          // نسخ — متاح دايماً
          InkWell(
            onTap: () => _copyToClipboard(context),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Tooltip(
                message: 'Copy path',
                child: Icon(Icons.copy_rounded, size: 14, color: color),
              ),
            ),
          ),

          // فتح — فقط للـ web URLs
          if (_isWebUrl) ...[
            const SizedBox(width: 2),
            InkWell(
              onTap: () => _openWebUrl(context),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Tooltip(
                  message: 'Open in browser',
                  child: Icon(Icons.launch_rounded, size: 14, color: color),
                ),
              ),
            ),
          ],

          // للـ local paths — زرار نسخ مع hint
          if (_isLocalPath) ...[
            const SizedBox(width: 2),
            Tooltip(
              message: 'Copy path, then paste in File Explorer',
              child: Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: color.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.comment_outlined,
                      size: 13,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Client Notes ($count)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 10),
          ...widget.comments.map((c) {
            final text = c['text'] as String? ?? '';
            final author = c['authorName'] as String? ?? 'Client';
            final dateStr = _fmtTs(c['createdAt']);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              author,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurface.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(text, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  String _fmtTs(dynamic v) {
    if (v == null) return '';
    try {
      if (v is Timestamp) {
        final d = v.toDate();
        return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
            '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      }
      return '';
    } catch (_) {
      return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MY NOTES TAB
// ─────────────────────────────────────────────────────────────────────────────

// projectTasksProvider replaced by projectTasksProvider from task_providers.dart

class _NotesTab extends ConsumerWidget {
  final String projectId;
  const _NotesTab({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tasksAsync = ref.watch(projectTasksProvider(projectId));
    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (tasks) {
        final tasksWithNotes = tasks
            .where((t) => t.clientComments.isNotEmpty)
            .toList();
        if (tasksWithNotes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.comment_outlined,
                  size: 48,
                  color: cs.onSurface.withOpacity(0.25),
                ),
                const SizedBox(height: 12),
                Text(
                  'No notes yet',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.4)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Go to Tasks tab to add notes',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          );
        }
        final allComments = tasksWithNotes
            .expand((t) => t.clientComments)
            .toList();
        final resolvedCount = allComments
            .where((c) => c['isResolved'] == true)
            .length;
        final openCount = allComments.length - resolvedCount;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _NoteStatChip(
                  label: 'Open',
                  count: openCount,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                _NoteStatChip(
                  label: 'Resolved',
                  count: resolvedCount,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...tasksWithNotes.map(
              (task) => _NoteGroup(
                taskTitle: task.title,
                taskId: task.id,
                comments: task.clientComments,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NoteStatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _NoteStatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteGroup extends StatelessWidget {
  final String taskTitle, taskId;
  final List<Map<String, dynamic>> comments;
  const _NoteGroup({
    required this.taskTitle,
    required this.taskId,
    required this.comments,
  });

  Future<void> _toggleResolved(int index) async {
    final updated = comments.map((c) => Map<String, dynamic>.from(c)).toList();
    updated[index]['isResolved'] = !(updated[index]['isResolved'] == true);
    await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({
      'clientComments': updated,
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolvedCount = comments.where((c) => c['isResolved'] == true).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.task_alt_outlined, size: 14, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    taskTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
                if (resolvedCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$resolvedCount resolved',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  '${comments.length} note${comments.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.primary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          ...comments.asMap().entries.map((entry) {
            final i = entry.key;
            final c = entry.value;
            final isResolved = c['isResolved'] == true;
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _toggleResolved(i),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isResolved
                            ? Colors.green.withOpacity(0.15)
                            : cs.surfaceContainerHighest,
                        border: Border.all(
                          color: isResolved ? Colors.green : cs.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                      child: isResolved
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.green,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isResolved
                                ? Colors.green.withOpacity(0.06)
                                : cs.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isResolved
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            c['text'] as String? ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: isResolved
                                  ? cs.onSurface.withOpacity(0.45)
                                  : cs.onSurface,
                              decoration: isResolved
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _noteFmtDate(c['createdAt']),
                              style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurface.withOpacity(0.4),
                              ),
                            ),
                            if (isResolved) ...[
                              const SizedBox(width: 6),
                              const Text(
                                '✓ Resolved',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

String _noteFmtDate(dynamic v) {
  if (v == null) return '—';
  try {
    if (v is Timestamp) {
      final d = v.toDate();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    if (v is String && v.isNotEmpty) return v;
  } catch (_) {}
  return '—';
}

// ─────────────────────────────────────────────────────────────────────────────
// REPORT TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ReportTab extends StatefulWidget {
  final String projectId, projectName;
  const _ReportTab({required this.projectId, required this.projectName});

  @override
  State<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<_ReportTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _exporting = false;

  Future<void> _exportPdf(
    List<TaskModel> tasks,
    Map<String, dynamic>? projectData,
  ) async {
    setState(() => _exporting = true);
    try {
      final progress =
          (projectData?['completionPercentage'] as num?)?.toDouble() ?? 0.0;
      final status = projectData?['status'] as String? ?? '—';
      final endDate = _rptFmtDate(projectData?['endDate']);
      final allComments = tasks.expand((t) => t.clientComments).toList();
      final totalNotes = allComments.length;
      final resolvedNotes = allComments
          .where((c) => c['isResolved'] == true)
          .length;
      final openNotes = totalNotes - resolvedNotes;
      final total = tasks.length;
      final completed = tasks.where((t) => t.status == 'completed').length;
      final inProg = tasks.where((t) => t.status == 'in_progress').length;
      final teamLeadReview = tasks
          .where((t) => t.status == 'team_leader_review')
          .length;
      final qcReview = tasks.where((t) => t.status == 'qc_review').length;
      final clientReview = tasks
          .where((t) => t.status == 'client_review')
          .length;
      final notStart = tasks.where((t) => t.status == 'not_started').length;

      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final cairoFont = pw.Font.ttf(fontData);
      final baseStyle = pw.TextStyle(font: cairoFont, fontSize: 10);
      final titleStyle = pw.TextStyle(
        font: cairoFont,
        fontSize: 18,
        fontWeight: pw.FontWeight.bold,
        color: const PdfColor.fromInt(0xFF2E7D32),
      );
      final sectionStyle = pw.TextStyle(
        font: cairoFont,
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
      );
      final headerCellStyle = pw.TextStyle(
        font: cairoFont,
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        color: PdfColors.white,
      );
      final cellStyle = pw.TextStyle(font: cairoFont, fontSize: 8);

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          textDirection: pw.TextDirection.rtl,
          build: (ctx) => [
            pw.Text(
              widget.projectName,
              style: titleStyle,
              textDirection: pw.TextDirection.rtl,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Project Report  •  Generated: ${_rptFmtNow()}',
              style: pw.TextStyle(
                font: cairoFont,
                fontSize: 9,
                color: PdfColors.grey600,
              ),
            ),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F8E9),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Status: ${_rptStatusLabel(status)}',
                    style: baseStyle,
                  ),
                  pw.Text('End Date: $endDate', style: baseStyle),
                  pw.Text(
                    'Progress: ${progress.toStringAsFixed(0)}%',
                    style: pw.TextStyle(
                      font: cairoFont,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Tasks Breakdown', style: sectionStyle),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Category', 'Count', '%'],
              data: [
                [
                  'Completed',
                  '$completed',
                  total > 0
                      ? '${(completed / total * 100).toStringAsFixed(0)}%'
                      : '0%',
                ],
                [
                  'In Progress',
                  '$inProg',
                  total > 0
                      ? '${(inProg / total * 100).toStringAsFixed(0)}%'
                      : '0%',
                ],
                [
                  'Team Leader Review',
                  '$teamLeadReview',
                  total > 0
                      ? '${(teamLeadReview / total * 100).toStringAsFixed(0)}%'
                      : '0%',
                ],
                [
                  'QC Review',
                  '$qcReview',
                  total > 0
                      ? '${(qcReview / total * 100).toStringAsFixed(0)}%'
                      : '0%',
                ],
                [
                  'Client Review',
                  '$clientReview',
                  total > 0
                      ? '${(clientReview / total * 100).toStringAsFixed(0)}%'
                      : '0%',
                ],
                [
                  'Not Started',
                  '$notStart',
                  total > 0
                      ? '${(notStart / total * 100).toStringAsFixed(0)}%'
                      : '0%',
                ],
                ['Total', '$total', '100%'],
              ],
              headerStyle: headerCellStyle,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF2E7D32),
              ),
              cellStyle: pw.TextStyle(font: cairoFont, fontSize: 9),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F8E9),
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
              },
            ),
            pw.SizedBox(height: 16),
            pw.Text('My Notes Status', style: sectionStyle),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Category', 'Count'],
              data: [
                ['Total Notes', '$totalNotes'],
                ['Resolved', '$resolvedNotes'],
                ['Open', '$openNotes'],
              ],
              headerStyle: headerCellStyle,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF2E7D32),
              ),
              cellStyle: pw.TextStyle(font: cairoFont, fontSize: 9),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F8E9),
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
            pw.SizedBox(height: 16),
            pw.Text('All Tasks', style: sectionStyle),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: [
                'Task',
                'Assigned To',
                'Status',
                'End Date',
                'Notes',
                'Resolved',
              ],
              data: tasks.map((t) {
                final tNotes = t.clientComments.length;
                final tResolved = t.clientComments
                    .where((c) => c['isResolved'] == true)
                    .length;
                return [
                  t.title,
                  t.assignedEngineerNames.isEmpty
                      ? '—'
                      : t.assignedEngineerNames.join(', '),
                  _rptTaskStatusLabel(t.status),
                  _rptFmtDateTime(t.endDate),
                  '$tNotes',
                  '$tResolved',
                ];
              }).toList(),
              headerStyle: headerCellStyle,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF2E7D32),
              ),
              cellStyle: cellStyle,
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F8E9),
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: '${widget.projectName.replaceAll(' ', '_')}_report.pdf',
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Error: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportExcel(List<TaskModel> tasks) async {
    setState(() => _exporting = true);
    try {
      final allComments = tasks.expand((t) => t.clientComments).toList();
      final resolvedNotes = allComments
          .where((c) => c['isResolved'] == true)
          .length;
      final openNotes = allComments.length - resolvedNotes;

      final excel = Excel.createExcel();
      excel.rename('Sheet1', 'Summary');
      final summary = excel['Summary'];
      _rptExcelHeader(summary, ['Metric', 'Value']);
      final summaryData = [
        ['Project', widget.projectName],
        ['Total Tasks', '${tasks.length}'],
        ['Completed', '${tasks.where((t) => t.status == 'completed').length}'],
        [
          'In Progress',
          '${tasks.where((t) => t.status == 'in_progress').length}',
        ],
        [
          'Team Leader Review',
          '${tasks.where((t) => t.status == 'team_leader_review').length}',
        ],
        ['QC Review', '${tasks.where((t) => t.status == 'qc_review').length}'],
        [
          'Client Review',
          '${tasks.where((t) => t.status == 'client_review').length}',
        ],
        [
          'Not Started',
          '${tasks.where((t) => t.status == 'not_started').length}',
        ],
        ['Total Notes', '${allComments.length}'],
        ['Resolved Notes', '$resolvedNotes'],
        ['Open Notes', '$openNotes'],
      ];
      for (var i = 0; i < summaryData.length; i++) {
        _rptExcelRow(
          summary,
          summaryData[i].map((v) => TextCellValue(v)).toList(),
          i + 1,
        );
      }
      summary.setColumnWidth(0, 22);
      summary.setColumnWidth(1, 28);

      final tasksSheet = excel['Tasks'];
      _rptExcelHeader(tasksSheet, [
        'Task',
        'Assigned To',
        'Status',
        'End Date',
        'Total Notes',
        'Resolved Notes',
      ]);
      for (var i = 0; i < tasks.length; i++) {
        final t = tasks[i];
        final tNotes = t.clientComments.length;
        final tResolved = t.clientComments
            .where((c) => c['isResolved'] == true)
            .length;
        _rptExcelRow(tasksSheet, [
          TextCellValue(t.title),
          TextCellValue(
            t.assignedEngineerNames.isEmpty
                ? '—'
                : t.assignedEngineerNames.join(', '),
          ),
          TextCellValue(_rptTaskStatusLabel(t.status)),
          TextCellValue(_rptFmtDateTime(t.endDate)),
          IntCellValue(tNotes),
          IntCellValue(tResolved),
        ], i + 1);
      }

      final notesSheet = excel['Notes'];
      _rptExcelHeader(notesSheet, ['Task', 'Note Text', 'Date', 'Status']);
      var noteRow = 1;
      for (final t in tasks) {
        for (final c in t.clientComments) {
          final isResolved = c['isResolved'] == true;
          _rptExcelRow(notesSheet, [
            TextCellValue(t.title),
            TextCellValue(c['text'] as String? ?? ''),
            TextCellValue(_noteFmtDate(c['createdAt'])),
            TextCellValue(isResolved ? 'Resolved' : 'Open'),
          ], noteRow);
          noteRow++;
        }
      }

      final bytes = excel.encode();
      if (bytes == null) return;
      await downloadExcel(
        Uint8List.fromList(bytes),
        '${widget.projectName.replaceAll(' ', '_')}_report.xlsx',
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer(
      builder: (context, ref, _) {
        final cs = Theme.of(context).colorScheme;
        final tasksAsync = ref.watch(
          projectTasksProvider(widget.projectId),
        );
        final projectAsync = ref.watch(singleProjectProvider(widget.projectId));
        return tasksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (tasks) {
            final total = tasks.length;
            final completed = tasks
                .where((t) => t.status == 'completed')
                .length;
            final inProg = tasks.where((t) => t.status == 'in_progress').length;
            final teamLeadReview = tasks
                .where((t) => t.status == 'team_leader_review')
                .length;
            final qcReview = tasks.where((t) => t.status == 'qc_review').length;
            final clientReview = tasks
                .where((t) => t.status == 'client_review')
                .length;
            final notStart = tasks
                .where((t) => t.status == 'not_started')
                .length;
            final allComments = tasks.expand((t) => t.clientComments).toList();
            final totalNotes = allComments.length;
            final resolvedNotes = allComments
                .where((c) => c['isResolved'] == true)
                .length;
            final openNotes = totalNotes - resolvedNotes;
            final project = projectAsync.value;
            final progress = project != null
                ? project.completionPercentage
                : 0.0;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: _exporting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.red,
                                ),
                              )
                            : const Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 16,
                                color: Colors.red,
                              ),
                        label: const Text(
                          'Export PDF',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _exporting
                            ? null
                            : () => _exportPdf(tasks, null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: _exporting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.green,
                                ),
                              )
                            : const Icon(
                                Icons.table_chart_outlined,
                                size: 16,
                                color: Colors.green,
                              ),
                        label: const Text(
                          'Export Excel',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.green),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _exporting
                            ? null
                            : () => _exportExcel(tasks),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _RptSection(
                  title: 'Task Progress',
                  icon: Icons.show_chart_rounded,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${progress.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: cs.primary,
                                  ),
                                ),
                                Text(
                                  'Tasks Completion',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _RptCircularProgress(
                            value: progress / 100,
                            color: cs.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          minHeight: 8,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(cs.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _RptSection(
                  title: 'Tasks Breakdown',
                  icon: Icons.task_alt_outlined,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _RptStatCard(
                              label: 'Total',
                              value: '$total',
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _RptStatCard(
                              label: 'Done',
                              value: '$completed',
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _RptStatCard(
                              label: 'In Progress',
                              value: '$inProg',
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _RptStatCard(
                              label: 'TL Review',
                              value: '$teamLeadReview',
                              color: Colors.indigo,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _RptStatCard(
                              label: 'QC Review',
                              value: '$qcReview',
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _RptStatCard(
                              label: 'Client Review',
                              value: '$clientReview',
                              color: Colors.teal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _RptStatCard(
                              label: 'Not Started',
                              value: '$notStart',
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                      if (total > 0) ...[
                        const SizedBox(height: 14),
                        _RptStatusBar(
                          segments: [
                            if (completed > 0)
                              _RptSegment(
                                'Done',
                                completed / total,
                                Colors.green,
                              ),
                            if (inProg > 0)
                              _RptSegment(
                                'In Progress',
                                inProg / total,
                                Colors.orange,
                              ),
                            if (teamLeadReview > 0)
                              _RptSegment(
                                'TL Review',
                                teamLeadReview / total,
                                Colors.indigo,
                              ),
                            if (qcReview > 0)
                              _RptSegment(
                                'QC Review',
                                qcReview / total,
                                Colors.deepPurple,
                              ),
                            if (clientReview > 0)
                              _RptSegment(
                                'Client Review',
                                clientReview / total,
                                Colors.teal,
                              ),
                            if (notStart > 0)
                              _RptSegment(
                                'Not Started',
                                notStart / total,
                                Colors.grey.shade400,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _RptSection(
                  title: 'My Notes Status',
                  icon: Icons.comment_outlined,
                  child: totalNotes == 0
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No notes added yet.',
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.4),
                              fontSize: 13,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _RptStatCard(
                                    label: 'Total',
                                    value: '$totalNotes',
                                    color: cs.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _RptStatCard(
                                    label: 'Open',
                                    value: '$openNotes',
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _RptStatCard(
                                    label: 'Resolved',
                                    value: '$resolvedNotes',
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            if (totalNotes > 0) ...[
                              const SizedBox(height: 14),
                              _RptStatusBar(
                                segments: [
                                  if (resolvedNotes > 0)
                                    _RptSegment(
                                      'Resolved',
                                      resolvedNotes / totalNotes,
                                      Colors.green,
                                    ),
                                  if (openNotes > 0)
                                    _RptSegment(
                                      'Open',
                                      openNotes / totalNotes,
                                      Colors.orange,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                ),
                if (tasks.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _RptSection(
                    title: 'All Tasks',
                    icon: Icons.list_alt_rounded,
                    child: Column(
                      children: tasks.map((t) {
                        final tNotes = t.clientComments.length;
                        final tResolved = t.clientComments
                            .where((c) => c['isResolved'] == true)
                            .length;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _rptTaskStatusColor(t.status),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  t.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (tNotes > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tResolved == tNotes
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    tResolved == tNotes
                                        ? '$tNotes ✓'
                                        : '$tResolved/$tNotes',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: tResolved == tNotes
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              _RptTaskStatusBadge(t.status),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }
}

// ─── Report helper widgets ────────────────────────────────────────────────────

class _RptSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _RptSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RptStatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _RptStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.75)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RptSegment {
  final String label;
  final double fraction;
  final Color color;
  const _RptSegment(this.label, this.fraction, this.color);
}

class _RptStatusBar extends StatelessWidget {
  final List<_RptSegment> segments;
  const _RptStatusBar({required this.segments});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 12,
            child: Row(
              children: segments
                  .map(
                    (s) => Expanded(
                      flex: ((s.fraction * 100).round()).clamp(1, 100),
                      child: Container(color: s.color),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: segments
              .map(
                (s) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: s.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${s.label} ${(s.fraction * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _RptCircularProgress extends StatelessWidget {
  final double value;
  final Color color;
  const _RptCircularProgress({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 6,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Text(
            '${(value * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RptTaskStatusBadge extends StatelessWidget {
  final String status;
  const _RptTaskStatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final color = _rptTaskStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _rptTaskStatusLabel(status),
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Report helper functions ──────────────────────────────────────────────────

Color _rptTaskStatusColor(String s) => switch (s) {
  'not_started' => Colors.grey,
  'in_progress' => Colors.orange,
  'team_leader_review' => Colors.indigo,
  'qc_review' => Colors.deepPurple,
  'client_review' => Colors.teal,
  'completed' => Colors.green,
  _ => Colors.grey,
};

String _rptStatusLabel(dynamic s) =>
    const {'active': 'Active', 'completed': 'Completed', 'on_hold': 'On Hold'}[s
        as String?] ??
    (s?.toString() ?? '—');

String _rptTaskStatusLabel(String? s) =>
    const {
      'not_started': 'Not Started',
      'in_progress': 'In Progress',
      'team_leader_review': 'Team Leader Review',
      'qc_review': 'QC Review',
      'client_review': 'Client Review',
      'completed': 'Completed',
    }[s] ??
    (s ?? '—');

String _rptFmtDate(dynamic v) {
  if (v == null) return '—';
  try {
    if (v is Timestamp) {
      final d = v.toDate();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    if (v is String && v.isNotEmpty) return v;
  } catch (_) {}
  return '—';
}

String _rptFmtDateTime(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _rptFmtNow() {
  final d = DateTime.now();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

void _rptExcelHeader(Sheet sheet, List<String> headers) {
  sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
  for (var i = 0; i < headers.length; i++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        .cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#2E7D32'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      fontSize: 11,
    );
  }
}

void _rptExcelRow(Sheet sheet, List<CellValue> values, int rowIndex) {
  sheet.appendRow(values);
  final isEven = rowIndex % 2 == 0;
  for (var i = 0; i < values.length; i++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex))
        .cellStyle = CellStyle(
      backgroundColorHex: isEven
          ? ExcelColor.fromHexString('#FFFFFF')
          : ExcelColor.fromHexString('#F1F8E9'),
      fontSize: 10,
      verticalAlign: VerticalAlign.Center,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Note: _EngineersPickerDialog removed — replaced by EmployeePickerDropdown
// from lib/core/widgets/employee_picker_dropdown.dart

