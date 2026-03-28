import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/controllers/home_providers.dart';
import '../../../projects/data/models/task_model.dart';
import '../../../projects/presentation/controllers/task_providers.dart';
import '../../../projects/presentation/widgets/task_comments_widget.dart';
import 'task_details_screen.dart';

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
    final user = ref.read(currentUserProvider).value;
    final tabCount = _tabCount(user);
    _tabController = TabController(length: tabCount, vsync: this);
  }

  int _tabCount(dynamic user) {
    if (user == null) return 1;
    // All roles get 2 tabs
    // Client gets 1 tab (only sees client_review tasks assigned to them)
    if (user.isClient) return 1;
    return 2;
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
    final isTeamLeader = user?.isTeamLeader ?? false;

    List<Widget> tabs = [];
    List<Widget> tabViews = [];

    // ══════════════════════════════════════════════════════════════════════
    // TAB DESIGN:
    //   "My Tasks"  → tasks this user has a direct role in (any active status)
    //   "All Tasks" → full office view (Admin/Mgmt/Reviewer/DC/TL)
    //   Client      → single tab, only their client_review tasks
    //
    // Every task stays visible to all stakeholders until completed (archived).
    // Actions only appear for the role whose turn it is in the workflow.
    // ══════════════════════════════════════════════════════════════════════

    final isClient = user?.isClient ?? false;

    if (isClient) {
      // Client: single tab — only sees tasks pending their approval
      tabs = [const Tab(text: 'My Reviews')];
      tabViews = [_MyTasksTrackerList(user: user)];
    } else if (isTeamLeader) {
      tabs = [
        const Tab(text: 'My Tasks'),
        const Tab(text: 'All Tasks'),
      ];
      tabViews = [
        _MyTasksTrackerList(user: user),
        _AllOfficeTasksList(user: user, statusFilter: _statusFilter),
      ];
    } else if (isReviewer) {
      tabs = [
        const Tab(text: 'My Tasks'),
        const Tab(text: 'All Tasks'),
      ];
      tabViews = [
        _MyTasksTrackerList(user: user),
        _AllOfficeTasksList(user: user, statusFilter: _statusFilter),
      ];
    } else if (user?.isAdmin == true || user?.isManagement == true) {
      tabs = [
        const Tab(text: 'All Tasks'),
        const Tab(text: 'Completed'),
      ];
      tabViews = [
        _AllOfficeTasksList(user: user, statusFilter: _statusFilter),
        _AllOfficeTasksList(user: user, statusFilter: 'completed'),
      ];
    } else if (user?.isDC == true) {
      tabs = [
        const Tab(text: 'My Tasks'),
        const Tab(text: 'All Tasks'),
      ];
      tabViews = [
        _MyTasksTrackerList(user: user),
        _AllOfficeTasksList(user: user, statusFilter: _statusFilter),
      ];
    } else {
      // Engineer — 2 tabs
      tabs = [
        const Tab(text: 'My Tasks'),
        const Tab(text: 'All Tasks'),
      ];
      tabViews = [
        _MyTasksTrackerList(user: user),
        _AllOfficeTasksList(user: user, statusFilter: _statusFilter),
      ];
    }

    final hasTabs = tabs.length > 1;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: const Text(
          'My Tasks',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: hasTabs
            ? TabBar(controller: _tabController, tabs: tabs)
            : null,
      ),
      body: hasTabs
          ? TabBarView(controller: _tabController, children: tabViews)
          : tabViews.first,
    );
  }
}

class _ClientReviewTasksList extends ConsumerWidget {
  final dynamic user;

  const _ClientReviewTasksList({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(pendingClientReviewTasksProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const _EmptyState(
            icon: Icons.person_outline,
            message: 'No tasks pending your review',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _TaskCard(
            task: tasks[i],
            user: user,
            ref: ref,
            mode: _CardMode.clientReview, // ✅ مهم جدًا
          ),
        );
      },
    );
  }
}

