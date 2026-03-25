import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../controllers/task_providers.dart';

class ProjectReportScreen extends ConsumerWidget {
  final ProjectModel project;
  const ProjectReportScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tasksAsync = ref.watch(projectTasksProvider(project.id));

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Project Report',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              project.name,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
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
                    Icons.bar_chart_outlined,
                    size: 64,
                    color: cs.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No tasks yet',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProjectSummaryCard(project: project, tasks: tasks),
              const SizedBox(height: 16),
              _SectionTitle(title: 'Overall Progress'),
              const SizedBox(height: 8),
              _OverallProgressCard(tasks: tasks),
              const SizedBox(height: 16),
              _SectionTitle(title: 'Progress by Discipline'),
              const SizedBox(height: 8),
              ..._buildDisciplineSections(tasks),
              const SizedBox(height: 16),
              _SectionTitle(title: 'Client Review Summary'),
              const SizedBox(height: 8),
              _ClientReviewSummaryCard(tasks: tasks),
              const SizedBox(height: 16),
              if (tasks.any((t) => t.isOverdue)) ...[
                _SectionTitle(title: 'Overdue Tasks', color: Colors.red),
                const SizedBox(height: 8),
                _OverdueTasksCard(tasks: tasks),
                const SizedBox(height: 16),
              ],
              _SectionTitle(title: 'All Tasks'),
              const SizedBox(height: 8),
              _AllTasksSection(tasks: tasks),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildDisciplineSections(List<TaskModel> tasks) {
    final byDiscipline = <String, List<TaskModel>>{};
    for (final t in tasks) {
      byDiscipline.putIfAbsent(t.discipline, () => []).add(t);
    }

    return byDiscipline.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _DisciplineProgressCard(
          discipline: entry.key,
          tasks: entry.value,
        ),
      );
    }).toList();
  }
}

class _ProjectSummaryCard extends StatelessWidget {
  final ProjectModel project;
  final List<TaskModel> tasks;

