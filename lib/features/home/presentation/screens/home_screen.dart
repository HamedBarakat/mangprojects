import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_model.dart';
import '../controllers/home_providers.dart';
import '../../../../features/office/presentation/controllers/office_providers.dart';
import 'package:mang_projects/features/employees/presentation/screens/employees_screen.dart';
import '../../../projects/presentation/screens/projects_screen.dart';
import '../../../projects/presentation/screens/project_details_screen.dart';
import '../../../projects/presentation/controllers/project_providers.dart';
import '../../../projects/presentation/controllers/task_providers.dart';
import '../../../projects/presentation/screens/add_edit_project_screen.dart';
import '../../../projects/data/models/project_model.dart';
import '../../../projects/presentation/widgets/project_card.dart';
import '../../../attendance/presentation/screens/attendance_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../client/presentation/screens/client_screen.dart';
import '../../../client/presentation/screens/clients_screen.dart';
import 'package:mang_projects/features/office/presentation/controllers/office_settings_providers.dart';
import '../../../projects/presentation/screens/my_tasks_screen.dart';
import '../../../projects/presentation/screens/dc_tasks_screen.dart';
import '../../../employees/presentation/screens/add_edit_employee_screen.dart';
import '../../../employees/presentation/controllers/employee_providers.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../notifications/presentation/controllers/notification_providers.dart';
import '../../../../core/theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.slate900,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.cyan500),
        ),
      ),
      error: (_, _) => const Scaffold(
        backgroundColor: AppColors.slate900,
        body: Center(child: Text('Error loading user data')),
      ),
      data: (UserModel? user) {
        if (user == null) {
          return const Scaffold(
            backgroundColor: AppColors.slate900,
            body: Center(child: CircularProgressIndicator(color: AppColors.cyan500)),
          );
        }
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
    final user = widget.user;
    final navItems = _getNavItems(user);

    return Scaffold(
      backgroundColor: AppColors.slate900,
      appBar: AppBar(
        backgroundColor: AppColors.slate850,
        elevation: 0,
        title: Row(
          children: [
            // Cyan dot accent
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 10),
              decoration: const BoxDecoration(
                color: AppColors.cyan500,
                shape: BoxShape.circle,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: const TextStyle(
                    color: AppColors.slate400,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  user.name,
                  style: const TextStyle(
                    color: AppColors.slate100,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Role badge
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppStatusColors.forRole(user.role).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppStatusColors.forRole(user.role).withOpacity(0.3),
              ),
            ),
            child: Text(
              user.roleLabel,
              style: TextStyle(
                color: AppStatusColors.forRole(user.role),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!user.isClient && !user.isAdministration)
            _HomeNotificationBell(),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            color: AppColors.slate400,
            tooltip: 'Logout',
            onPressed: () async {
              await _performLogout(ref);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.slate700),
        ),
      ),
      body: _getBody(user, _selectedIndex),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.slate700, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          destinations: navItems,
        ),
      ),
    );
  }

  List<NavigationDestination> _getNavItems(UserModel user) {
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

    if (user.isAdmin) {
      items.addAll([
        const NavigationDestination(
          icon: Icon(Icons.people_outline_rounded),
          selectedIcon: Icon(Icons.people_rounded),
          label: 'Employees',
        ),
        const NavigationDestination(
          icon: Icon(Icons.business_outlined),
          selectedIcon: Icon(Icons.business_rounded),
          label: 'Clients',
        ),
        const NavigationDestination(
          icon: Icon(Icons.access_time_outlined),
          selectedIcon: Icon(Icons.access_time_filled_rounded),
          label: 'Attendance',
        ),
        const NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart_rounded),
          label: 'Reports',
        ),
      ]);
    }

    if (user.isManagement && !user.isAdmin) {
      items.addAll([
        const NavigationDestination(
          icon: Icon(Icons.task_outlined),
          selectedIcon: Icon(Icons.task_rounded),
          label: 'My Tasks',
        ),
        const NavigationDestination(
          icon: Icon(Icons.access_time_outlined),
          selectedIcon: Icon(Icons.access_time_filled_rounded),
          label: 'Attendance',
        ),
        const NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart_rounded),
          label: 'Reports',
        ),
      ]);
    }

    if (user.isTeamLeader || user.isEngineer) {
      items.addAll([
        const NavigationDestination(
          icon: Icon(Icons.task_outlined),
          selectedIcon: Icon(Icons.task_rounded),
          label: 'My Tasks',
        ),
        const NavigationDestination(
          icon: Icon(Icons.access_time_outlined),
          selectedIcon: Icon(Icons.access_time_filled_rounded),
          label: 'Attendance',
        ),
      ]);
    }

    if (user.isReviewer) {
      items.add(
        const NavigationDestination(
          icon: Icon(Icons.task_outlined),
          selectedIcon: Icon(Icons.task_rounded),
          label: 'My Tasks',
        ),
      );
    }

    if (user.isDC) {
      items.addAll([
        const NavigationDestination(
          icon: Icon(Icons.task_outlined),
          selectedIcon: Icon(Icons.task_rounded),
          label: 'My Tasks',
        ),
        const NavigationDestination(
          icon: Icon(Icons.access_time_outlined),
          selectedIcon: Icon(Icons.access_time_filled_rounded),
          label: 'Attendance',
        ),
      ]);
    }

    items.add(
      const NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings_rounded),
        label: 'Settings',
      ),
    );

    return items;
  }

  Widget _getBody(UserModel user, int index) {
    if (user.isClient) {
      if (index == 0) return const ClientScreen();
      return const SettingsScreen();
    }

    if (user.isAdministration) {
      if (index == 0) return const AttendanceScreen();
      return const SettingsScreen();
    }

    if (index == 0) return _DashboardTab(user: user);
    if (index == 1) return const ProjectsScreen();

    if (user.isAdmin) {
      if (index == 2) return const EmployeesScreen();
      if (index == 3) return const ClientsScreen();
      if (index == 4) return const AttendanceScreen();
      if (index == 5) return const ReportsScreen();
      return const SettingsScreen();
    }

    if (user.isManagement) {
      if (index == 2) return const MyTasksScreen();
      if (index == 3) return const AttendanceScreen();
      if (index == 4) return const ReportsScreen();
      return const SettingsScreen();
    }

    if (user.isTeamLeader || user.isEngineer) {
      if (index == 2) return const MyTasksScreen();
      if (index == 3) return const AttendanceScreen();
      return const SettingsScreen();
    }

    if (user.isReviewer) {
      if (index == 2) return const MyTasksScreen();
      return const SettingsScreen();
    }

    if (user.isDC) {
      if (index == 2) return const DCTasksScreen();
      if (index == 3) return const AttendanceScreen();
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
}

  // ── Logout: clear all caches and reset providers ─────────────────────────
  Future<void> _performLogout(WidgetRef ref) async {
    // Invalidate ALL providers BEFORE sign-out so all Firestore streams
    // are cancelled and recreated fresh when the next user logs in.
    // projectTasksProvider and projectTaskStatsProvider are family providers
    // that hold per-project streams — invalidating by type clears all instances.
    // Invalidate repositories first — forces fresh Firestore instance
    ref.invalidate(taskRepositoryProvider);
    ref.invalidate(projectRepositoryProvider);
    // Then invalidate all derived providers
    ref.invalidate(currentUserProvider);
    ref.invalidate(projectsProvider);
    ref.invalidate(singleProjectProvider);
    ref.invalidate(allVisibleTasksProvider);
    ref.invalidate(projectTasksProvider);
    ref.invalidate(projectTaskStatsProvider);
    ref.invalidate(teamLeaderReviewTasksProvider);
    ref.invalidate(qcReviewTasksProvider);
    ref.invalidate(unreadNotificationsCountProvider);
    ref.invalidate(employeesProvider);

    // Clear selected office from local storage
    await ref.read(selectedOfficeProvider.notifier).clearOffice();

    // Sign out — authStateChanges stream fires → AuthWrapper shows LoginScreen
    await FirebaseAuth.instance.signOut();
  }


// ── Dashboard Tab ─────────────────────────────────────────────────────────────

class _DashboardTab extends ConsumerWidget {
  final UserModel user;
  const _DashboardTab({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesCountProvider(user.officeId));
    final activeProjectsCount = ref.watch(activeProjectsCountProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final pendingTasksValue = _buildPendingTasksValue(ref);

    final recentProjects = projectsAsync.when(
      data: (list) => list.take(3).toList(),
      loading: () => <ProjectModel>[],
      error: (_, _) => <ProjectModel>[],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Office Hero Card ─────────────────────────────────────────────
          _OfficeCard(user: user),
          const SizedBox(height: 24),

          // ── Section Header ───────────────────────────────────────────────
          _SectionHeader(title: 'Overview'),
          const SizedBox(height: 12),

          // ── Stat Cards ───────────────────────────────────────────────────
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.business_center_rounded,
                      label: 'Active Projects',
                      value: projectsAsync.isLoading ? '...' : activeProjectsCount.toString(),
                      color: AppColors.cyan500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!user.isAdministration)
                    Expanded(
                      child: _StatCard(
                        icon: Icons.task_alt_rounded,
                        label: _pendingTasksLabel(),
                        value: pendingTasksValue,
                        color: AppColors.warning,
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
                          error: (_, _) => '—',
                        ),
                        color: Colors.purple,
                      ),
                    ),
                  if (user.isAdmin) const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle_rounded,
                      label: 'Completed',
                      value: projectsAsync.when(
                        data: (list) => list.where((p) => p.status == 'completed').length.toString(),
                        loading: () => '...',
                        error: (_, _) => '—',
                      ),
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (user.isAdmin) ...[
            const SizedBox(height: 24),
            _SectionHeader(title: 'Quick Actions'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.add_business_rounded,
                    label: 'New Project',
                    color: AppColors.cyan500,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddEditProjectScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.person_add_rounded,
                    label: 'Add Employee',
                    color: Colors.purple,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddEditEmployeeScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // ── Recent Projects ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionHeader(title: 'Recent Projects'),
              if (recentProjects.isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProjectsScreen()),
                  ),
                  child: const Text('View all', style: TextStyle(color: AppColors.cyan400, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (projectsAsync.isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.cyan500))
          else if (recentProjects.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: AppDecorations.card(),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.slate700,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.business_center_outlined,
                      size: 36,
                      color: AppColors.slate500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No projects yet',
                    style: TextStyle(color: AppColors.slate400, fontSize: 14),
                  ),
                  if (user.isAdmin) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddEditProjectScreen()),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
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
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => ProjectCard(
                project: recentProjects[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProjectDetailsScreen(project: recentProjects[i]),
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
    if (user.isReviewer || user.isManagement) {
      final qcTasksAsync = ref.watch(qcTasksProvider);
      return qcTasksAsync.when(
        data: (tasks) => tasks.where((t) => t.status == 'qc_review' || t.status == 'client_review').length.toString(),
        loading: () => '...',
        error: (_, _) => '0',
      );
    }

    if (user.isTeamLeader) {
      final teamLeaderTasksAsync = ref.watch(teamLeaderTasksProvider);
      return teamLeaderTasksAsync.when(
        data: (tasks) => tasks.where((t) => t.status == 'team_leader_review').length.toString(),
        loading: () => '...',
        error: (_, _) => '0',
      );
    }

    final myTasksAsync = ref.watch(myTasksProvider);
    return myTasksAsync.when(
      data: (tasks) => tasks.where((t) => t.status == 'not_started' || t.status == 'in_progress').length.toString(),
      loading: () => '...',
      error: (_, _) => '0',
    );
  }
}

// ── Office Card ───────────────────────────────────────────────────────────────

class _OfficeCard extends ConsumerWidget {
  final UserModel user;
  const _OfficeCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customTitles = ref.watch(officeSettingsProvider).valueOrNull?.effectiveJobTitles;
    final titleLabel = user.jobTitleLabelFrom(customTitles);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.heroBanner(),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Icon(Icons.domain_rounded, color: Colors.white, size: 26),
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
                  style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
                ),
              ],
            ),
          ),
          // Decorative cyan glow dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.cyan400,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.cyan400, blurRadius: 8, spreadRadius: 2)],
            ),
          ),
        ],
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
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.cyan500,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.slate100,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.slate800,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate700),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.slate400, fontSize: 11),
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notification Bell ─────────────────────────────────────────────────────────

class _HomeNotificationBell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unreadNotificationsCountProvider);
    final count = countAsync.value ?? 0;

    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            count > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded,
            color: count > 0 ? AppColors.cyan400 : AppColors.slate400,
            size: 22,
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