// ── Badge Dot ─────────────────────────────────────────────────────────────────

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
      ('team_leader_review', 'Team Leader Review'),
      ('qc_review', 'QC Review'),
      ('client_review', 'Client Review'),
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
    final tasksAsync = ref.watch(allVisibleTasksProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tasks) {
        final filtered = statusFilter == 'all'
            ? tasks
            : tasks.where((t) => t.status == statusFilter).toList();

        if (filtered.isEmpty) {
          return _EmptyState(
            icon: Icons.task_outlined,
            message: statusFilter == 'all'
                ? 'No tasks assigned yet'
                : 'No ${_statusLabel(statusFilter)} tasks',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _TaskCard(
            task: filtered[i],
            user: user,
            ref: ref,
            mode: _cardMode(filtered[i]),
          ),
        );
      },
    );
  }

  _CardMode _cardMode(TaskModel task) {
    // ✅ FIX: delegate to centralized resolver so all role checks are consistent
    return getTaskMode(task, user);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'not_started':
        return 'Not Started';
      case 'in_progress':
        return 'In Progress';
      case 'team_leader_review':
        return 'Team Leader Review';
      case 'qc_review':
        return 'QC Review';
      case 'client_review':
        return 'Client Review';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }
}

// ── Team Leader Review List ───────────────────────────────────────────────────

class _TeamLeaderReviewList extends ConsumerWidget {
  final dynamic user;

  const _TeamLeaderReviewList({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(pendingTeamLeaderReviewTasksProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const _EmptyState(
            icon: Icons.fact_check_outlined,
            message: 'No tasks pending your review',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _TaskCard(
            task: tasks[i],
            user: user,
            ref: ref,
            mode: _CardMode.teamLeaderReview,
          ),
        );
      },
    );
  }
}

// ── QC Review List ────────────────────────────────────────────────────────────

class _QcReviewTasksList extends ConsumerWidget {
  final dynamic user;