  const _ProjectSummaryCard({required this.project, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalPlanned = tasks.fold(0.0, (sum, t) => sum + t.plannedHours);
    final totalActual = tasks.fold(0.0, (sum, t) => sum + t.actualHours);
    final overdue = tasks.where((t) => t.isOverdue).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.clientName,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      project.projectCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _WhiteChip(project.statusLabel),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SummaryMetric(
                label: 'Total Tasks',
                value: '${tasks.length}',
                color: Colors.white,
              ),
              _SummaryMetric(
                label: 'Planned Hours',
                value: totalPlanned.toStringAsFixed(0),
                color: Colors.white,
              ),
              _SummaryMetric(
                label: 'Actual Hours',
                value: totalActual.toStringAsFixed(0),
                color: totalActual > totalPlanned
                    ? Colors.orange.shade200
                    : Colors.white,
              ),
              if (overdue > 0)
                _SummaryMetric(
                  label: 'Overdue',
                  value: '$overdue',
                  color: Colors.red.shade200,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: project.completionPercentage / 100,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${project.completionPercentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 10),
          ),
        ],
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
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OverallProgressCard extends StatelessWidget {
  final List<TaskModel> tasks;
  const _OverallProgressCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = tasks.length;

    final counts = {
      'not_started': tasks.where((t) => t.status == 'not_started').length,
      'in_progress': tasks.where((t) => t.status == 'in_progress').length,
      'team_leader_review': tasks
          .where((t) => t.status == 'team_leader_review')
          .length,
      'qc_review': tasks.where((t) => t.status == 'qc_review').length,
      'client_review': tasks.where((t) => t.status == 'client_review').length,
      'completed': tasks.where((t) => t.status == 'completed').length,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  _ProgressSegment(
                    flex: counts['not_started']!,
                    total: total,
                    color: Colors.grey.shade300,
                  ),
                  _ProgressSegment(
                    flex: counts['in_progress']!,
                    total: total,
                    color: Colors.blue,
                  ),
                  _ProgressSegment(
                    flex: counts['team_leader_review']!,
                    total: total,
                    color: Colors.teal,
                  ),
                  _ProgressSegment(
                    flex: counts['qc_review']!,
                    total: total,
                    color: Colors.orange,
                  ),
                  _ProgressSegment(
                    flex: counts['client_review']!,
                    total: total,
                    color: Colors.purple,
                  ),
                  _ProgressSegment(
                    flex: counts['completed']!,
                    total: total,
                    color: Colors.green.shade700,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _LegendItem(
                color: Colors.grey.shade300,
                label: 'Not Started',
                count: counts['not_started']!,
              ),
              _LegendItem(
                color: Colors.blue,
                label: 'In Progress',
                count: counts['in_progress']!,
              ),
              _LegendItem(
                color: Colors.teal,
                label: 'Team Leader Review',
                count: counts['team_leader_review']!,
              ),
              _LegendItem(
                color: Colors.orange,
                label: 'QC Review',
                count: counts['qc_review']!,
              ),
              _LegendItem(
                color: Colors.purple,
                label: 'Client Review',
                count: counts['client_review']!,
              ),
              _LegendItem(
                color: Colors.green.shade700,
                label: 'Completed',
                count: counts['completed']!,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressSegment extends StatelessWidget {
  final int flex;
  final int total;
  final Color color;

  const _ProgressSegment({
    required this.flex,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (flex == 0 || total == 0) return const SizedBox.shrink();
    return Expanded(
      flex: flex,
      child: Container(color: color),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (count == 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.7)),
        ),
      ],
    );
  }
}

class _DisciplineProgressCard extends StatelessWidget {
  final String discipline;
  final List<TaskModel> tasks;

  const _DisciplineProgressCard({
    required this.discipline,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = tasks.length;
    final completed = tasks.where((t) => t.isCompleted).length;
    final inProgress = tasks.where((t) => t.status == 'in_progress').length;
    final underReview = tasks
        .where(
          (t) => t.status == 'team_leader_review' || t.status == 'qc_review',
        )
        .length;
    final clientStage = tasks.where((t) => t.status == 'client_review').length;
    final overdue = tasks.where((t) => t.isOverdue).length;
    final percentage = total > 0 ? (completed / total * 100) : 0.0;

    final plannedHours = tasks.fold(0.0, (s, t) => s + t.plannedHours);
    final actualHours = tasks.fold(0.0, (s, t) => s + t.actualHours);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              Expanded(
                child: Text(
                  discipline,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '$total tasks',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: percentage == 100 ? Colors.green : cs.primary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                percentage == 100 ? Colors.green : cs.primary,
              ),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              if (inProgress > 0)
                _MiniChip(label: '$inProgress in progress', color: Colors.blue),
              if (underReview > 0)
                _MiniChip(
                  label: '$underReview in review',
                  color: Colors.orange,
                ),
              if (clientStage > 0)
                _MiniChip(
                  label: '$clientStage with client',
                  color: Colors.purple,
                ),
              if (completed > 0)
                _MiniChip(label: '$completed done', color: Colors.green),
              if (overdue > 0)
                _MiniChip(label: '$overdue overdue', color: Colors.red),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 13,
                color: cs.onSurface.withOpacity(0.4),
              ),
              const SizedBox(width: 4),
              Text(
                '${actualHours.toStringAsFixed(1)}h actual / ${plannedHours.toStringAsFixed(1)}h planned',
                style: TextStyle(
                  fontSize: 11,
                  color: actualHours > plannedHours
                      ? Colors.orange
                      : cs.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientReviewSummaryCard extends StatelessWidget {
  final List<TaskModel> tasks;
  const _ClientReviewSummaryCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final awaitingClient = tasks
        .where((t) => t.status == 'client_review')
        .length;
    final clientApproved = tasks.where((t) => t.status == 'completed').length;
    final clientRejected = tasks
        .where((t) => t.clientReviewRound > 1 && t.status != 'completed')
        .length;
    final multiRound = tasks.where((t) => t.clientReviewRound > 1).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ClientMetric(
                icon: Icons.hourglass_empty_rounded,
                label: 'Awaiting Client',
                value: awaitingClient,
                color: Colors.orange,
              ),
              _ClientMetric(
                icon: Icons.check_circle_rounded,
                label: 'Client Approved',
                value: clientApproved,
                color: Colors.green,
              ),
              _ClientMetric(
                icon: Icons.cancel_rounded,
                label: 'Rejected Rounds',
                value: clientRejected,
                color: Colors.red,
              ),
              _ClientMetric(
                icon: Icons.replay_rounded,
                label: 'Multi-Round',
                value: multiRound,
                color: Colors.purple,
              ),
            ],
          ),
          if (multiRound > 0) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...(() {
              final sorted =
                  tasks.where((t) => t.clientReviewRound > 1).toList()..sort(
                    (a, b) =>
                        b.clientReviewRound.compareTo(a.clientReviewRound),
                  );

              return sorted
                  .take(3)
                  .map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.title,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Round ${t.clientReviewRound}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
            })(),
          ],
        ],
      ),
    );
  }
}

class _ClientMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _ClientMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}

class _OverdueTasksCard extends StatelessWidget {
  final List<TaskModel> tasks;
  const _OverdueTasksCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final overdue = tasks.where((t) => t.isOverdue).toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: overdue.asMap().entries.map((entry) {
          final i = entry.key;
          final task = entry.value;
          final daysLate = DateTime.now().difference(task.endDate).inDays;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${task.discipline} • ${task.assignedEngineerNames.join(', ')}',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$daysLate days late',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (i < overdue.length - 1) const Divider(height: 1, indent: 14),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _AllTasksSection extends StatelessWidget {
  final List<TaskModel> tasks;
  const _AllTasksSection({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final byDiscipline = <String, List<TaskModel>>{};
    for (final t in tasks) {
      byDiscipline.putIfAbsent(t.discipline, () => []).add(t);
    }

    return Column(
      children: byDiscipline.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CollapsibleTaskGroup(
            discipline: entry.key,
            tasks: entry.value,
          ),
        );
      }).toList(),
    );
  }
}

class _CollapsibleTaskGroup extends StatefulWidget {
  final String discipline;
  final List<TaskModel> tasks;

