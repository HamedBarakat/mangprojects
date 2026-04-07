import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../home/presentation/controllers/home_providers.dart';
import '../../../notifications/data/notification_repository.dart';
import '../../data/models/task_model.dart';
import '../controllers/task_providers.dart';
import '../controllers/project_providers.dart';
import 'task_details_screen.dart';
import 'project_details_screen.dart';
import '../../data/models/project_model.dart';
import '../../../employees/presentation/controllers/employee_providers.dart';
import '../../../employees/data/models/employee_model.dart';

class ManagementDashboardScreen extends ConsumerWidget {
  const ManagementDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider).value;
    final allTasksAsync = ref.watch(allOfficeTasksProvider);
    final overdueAsync = ref.watch(overdueTasksProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final employeesAsync = ref.watch(employeesProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Management Overview'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: cs.outlineVariant),
        ),
      ),
      body: allTasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allTasks) {
          // ── Compute stats ──────────────────────────────────────────────────
          final byStatus = <String, int>{};
          for (final t in allTasks) {
            byStatus[t.status] = (byStatus[t.status] ?? 0) + 1;
          }
          // رتب المتأخرة حسب الأولوية أولاً ثم تاريخ الانتهاء
          final overdue = List<TaskModel>.from(overdueAsync.value ?? <TaskModel>[])
            ..sort((a, b) {
              final p = a.priorityOrder.compareTo(b.priorityOrder);
              return p != 0 ? p : a.endDate.compareTo(b.endDate);
            });
          final urgentCount = overdue.where((t) => t.priority == 'urgent').length;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Urgent warning banner ──────────────────────────────────
                if (urgentCount > 0) ...[
                  _UrgentBanner(count: urgentCount),
                  const SizedBox(height: 16),
                ],

                // ── Overview stat cards ────────────────────────────────────
                _SectionHeader(title: 'Task Overview'),
                const SizedBox(height: 12),
                _StatsGrid(byStatus: byStatus, total: allTasks.length),
                const SizedBox(height: 24),

                // ── Overdue Alert ──────────────────────────────────────────
                if (overdue.isNotEmpty) ...[
                  _OverdueSection(tasks: overdue, ref: ref, user: user),
                  const SizedBox(height: 24),
                ],

                // ── Contracts Expiring ─────────────────────────────────────
                ...employeesAsync.when(
                  loading: () => [],
                  error: (_, _) => [],
                  data: (employees) {
                    final expiring = employees
                        .where((e) =>
                            e.isActive &&
                            (e.isContractExpiringSoon || e.isContractExpired))
                        .toList()
                      ..sort((a, b) {
                        final aDate = a.contractEndDate ?? DateTime(9999);
                        final bDate = b.contractEndDate ?? DateTime(9999);
                        return aDate.compareTo(bDate);
                      });
                    if (expiring.isEmpty) return [];
                    return [
                      _ContractsExpiringSection(employees: expiring),
                      const SizedBox(height: 24),
                    ];
                  },
                ),

                // ── Task status breakdown by project ───────────────────────
                _SectionHeader(title: 'By Project'),
                const SizedBox(height: 12),
                projectsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (projects) => _ProjectBreakdownList(
                    projects: projects,
                    allTasks: allTasks,
                  ),
                ),

                const SizedBox(height: 24),

                // ── In-review tasks (needing attention) ───────────────────
                _SectionHeader(title: 'Pending Review'),
                const SizedBox(height: 12),
                _PendingReviewList(
                  tasks: allTasks
                      .where((t) =>
                          t.status == 'team_leader_review' ||
                          t.status == 'qc_review' ||
                          t.status == 'client_review')
                      .toList()
                    ..sort((a, b) => a.endDate.compareTo(b.endDate)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 3, height: 16,
          decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(
          color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 15,
        )),
      ],
    );
  }
}

// ── Stats Grid ────────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final Map<String, int> byStatus;
  final int total;
  const _StatsGrid({required this.byStatus, required this.total});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Total', total, Icons.assignment_outlined, AppColors.info),
      ('Not Started', byStatus['not_started'] ?? 0, Icons.radio_button_unchecked, AppColors.slate400),
      ('In Progress', byStatus['in_progress'] ?? 0, Icons.pending_outlined, AppColors.info),
      ('TL Review', byStatus['team_leader_review'] ?? 0, Icons.rate_review_outlined, AppColors.warning),
      ('QC Review', byStatus['qc_review'] ?? 0, Icons.verified_outlined, AppColors.cyan500),
      ('Client Review', byStatus['client_review'] ?? 0, Icons.person_pin_outlined, Colors.purple),
      ('Completed', byStatus['completed'] ?? 0, Icons.check_circle_outline_rounded, AppColors.success),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final (label, count, icon, color) = items[i];
        return _StatCard(label: label, count: count, icon: icon, color: color);
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.count, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.cardOf(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: cs.subtleText, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Urgent Banner ─────────────────────────────────────────────────────────────
class _UrgentBanner extends StatelessWidget {
  final int count;
  const _UrgentBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.priority_high_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count urgent task${count == 1 ? '' : 's'} overdue — immediate attention required!',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overdue Section ───────────────────────────────────────────────────────────
class _OverdueSection extends StatelessWidget {
  final List<TaskModel> tasks;
  final WidgetRef ref;
  final dynamic user;
  const _OverdueSection({required this.tasks, required this.ref, required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3, height: 16,
              decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
            const SizedBox(width: 4),
            Text(
              'Overdue Tasks (${tasks.length})',
              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _sendOverdueAlerts(context),
              icon: const Icon(Icons.notifications_outlined, size: 16),
              label: const Text('Alert Team', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) => _OverdueTaskTile(task: tasks[i]),
        ),
      ],
    );
  }

  Future<void> _sendOverdueAlerts(BuildContext context) async {
    if (user == null) return;
    final now = DateTime.now();
    final notifRepo = NotificationRepository();
    final officeWide = await notifRepo.fetchOfficeWideStakeholders(user.officeId);
    int sent = 0;
    for (final task in tasks) {
      final daysOver = now.difference(task.endDate).inDays;
      final recipients = <String>{
        ...task.assignedEngineerIds,
        if (task.teamLeaderId.isNotEmpty) task.teamLeaderId,
        if (task.reviewerId.isNotEmpty) task.reviewerId,
        ...officeWide,
      };
      try {
        await notifRepo.sendOverdueAlert(
          officeId: task.officeId,
          taskId: task.id,
          taskTitle: task.title,
          projectId: task.projectId,
          projectName: task.projectName,
          recipientIds: recipients.toList(),
          daysOverdue: daysOver,
        );
        sent++;
      } catch (_) {}
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Overdue alerts sent for $sent tasks')),
      );
    }
  }
}

