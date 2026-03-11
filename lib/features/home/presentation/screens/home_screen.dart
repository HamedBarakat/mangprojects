import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_model.dart';
import '../controllers/home_providers.dart';
import '../../../../features/office/presentation/controllers/office_providers.dart';
import 'package:mang_projects/features/employees/presentation/screens/employees_screen.dart';
import '../../../projects/presentation/screens/projects_screen.dart';
import '../../../projects/presentation/controllers/project_providers.dart';
import '../../../projects/presentation/controllers/task_providers.dart';
import '../../../projects/presentation/screens/add_edit_project_screen.dart';
import '../../../projects/data/models/project_model.dart';
import '../../../projects/presentation/widgets/project_card.dart';
import '../../../attendance/presentation/screens/attendance_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../client/presentation/screens/client_screen.dart';
import 'package:mang_projects/features/office/presentation/controllers/office_settings_providers.dart';
import '../../../projects/presentation/screens/project_details_screen.dart';
import '../../../projects/presentation/screens/my_tasks_screen.dart';
import '../../../employees/presentation/screens/add_edit_employee_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) =>
          const Scaffold(body: Center(child: Text('Error loading user data'))),
      data: (UserModel? user) {
        if (user == null)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        return _HomeScaffold(user: user);
      },
    );
  }
}

class _HomeScaffold extends ConsumerStatefulWidget {
  final UserModel user;
  const _HomeScaffold({required this.user});

  @override
  ConsumerState<_HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends ConsumerState<_HomeScaffold> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.user.isAdmin) {
        ref
            .read(officeSettingsRepositoryProvider)
            .initializeSettings(widget.user.officeId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = widget.user;
    final navItems = _getNavItems(user);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withOpacity(0.6),
              ),
            ),
            Text(
              user.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getRoleColor(user.role, cs).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.roleLabel,
              style: TextStyle(
                color: _getRoleColor(user.role, cs),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              await ref.read(localStorageProvider).clearAll();
            },
          ),
        ],
      ),
      body: _getBody(user, _selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: navItems,
      ),
    );
  }

  List<NavigationDestination> _getNavItems(UserModel user) {
    // ── Client: Projects + Settings فقط ──────────────────────────────────────
    if (user.isClient) {
      return const [
        NavigationDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder_rounded),
          label: 'My Projects',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: 'Settings',
        ),
      ];
    }

    // ── Administration: Attendance + Settings فقط ─────────────────────────────
    if (user.isAdministration) {
      return const [
        NavigationDestination(
          icon: Icon(Icons.access_time_outlined),
          selectedIcon: Icon(Icons.access_time_filled_rounded),
          label: 'Attendance',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: 'Settings',
        ),
      ];
    }

    final items = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.business_center_outlined),
        selectedIcon: Icon(Icons.business_center_rounded),
        label: 'Projects',
      ),
    ];

    // Admin
    if (user.isAdmin) {
      items.add(const NavigationDestination(
        icon: Icon(Icons.people_outline_rounded),
        selectedIcon: Icon(Icons.people_rounded),
        label: 'Employees',
      ));
      items.add(const NavigationDestination(
        icon: Icon(Icons.access_time_outlined),
        selectedIcon: Icon(Icons.access_time_filled_rounded),
        label: 'Attendance',
      ));
      items.add(const NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart_rounded),
        label: 'Reports',
      ));
    }

    // Management: reviewer-level + Attendance + Reports
    if (user.isManagement && !user.isAdmin) {
      items.add(const NavigationDestination(
        icon: Icon(Icons.task_outlined),
        selectedIcon: Icon(Icons.task_rounded),
        label: 'My Tasks',
      ));
      items.add(const NavigationDestination(
        icon: Icon(Icons.access_time_outlined),
        selectedIcon: Icon(Icons.access_time_filled_rounded),
        label: 'Attendance',
      ));
      items.add(const NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart_rounded),
        label: 'Reports',
      ));
    }

    // Team Leader / Engineer
    if (user.isTeamLeader || user.isEngineer) {
      items.add(const NavigationDestination(
        icon: Icon(Icons.task_outlined),
        selectedIcon: Icon(Icons.task_rounded),
        label: 'My Tasks',
      ));
      items.add(const NavigationDestination(
        icon: Icon(Icons.access_time_outlined),
        selectedIcon: Icon(Icons.access_time_filled_rounded),
        label: 'Attendance',
      ));
    }

    // Reviewer
    if (user.isReviewer) {
      items.add(const NavigationDestination(
        icon: Icon(Icons.task_outlined),
        selectedIcon: Icon(Icons.task_rounded),
        label: 'My Tasks',
      ));
    }

    items.add(const NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings_rounded),
      label: 'Settings',
    ));

    return items;
  }

  Widget _getBody(UserModel user, int index) {
    // ── Client: MyProjects + Settings ────────────────────────────────────────
    if (user.isClient) {
      if (index == 0) return const ClientScreen();
      return const SettingsScreen();
    }

    // ── Administration: Attendance فقط ───────────────────────────────────────
    if (user.isAdministration) {
      if (index == 0) return const AttendanceScreen();
      return const SettingsScreen();
    }

    if (index == 0) return _DashboardTab(user: user);
    if (index == 1) return const ProjectsScreen();

    // Admin: Home/Projects/Employees/Attendance/Reports/Settings
    if (user.isAdmin) {
      if (index == 2) return const EmployeesScreen();
      if (index == 3) return const AttendanceScreen();
      if (index == 4) return const ReportsScreen();
      return const SettingsScreen();
    }

    // Management: Home/Projects/MyTasks/Attendance/Reports/Settings
    if (user.isManagement) {
      if (index == 2) return const MyTasksScreen();
      if (index == 3) return const AttendanceScreen();
      if (index == 4) return const ReportsScreen();
      return const SettingsScreen();
    }

    // Team Leader / Engineer
    if (user.isTeamLeader || user.isEngineer) {
      if (index == 2) return const MyTasksScreen();
      if (index == 3) return const AttendanceScreen();
      return const SettingsScreen();
    }

    // Reviewer
    if (user.isReviewer) {
      if (index == 2) return const MyTasksScreen();
      return const SettingsScreen();
    }

    return const SettingsScreen();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon 👋';
    return 'Good Evening 👋';
  }

  Color _getRoleColor(String role, ColorScheme cs) {
    switch (role) {
      case 'admin':          return Colors.deepPurple;
      case 'engineer':       return cs.primary;
      case 'team_leader':    return Colors.teal;
      case 'reviewer':       return Colors.indigo;
      case 'management':     return Colors.brown;
      case 'administration': return Colors.blueGrey;
      case 'client':         return Colors.orange;
      default:               return cs.primary;
    }
  }
}