  const _CollapsibleTaskGroup({required this.discipline, required this.tasks});

  @override
  State<_CollapsibleTaskGroup> createState() => _CollapsibleTaskGroupState();
}

class _CollapsibleTaskGroupState extends State<_CollapsibleTaskGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final completed = widget.tasks.where((t) => t.isCompleted).length;
    final total = widget.tasks.length;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.discipline,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '$completed / $total',
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
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            ...widget.tasks.asMap().entries.map((entry) {
              final i = entry.key;
              final task = entry.value;
              return Column(
                children: [
                  _TaskReportRow(task: task),
                  if (i < widget.tasks.length - 1)
                    const Divider(height: 1, indent: 14),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _TaskReportRow extends StatelessWidget {
  final TaskModel task;
  const _TaskReportRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: task.isOverdue ? Colors.red : cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusDot(status: task.status),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 12,
                color: cs.onSurface.withOpacity(0.4),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  task.assignedEngineerNames.join(', '),
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                task.status != 'qc_review' &&
                        task.status != 'client_review' &&
                        task.status != 'completed'
                    ? Icons.radio_button_unchecked
                    : Icons.check_circle_rounded,
                size: 13,
                color:
                    task.status != 'qc_review' &&
                        task.status != 'client_review' &&
                        task.status != 'completed'
                    ? cs.onSurface.withOpacity(0.3)
                    : Colors.orange,
              ),
              const SizedBox(width: 2),
              Text(
                'Rev',
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withOpacity(0.4),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                task.status == 'completed'
                    ? Icons.check_circle_rounded
                    : task.clientReviewRound > 1 && task.status != 'completed'
                    ? Icons.cancel_rounded
                    : Icons.radio_button_unchecked,
                size: 13,
                color: task.status == 'completed'
                    ? Colors.green
                    : task.clientReviewRound > 1 && task.status != 'completed'
                    ? Colors.red
                    : cs.onSurface.withOpacity(0.3),
              ),
              const SizedBox(width: 2),
              Text(
                'Client',
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withOpacity(0.4),
                ),
              ),
              if (task.clientReviewRound > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'R${task.clientReviewRound}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: task.plannedHours > 0
                  ? (task.actualHours / task.plannedHours).clamp(0.0, 1.0)
                  : 0,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                task.actualHours > task.plannedHours
                    ? Colors.orange
                    : cs.primary.withOpacity(0.6),
              ),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color? color;

  const _SectionTitle({required this.title, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
        color: color ?? cs.onSurface,
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'not_started' => Colors.grey,
      'in_progress' => Colors.blue,
      'team_leader_review' => Colors.teal,
      'qc_review' => Colors.orange,
      'client_review' => Colors.purple,
      'completed' => Colors.green,
      _ => Colors.grey,
    };

    final label = switch (status) {
      'not_started' => 'Not Started',
      'in_progress' => 'In Progress',
      'team_leader_review' => 'Team Leader Review',
      'qc_review' => 'QC Review',
      'client_review' => 'Client Review',
      'completed' => 'Completed',
      _ => status,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