class _OverdueTaskTile extends StatelessWidget {
  final TaskModel task;
  const _OverdueTaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final daysOver = DateTime.now().difference(task.endDate).inDays;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TaskDetailsScreen(
                taskId: task.id,
                projectId: task.projectId,
                officeId: task.officeId,
              )),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            // مؤشر الأولوية — أحمر للعاجل، برتقالي للعالي، رمادي للباقي
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: task.priority == 'urgent'
                    ? Colors.red
                    : task.priority == 'high'
                        ? Colors.orange
                        : AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(task.title,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurface)),
                      ),
                      if (task.priority == 'urgent') ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                          ),
                          child: const Text('Urgent',
                              style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ] else if (task.priority == 'high') ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                          ),
                          child: const Text('High',
                              style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  Text('${task.projectName} · ${task.teamLeaderName}',
                      style: TextStyle(color: cs.subtleText, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$daysOver day${daysOver == 1 ? '' : 's'} late',
                    style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 4),
                Text(task.statusLabel, style: TextStyle(color: cs.subtleText, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Project Breakdown List ────────────────────────────────────────────────────
class _ProjectBreakdownList extends StatelessWidget {
  final List<ProjectModel> projects;
  final List<TaskModel> allTasks;
  const _ProjectBreakdownList({required this.projects, required this.allTasks});

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return Center(
        child: Text('No projects', style: TextStyle(color: Theme.of(context).colorScheme.subtleText)),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: projects.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final project = projects[i];
        final tasks = allTasks.where((t) => t.projectId == project.id).toList();
        if (tasks.isEmpty) return const SizedBox.shrink();

        final completed = tasks.where((t) => t.status == 'completed').length;
        final inReview = tasks.where((t) =>
            t.status == 'team_leader_review' ||
            t.status == 'qc_review' ||
            t.status == 'client_review').length;
        final overdue = tasks.where((t) =>
            t.status != 'completed' && t.endDate.isBefore(DateTime.now())).length;

        return InkWell(
          onTap: () => Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => ProjectDetailsScreen(project: project)),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: AppDecorations.cardOf(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(project.name,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface)),
                    ),
                    if (overdue > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$overdue overdue',
                            style: const TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: tasks.isEmpty ? 0 : completed / tasks.length,
                    minHeight: 6,
                    backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Pill(label: '${tasks.length} tasks', color: AppColors.info),
                    const SizedBox(width: 6),
                    _Pill(label: '$completed done', color: AppColors.success),
                    const SizedBox(width: 6),
                    if (inReview > 0)
                      _Pill(label: '$inReview review', color: AppColors.warning),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Pending Review List ───────────────────────────────────────────────────────
class _PendingReviewList extends StatelessWidget {
  final List<TaskModel> tasks;
  const _PendingReviewList({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (tasks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: AppDecorations.cardOf(context),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 40, color: AppColors.success),
            const SizedBox(height: 8),
            Text('No tasks pending review', style: TextStyle(color: cs.subtleText)),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final task = tasks[i];
        final statusColor = AppStatusColors.forTaskStatus(task.status);
        final isOverdue = task.endDate.isBefore(DateTime.now());

        return InkWell(
          onTap: () => Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => TaskDetailsScreen(
                taskId: task.id,
                projectId: task.projectId,
                officeId: task.officeId,
              )),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: AppDecorations.cardOf(context),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.pending_outlined, color: statusColor, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurface)),
                      Text('${task.projectName} · ${task.statusLabel}',
                          style: TextStyle(color: cs.subtleText, fontSize: 11)),
                    ],
                  ),
                ),
                if (isOverdue)
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Contracts Expiring Section ────────────────────────────────────────────────
class _ContractsExpiringSection extends StatelessWidget {
  final List<EmployeeModel> employees;
  const _ContractsExpiringSection({required this.employees});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Contracts Expiring (${employees.length})'),
        const SizedBox(height: 12),
        ...employees.map((e) => _ContractTile(employee: e)),
      ],
    );
  }
}

class _ContractTile extends StatelessWidget {
  final EmployeeModel employee;
  const _ContractTile({required this.employee});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isExpired = employee.isContractExpired;
    final color = isExpired ? AppColors.error : AppColors.warning;
    final endDate = employee.contractEndDate!;
    final daysLeft = endDate.difference(DateTime.now()).inDays;
    final label = isExpired
        ? 'Expired ${(-daysLeft)} day${-daysLeft == 1 ? '' : 's'} ago'
        : 'Expires in $daysLeft day${daysLeft == 1 ? '' : 's'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(
              employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(employee.name,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurface)),
                Text(employee.jobTitleLabel,
                    style: TextStyle(color: cs.subtleText, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