  const _QcReviewTasksList({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(pendingQcReviewTasksProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const _EmptyState(
            icon: Icons.rate_review_outlined,
            message: 'No tasks pending QC review',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _TaskCard(
            task: tasks[i],
            user: user,
            ref: ref,
            mode: _CardMode.qcReview,
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _MyTasksTrackerList — "My Tasks" tab
// Shows all tasks this user is directly involved in (any status except completed)
// Each task shows the correct action button for this user's role & the task's
// current status. When it's not this user's turn → viewOnly (no button).
// ══════════════════════════════════════════════════════════════════════════════
class _MyTasksTrackerList extends ConsumerWidget {
  final dynamic user;
  const _MyTasksTrackerList({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allVisibleTasksProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tasks) {
        final uid = user?.uid ?? '';
        final isEngineer = user?.isEngineer == true;
        final isTeamLeader = user?.isTeamLeader == true;
        final isReviewer = user?.isReviewer == true;
        final isDC = user?.isDC == true;

        // ── Filter logic per role ────────────────────────────────────────
        // Engineer "My Tasks":  only tasks still in their court (not_started / in_progress)
        //   Once submitted → moves to "All Tasks" tab for tracking
        // TL "My Tasks":        tasks pending their review (team_leader_review)
        //   + tasks in progress they need to watch (not_started / in_progress)
        // QC "My Tasks":        tasks pending their review (qc_review)
        //   + earlier stages they assigned as reviewer
        // DC "My Tasks":        tasks at client_review stage (ready to dispatch)
        // Client:               tasks at client_review (handled by allVisibleTasksProvider)
        // Admin/Mgmt:           uses _AllOfficeTasksList — not this widget

        List<TaskModel> active;

        if (isEngineer) {
          // Engineer only sees their own turn: not_started + in_progress
          // Submitted tasks (team_leader_review / qc_review / client_review) → All Tasks tab
          active = tasks
              .where((t) =>
                  (t.assignedEngineerIds as List<dynamic>? ?? []).contains(uid) &&
                  (t.status == 'not_started' || t.status == 'in_progress'))
              .toList()
            ..sort((a, b) => a.endDate.compareTo(b.endDate));
        } else if (isTeamLeader) {
          // TL sees tasks pending their action (team_leader_review)
          // + tasks still being worked on in their projects (so they can track)
          active = tasks
              .where((t) =>
                  t.teamLeaderId == uid &&
                  (t.status == 'not_started' ||
                   t.status == 'in_progress' ||
                   t.status == 'team_leader_review'))
              .toList()
            ..sort((a, b) => a.endDate.compareTo(b.endDate));
        } else if (isReviewer) {
          // QC sees tasks pending their review action
          active = tasks
              .where((t) =>
                  t.reviewerId == uid &&
                  t.status == 'qc_review')
              .toList()
            ..sort((a, b) => a.endDate.compareTo(b.endDate));
        } else if (isDC) {
          // DC sees tasks ready to dispatch to client
          active = tasks
              .where((t) => t.status == 'client_review')
              .toList()
            ..sort((a, b) => a.endDate.compareTo(b.endDate));
        } else {
          // Client / others — show all non-completed
          active = tasks
              .where((t) => t.status != 'completed')
              .toList()
            ..sort((a, b) => a.endDate.compareTo(b.endDate));
        }

        if (active.isEmpty) {
          return const _EmptyState(
            icon: Icons.task_outlined,
            message: 'No active tasks',
          );
        }

        // Group by discipline for readability
        final byDiscipline = <String, List<TaskModel>>{};
        for (final t in active) {
          byDiscipline.putIfAbsent(t.discipline, () => []).add(t);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: byDiscipline.entries.map((entry) {
            return _DisciplineGroup(
              discipline: entry.key,
              tasks: entry.value,
              user: user,
            );
          }).toList(),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _AllOfficeTasksList — "All Tasks" tab
// Admin / Management / TL / QC / DC can see all office tasks with status filter
// viewOnly — no action buttons here
// ══════════════════════════════════════════════════════════════════════════════
class _AllOfficeTasksList extends ConsumerWidget {
  final dynamic user;
  final String statusFilter;
  const _AllOfficeTasksList({required this.user, required this.statusFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allVisibleTasksProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tasks) {
        final uid = user?.uid ?? '';
        final isEngineer = user?.isEngineer == true;
        final isTeamLeader = user?.isTeamLeader == true;
        final isReviewer = user?.isReviewer == true;

        List<TaskModel> filtered;

        if (statusFilter == 'completed') {
          filtered = tasks.where((t) => t.status == 'completed').toList();
        } else if (isEngineer) {
          // Engineer "All Tasks": all their assigned tasks (any active status)
          // This is where they track submitted tasks (qc_review, client_review, etc.)
          filtered = tasks
              .where((t) =>
                  (t.assignedEngineerIds as List<dynamic>? ?? []).contains(uid) &&
                  t.status != 'completed')
              .toList();
        } else if (isTeamLeader) {
          // TL "All Tasks": all tasks in their projects including advanced stages
          filtered = tasks
              .where((t) =>
                  t.teamLeaderId == uid &&
                  t.status != 'completed')
              .toList();
        } else if (isReviewer) {
          // QC "All Tasks": all tasks assigned to them as reviewer (full tracking)
          filtered = tasks
              .where((t) =>
                  t.reviewerId == uid &&
                  t.status != 'completed')
              .toList();
        } else {
          // Admin / Management / DC — see all office tasks
          filtered = tasks.where((t) => t.status != 'completed').toList();
        }

        filtered.sort((a, b) => a.endDate.compareTo(b.endDate));

        if (filtered.isEmpty) {
          return const _EmptyState(
            icon: Icons.task_outlined,
            message: 'No tasks',
          );
        }

        final byDiscipline = <String, List<TaskModel>>{};
        for (final t in filtered) {
          byDiscipline.putIfAbsent(t.discipline, () => []).add(t);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: byDiscipline.entries.map((entry) {
            return _DisciplineGroup(
              discipline: entry.key,
              tasks: entry.value,
              user: user,
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Discipline Group ─────────────────────────────────────────────────────────
class _DisciplineGroup extends StatelessWidget {
  final String discipline;
  final List<TaskModel> tasks;
  final dynamic user;

  const _DisciplineGroup({
    required this.discipline,
    required this.tasks,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    discipline,
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${tasks.length} task${tasks.length > 1 ? "s" : ""}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...tasks.map(
            (task) => Consumer(
              builder: (_, ref, _) => _TaskCard(
                task: task,
                user: user,
                ref: ref,
                mode: getTaskMode(task, user),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card Mode Enum ────────────────────────────────────────────────────────────

// 🔥 UNIFIED TASK LIST (Stage 2) — kept for backward compatibility
class _UnifiedTasksList extends ConsumerWidget {
  final bool showOnlyAssigned;
  final String statusFilter;
  final dynamic user;
  // للـ Team Leader فقط: true = "My Tasks" (معيّن كمهندس), false = "Team Tasks" (مشاريعه)
  final bool teamLeaderMyTasks;

  const _UnifiedTasksList({
    required this.statusFilter,
    required this.user,
    required this.showOnlyAssigned,
    this.teamLeaderMyTasks = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allVisibleTasksProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tasks) {
        final uid = user?.uid ?? '';
        // ✅ FIX: use isTeamLeader NOT canManageTasks
        final isTeamLeader = user?.isTeamLeader == true;
        final isReviewer   = user?.isReviewer == true;
        final isDC         = user?.isDC == true;
        final isEngineer   = user?.isEngineer == true;
        // Admin + Management see all tasks — allVisibleTasksProvider
        // already returns full office tasks for them

        List<TaskModel> filtered;

        // ══════════════════════════════════════════════════════════════════
        // TEAM LEADER
        // ══════════════════════════════════════════════════════════════════
        if (isTeamLeader) {
          // Team Leader tracks ALL tasks in their projects (any active status)
          // getTaskMode() will show Approve/Reject button only on team_leader_review
          filtered = tasks
              .where((t) =>
                  t.teamLeaderId == uid &&
                  t.status != 'completed')
              .toList()
            ..sort((a, b) => a.endDate.compareTo(b.endDate));

        // ══════════════════════════════════════════════════════════════════
        // QC / REVIEWER
        // ══════════════════════════════════════════════════════════════════
        } else if (isReviewer) {
          // Reviewer tracks all tasks assigned to them (any active status)
          // getTaskMode() shows Approve/Reject only when status == qc_review
          filtered = tasks
              .where((t) =>
                  t.reviewerId == uid &&
                  t.status != 'completed')
              .toList()
            ..sort((a, b) => a.endDate.compareTo(b.endDate));

        // ══════════════════════════════════════════════════════════════════
        // DC
        // ══════════════════════════════════════════════════════════════════
        } else if (isDC) {
          // DC tracks tasks from client_review onward + monitors all active tasks
          // getTaskMode() always returns viewOnly for DC
          filtered = tasks
              .where((t) => t.status != 'completed')
              .toList();

        // ══════════════════════════════════════════════════════════════════
        // ENGINEER
        // ══════════════════════════════════════════════════════════════════
        } else if (isEngineer) {
          // Engineer tracks all assigned tasks (any active status)
          // getTaskMode() shows Start/Submit only when assigned + right status
          filtered = tasks
              .where((t) => t.status != 'completed')
              .toList();

        // ══════════════════════════════════════════════════════════════════
        // ADMIN / MANAGEMENT — see all, filtered by status
        // ══════════════════════════════════════════════════════════════════
        } else {
          if (showOnlyAssigned) {
            // "My Tasks" for Admin = tasks completed (archive view)
            filtered = tasks
                .where((t) => t.status == 'completed')
                .toList();
          } else {
            if (statusFilter == 'all') {
              filtered = tasks
                  .where((t) => t.status != 'completed')
                  .toList();
            } else {
              filtered = tasks
                  .where((t) => t.status == statusFilter)
                  .toList();
            }
          }
        }

        if (filtered.isEmpty) {
          return const _EmptyState(
            icon: Icons.task_outlined,
            message: 'No tasks available',
          );
        }

        // 🔥 Group by discipline (Client style) WITHOUT removing original structure
        final byDiscipline = <String, List<TaskModel>>{};
        for (final t in filtered) {
          byDiscipline.putIfAbsent(t.discipline, () => []).add(t);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: byDiscipline.entries.map((entry) {
            final discipline = entry.key;
            final tasks = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withOpacity(0.5),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            discipline,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${tasks.length} task${tasks.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ...tasks.map(
                    (task) => _TaskCard(
                      task: task,
                      user: user,
                      ref: ref,
                      mode: getTaskMode(task, user),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// getTaskMode — Centralized action resolver
//
// Task Cycle: not_started → in_progress → team_leader_review → qc_review
//             → client_review → completed (archived)
//
// PRINCIPLE: Every stakeholder SEES the task until completed.
//            But only the role whose TURN it is gets action buttons.
//
//   Engineer     → startTask (not_started) or submitToTeamLeader (in_progress)
//                  ONLY if uid is in assignedEngineerIds
//   Team Leader  → teamLeaderReview (team_leader_review) — Approve → QC / Reject → Engineers
//                  viewOnly on all other statuses (watches progress)
//   QC/Reviewer  → qcReview (qc_review) — Approve → Client / Reject → TL
//                  viewOnly on all other statuses
//   Client       → clientReview (client_review) — Approve → completed / Reject → QC
//                  viewOnly on all other statuses
//   DC           → viewOnly always (tracks task flow, dispatches docs)
//   Admin/Mgmt   → viewOnly always (oversight, no direct task actions)
// ══════════════════════════════════════════════════════════════════════════════
_CardMode getTaskMode(TaskModel task, dynamic user) {
  if (user == null) return _CardMode.viewOnly;

  // ── Client ──────────────────────────────────────────────────────────────
  if (user.isClient) {
    if (task.status == 'client_review') return _CardMode.clientReview;
    return _CardMode.viewOnly; // can track other statuses but no action
  }

  // ── Team Leader ─────────────────────────────────────────────────────────
  // TL sees ALL tasks in their projects (allVisibleTasksProvider returns them).
  // Action only when it's their turn: team_leader_review.
  if (user.isTeamLeader) {
    if (task.status == 'team_leader_review') return _CardMode.teamLeaderReview;
    return _CardMode.viewOnly; // tracks in_progress, qc_review, client_review
  }

  // ── QC / Reviewer ───────────────────────────────────────────────────────
  // QC sees tasks assigned to them as reviewer.
  // Action only when status == qc_review AND they are the designated reviewer.
  if (user.isReviewer) {
    if (task.status == 'qc_review' && task.reviewerId == user.uid) {
      return _CardMode.qcReview;
    }
    return _CardMode.viewOnly;
  }

  // ── Engineer ────────────────────────────────────────────────────────────
  // Engineer acts ONLY on tasks they are assigned to.
  if (user.isEngineer) {
    final assignedToMe = (task.assignedEngineerIds as List<dynamic>? ?? [])
        .contains(user.uid);
    if (!assignedToMe) return _CardMode.viewOnly;
    if (task.status == 'not_started') return _CardMode.startTask;
    if (task.status == 'in_progress') return _CardMode.submitToTeamLeader;
    // Once submitted (team_leader_review / qc_review / client_review)
    // engineer can still track their task — viewOnly
    return _CardMode.viewOnly;
  }

  // ── DC / Admin / Management → always viewOnly ───────────────────────────
  return _CardMode.viewOnly;
}

enum _CardMode {
  viewOnly,
  startTask,
  submitToTeamLeader,
  teamLeaderReview,
  qcReview,
  clientReview, // ✅ أضفنا ده
}

// ── Task Card ─────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final dynamic user;
  final WidgetRef ref;
  final _CardMode mode;

  const _TaskCard({
    required this.task,
    required this.user,
    required this.ref,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
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
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: task.isOverdue
                ? Colors.red.withOpacity(0.3)
                : cs.outlineVariant.withOpacity(0.5),
          ),
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
                  const SizedBox(width: 8),
                  _StatusBadge(status: task.status),
                ],
              ),

              if (task.isOverdue) ...[
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 13,
                      color: Colors.red,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Overdue',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],

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

              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _InfoChip(
                    icon: Icons.category_outlined,
                    label: task.category,
                  ),
                  _InfoChip(
                    icon: Icons.engineering_outlined,
                    label: task.discipline,
                  ),
                  _InfoChip(
                    icon: Icons.group_outlined,
                    label: '${task.assignedEngineerNames.length} engineers',
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
                      color: task.isOverdue
                          ? Colors.red
                          : cs.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: task.normalizedProgress / 100,
                        backgroundColor: cs.surfaceContainerHighest,
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${task.normalizedProgress.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),

              if (task.taskLink.isNotEmpty) ...[
                const SizedBox(height: 8),
                _TaskLinkRow(link: task.taskLink),
              ],

              if (task.teamLeaderReviewNotes.isNotEmpty) ...[
                const SizedBox(height: 8),
                _NoteBox(
                  label: 'Team Leader',
                  note: task.teamLeaderReviewNotes,
                  color: Colors.teal,
                  icon: Icons.supervisor_account_outlined,
                ),
              ],

              if (task.qcReviewNotes.isNotEmpty) ...[
                const SizedBox(height: 8),
                _NoteBox(
                  label: 'QC',
                  note: task.qcReviewNotes,
                  color: Colors.purple,
                  icon: Icons.rate_review_outlined,
                ),
              ],

              if (task.clientReviewRound > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.send_rounded,
                      size: 12,
                      color: Colors.blue.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sent to client: round ${task.clientReviewRound}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],

              if (task.clientReviewNotes.isNotEmpty) ...[
                const SizedBox(height: 8),
                _NoteBox(
                  label: 'Client',
                  note: task.clientReviewNotes,
                  color: Colors.indigo,
                  icon: Icons.person_outline,
                ),
              ],

              if (task.clientComments.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                _ClientCommentsSection(comments: task.clientComments),
              ],

              if (mode != _CardMode.viewOnly) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _buildActions(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    switch (mode) {
      case _CardMode.startTask:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _startTask(context),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Start Task'),
          ),
        );

      case _CardMode.submitToTeamLeader:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _submitToTeamLeaderReview(context),
            icon: const Icon(Icons.upload_rounded, size: 18),
            label: const Text('Submit to Team Leader'),
          ),
        );

      case _CardMode.teamLeaderReview:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _teamLeaderAction(context, reject: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () => _teamLeaderAction(context, reject: false),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Send to QC'),
              ),
            ),
          ],
        );

      case _CardMode.qcReview:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _qcAction(context, reject: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FilledButton(
                onPressed: () => _qcAction(context, reject: false),
                child: const Text('Approve'),
              ),
            ),
          ],
        );

      case _CardMode.clientReview:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _clientAction(context, reject: true),
                icon: const Icon(Icons.close_rounded, size: 16),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                label: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _clientAction(context, reject: false),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Approve'),
              ),
            ),
          ],
        );

      case _CardMode.viewOnly:
        return const SizedBox.shrink();

      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _startTask(BuildContext context) async {
    final userName = ref.read(currentUserProvider).value?.name ?? '';
    await ref.read(taskRepositoryProvider).startTask(task.id,
        userName: userName);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task started ✓')));
    }
  }

  Future<void> _submitToTeamLeaderReview(BuildContext context) async {
    final userName = ref.read(currentUserProvider).value?.name ?? '';
    await ref.read(taskRepositoryProvider).submitToTeamLeaderReview(task.id,
        userName: userName);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submitted to Team Leader ✓')),
      );
    }
  }

  Future<void> _teamLeaderAction(
    BuildContext context, {
    required bool reject,
  }) async {
    final container = ProviderScope.containerOf(context);
    final notes = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: _TaskReviewSheet(
          task: task,
          title: reject ? 'Reject & Return to Engineers' : 'Send to QC',
          confirmText: reject ? 'Reject' : 'Send to QC',
          confirmColor: reject ? Colors.red : null,
          notesHint: reject
              ? 'Enter notes for engineers...'
              : 'Optional notes...',
        ),
      ),
    );

    if (notes == null) return;

    final userName = ref.read(currentUserProvider).value?.name ?? '';
    if (reject) {
      await ref
          .read(taskRepositoryProvider)
          .teamLeaderRejectToInProgress(
              taskId: task.id, notes: notes, userName: userName);
    } else {
      await ref
          .read(taskRepositoryProvider)
          .teamLeaderApproveToQc(
              taskId: task.id, notes: notes, userName: userName);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reject ? 'Returned to engineers ✓' : 'Sent to QC ✓'),
        ),
      );
    }
  }

  Future<void> _qcAction(BuildContext context, {required bool reject}) async {
    final container = ProviderScope.containerOf(context);
    final notes = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: _TaskReviewSheet(
          task: task,
          title: reject ? 'Reject Task' : 'Approve to Client',
          confirmText: 'Confirm',
          confirmColor: reject ? Colors.red : null,
          notesHint: reject ? 'Enter notes...' : 'Optional notes...',
        ),
      ),
    );

    if (notes == null) return;

    final userName = ref.read(currentUserProvider).value?.name ?? '';
    if (reject) {
      await ref
          .read(taskRepositoryProvider)
          .qcRejectToTeamLeader(
              taskId: task.id, notes: notes, userName: userName);
    } else {
      await ref
          .read(taskRepositoryProvider)
          .qcApproveToClient(
              taskId: task.id, notes: notes, userName: userName);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QC review submitted ✓')));
    }
  }

  Future<void> _clientAction(
    BuildContext context, {
    required bool reject,
  }) async {
    // ✅ FIX: use proper repository methods (old code wrote invalid status values)
    final container = ProviderScope.containerOf(context);
    final notes = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: _TaskReviewSheet(
          task: task,
          title: reject ? 'Reject Task' : 'Approve Task',
          confirmText: reject ? 'Reject' : 'Approve',
          confirmColor: reject ? Colors.red : null,
          notesHint: reject
              ? 'Enter rejection notes...'
              : 'Optional approval notes...',
        ),
      ),
    );

    if (notes == null) return; // user cancelled

    final userName = ref.read(currentUserProvider).value?.name ?? '';
    try {
      if (reject) {
        await ref.read(taskRepositoryProvider).clientRejectToQc(
              taskId: task.id,
              notes: notes,
              userName: userName,
            );
      } else {
        await ref.read(taskRepositoryProvider).clientApproveTask(
              taskId: task.id,
              notes: notes,
              userName: userName,
            );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reject
                  ? 'Task returned to QC ✓'
                  : 'Task approved ✓',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _TaskReviewSheet extends StatefulWidget {
  final TaskModel task;
  final String title;
  final String confirmText;
  final Color? confirmColor;
  final String notesHint;

  const _TaskReviewSheet({
    required this.task,
    required this.title,
    required this.confirmText,
    required this.notesHint,
    this.confirmColor,
  });

  @override
  State<_TaskReviewSheet> createState() => _TaskReviewSheetState();
}

class _TaskReviewSheetState extends State<_TaskReviewSheet> {
  late final TextEditingController _notesController;

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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.65,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.task.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.task.projectName,
                            style: TextStyle(
                              color: cs.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 🔥 Add Comment Section (بديل Review Notes)
                          Text(
                            'Add Comment',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),

                          const SizedBox(height: 8),

                          TaskCommentsSection(
                            taskId: widget.task.id,
                            projectId: widget.task.projectId,
                            officeId: widget.task.officeId,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      border: Border(
                        top: BorderSide(
                          color: cs.outlineVariant.withOpacity(0.4),
                        ),
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
                          child: FilledButton(
                            style: widget.confirmColor != null
                                ? FilledButton.styleFrom(
                                    backgroundColor: widget.confirmColor,
                                  )
                                : null,
                            onPressed: () {
                              Navigator.pop(
                                context,
                                _notesController.text.trim(),
                              );
                            },
                            child: Text(widget.confirmText),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Note Box ──────────────────────────────────────────────────────────────────

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

// ── Empty State ───────────────────────────────────────────────────────────────

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

// ── Reusable Widgets ──────────────────────────────────────────────────────────

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
    final hasUnread = unread > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasUnread
                  ? Colors.orange.withOpacity(0.12)
                  : Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.comment_outlined,
                  size: 13,
                  color: hasUnread ? Colors.orange : Colors.blue,
                ),
                const SizedBox(width: 5),
                Text(
                  hasUnread
                      ? 'Client Notes ($unread new)'
                      : 'Client Notes ($count)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasUnread ? Colors.orange : Colors.blue,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: hasUnread ? Colors.orange : Colors.blue,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 10),
          ...widget.comments.map((c) {
            final text = c['text'] as String? ?? '';
            final round = c['round'] as int? ?? 0;
            final type = c['type'] as String? ?? '';
            final isRead = c['isRead'] as bool? ?? true;
            final createdAt = c['createdAt'];
            final dateStr = _fmtTimestamp(createdAt);
            final isRejected = type == 'rejected';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: !isRead
                    ? Colors.orange.withOpacity(0.07)
                    : isRejected
                    ? Colors.red.withOpacity(0.05)
                    : Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: !isRead
                      ? Colors.orange.withOpacity(0.3)
                      : isRejected
                      ? Colors.red.withOpacity(0.2)
                      : Colors.green.withOpacity(0.2),
                ),
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
                              'Client • Round $round',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            if (!isRead) ...[
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Icon(
                              isRejected
                                  ? Icons.cancel_outlined
                                  : Icons.check_circle_outline,
                              size: 12,
                              color: isRejected ? Colors.red : Colors.green,
                            ),
                            const SizedBox(width: 4),
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

  String _fmtTimestamp(dynamic v) {
    if (v == null) return '';
    try {
      DateTime d;
      if (v is Timestamp) {
        d = v.toDate();
      } else {
        return '';
      }
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

// ================= CLIENT REVIEW PROVIDER =================

final pendingClientReviewTasksProvider = StreamProvider<List<TaskModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;

  if (user == null || user.linkedClientId == null) {
    return const Stream.empty();
  }

  return FirebaseFirestore.instance
      .collection('tasks')
      .where('clientId', isEqualTo: user.linkedClientId)
      .where('status', isEqualTo: 'client_review')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList(),
      );
});

// ── Task Link Row — نسخ + فتح (web + local paths) ────────────────────────────
class _TaskLinkRow extends StatelessWidget {
  final String link;
  const _TaskLinkRow({required this.link});

  bool get _isLocal =>
      link.startsWith('\\\\') ||
      link.startsWith('//') ||
      RegExp(r'^[A-Za-z]:[\\\/]').hasMatch(link);

  bool get _isWeb =>
      link.startsWith('http://') || link.startsWith('https://');

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied ✓'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(link);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _isLocal ? Colors.orange.shade700 : Colors.blue;
    final icon = _isLocal
        ? Icons.storage_rounded
        : _isWeb
            ? Icons.open_in_new_rounded
            : Icons.link_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              link,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                decoration: _isWeb ? TextDecoration.underline : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () => _copy(context),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Tooltip(
                message: 'Copy',
                child: Icon(Icons.copy_rounded, size: 14, color: color),
              ),
            ),
          ),
          if (_isWeb) ...[
            const SizedBox(width: 2),
            InkWell(
              onTap: _open,
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
          if (_isLocal) ...[
            const SizedBox(width: 2),
            Tooltip(
              message: 'Copy path, paste in File Explorer',
              child: Icon(Icons.info_outline_rounded,
                  size: 13, color: color.withOpacity(0.6)),
            ),
          ],
        ],
      ),
    );
  }
}