// ── Dashboard Tab ─────────────────────────────────────────────────────────────

class _DashboardTab extends ConsumerWidget {
  final UserModel user;
  const _DashboardTab({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final employeesAsync = ref.watch(
      employeesCountProvider(user.officeId),
    );
    final activeProjectsCount = ref.watch(activeProjectsCountProvider);
    final projectsAsync = ref.watch(projectsProvider);

    final pendingTasksValue = _buildPendingTasksValue(ref);

    final recentProjects = projectsAsync.when(
      data: (list) => list.take(3).toList(),
      loading: () => <ProjectModel>[],
      error: (_, __) => <ProjectModel>[],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OfficeCard(user: user),
          const SizedBox(height: 24),

          Text(
            'Overview',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.business_center_rounded,
                      label: 'Active Projects',
                      value: projectsAsync.isLoading
                          ? '...'
                          : activeProjectsCount.toString(),
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Management & Reviewer: show pending review tasks
                  if (!user.isAdministration)
                    Expanded(
                      child: _StatCard(
                        icon: Icons.task_alt_rounded,
                        label: _pendingTasksLabel(),
                        value: pendingTasksValue,
                        color: Colors.orange,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (user.isAdmin)
                    Expanded(
                      child: _StatCard(
                        icon: Icons.people_rounded,
                        label: 'Employees',
                        value: employeesAsync.when(
                          data: (c) => c.toString(),
                          loading: () => '...',
                          error: (_, __) => '—',
                        ),
                        color: Colors.deepPurple,
                      ),
                    ),
                  if (user.isAdmin) const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle_rounded,
                      label: 'Completed',
                      value: projectsAsync.when(
                        data: (list) => list
                            .where((p) => p.status == 'completed')
                            .length
                            .toString(),
                        loading: () => '...',
                        error: (_, __) => '—',
                      ),
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          if (user.isAdmin) ...[
            Text(
              'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.add_business_rounded,
                    label: 'New Project',
                    color: cs.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddEditProjectScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.person_add_rounded,
                    label: 'Add Employee',
                    color: Colors.deepPurple,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddEditEmployeeScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Projects',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (recentProjects.isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProjectsScreen()),
                  ),
                  child: const Text('View all'),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (projectsAsync.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (recentProjects.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.business_center_outlined,
                    size: 48,
                    color: cs.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No projects yet',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                  ),
                  if (user.isAdmin) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddEditProjectScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add First Project'),
                    ),
                  ],
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentProjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => ProjectCard(
                project: recentProjects[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProjectDetailsScreen(project: recentProjects[i]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _pendingTasksLabel() {
    if (user.isReviewer || user.isManagement) return 'Awaiting Review';
    return 'Pending Tasks';
  }

  String _buildPendingTasksValue(WidgetRef ref) {
    // Reviewer & Management: tasks under_review
    if (user.isReviewer || user.isManagement) {
      final async = ref.watch(tasksForReviewProvider);
      return async.when(
        data: (tasks) => tasks.length.toString(),
        loading: () => '...',
        error: (_, __) => '—',
      );
    }

    if (user.isTeamLeader) {
      final async = ref.watch(teamTasksProvider);
      return async.when(
        data: (tasks) => tasks
            .where(
              (t) => t.status == 'not_started' || t.status == 'in_progress',
            )
            .length
            .toString(),
        loading: () => '...',
        error: (_, __) => '—',
      );
    }

    if (user.isEngineer) {
      final async = ref.watch(myTasksProvider);
      return async.when(
        data: (tasks) => tasks
            .where(
              (t) => t.status == 'not_started' || t.status == 'in_progress',
            )
            .length
            .toString(),
        loading: () => '...',
        error: (_, __) => '—',
      );
    }

    final projectsAsync = ref.watch(projectsProvider);
    return projectsAsync.when(
      data: (_) => '—',
      loading: () => '...',
      error: (_, __) => '—',
    );
  }
}

// ── Office Card ───────────────────────────────────────────────────────────────

class _OfficeCard extends ConsumerWidget {
  final UserModel user;
  const _OfficeCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    // ✅ قرأ الـ custom job titles من الـ office settings
    final customTitles = ref.watch(officeSettingsProvider).valueOrNull
        ?.effectiveJobTitles;
    final titleLabel = user.jobTitleLabelFrom(customTitles);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.domain_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.watch(selectedOfficeProvider)?.name ?? user.officeId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  titleLabel,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Action Button ───────────────────────────────────────────────────────

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
