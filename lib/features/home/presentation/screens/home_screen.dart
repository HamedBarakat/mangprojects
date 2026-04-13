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
import '../../../projects/presentation/screens/management_dashboard_screen.dart';
import '../../../employees/presentation/screens/add_edit_employee_screen.dart';
import '../../../employees/presentation/controllers/employee_providers.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../notifications/presentation/controllers/notification_providers.dart';
import '../../../leaves/presentation/screens/leaves_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/fcm_service.dart';
import '../widgets/dashboard_sections.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const Scaffold(
        body: Center(child: Text('Error loading user data')),
      ),
      data: (UserModel? user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
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
      // Initialise FCM: request permission, save token, listen for messages
      FcmService().init(widget.user.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final navItems = _getNavItems(user);

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            // Cyan dot accent
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: TextStyle(
                    color: cs.subtleText,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  user.name,
                  style: TextStyle(
                    color: cs.headText,
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
            color: cs.subtleText,
            tooltip: 'Logout',
            onPressed: () async {
              await _performLogout();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: cs.border),
        ),
      ),
      body: _getBody(user, _selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cs.border, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          destinations: navItems,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // _getNavItems — order here MUST match _getBody index mapping exactly.
  // isReviewer is checked before isAdmin: a reviewer can have adminFlag=true
  // which would make isAdmin true and route them to the wrong nav.
  // ─────────────────────────────────────────────────────────────────────────
  List<NavigationDestination> _getNavItems(UserModel user) {

    // ── CLIENT ───────────────────────────────────────────────────────────────
    // 0=MyProjects  1=Settings
    if (user.isClient) {
      return const [
        NavigationDestination(icon: Icon(Icons.folder_outlined),       selectedIcon: Icon(Icons.folder_rounded),              label: 'My Projects'),
        NavigationDestination(icon: Icon(Icons.settings_outlined),     selectedIcon: Icon(Icons.settings_rounded),            label: 'Settings'),
      ];
    }

    // ── ADMINISTRATION ────────────────────────────────────────────────────────
    // 0=Attendance  1=Leaves  2=Settings
    if (user.isAdministration) {
      return const [
        NavigationDestination(icon: Icon(Icons.access_time_outlined),  selectedIcon: Icon(Icons.access_time_filled_rounded),  label: 'Attendance'),
        NavigationDestination(icon: Icon(Icons.event_note_outlined),   selectedIcon: Icon(Icons.event_note_rounded),          label: 'Leaves'),
        NavigationDestination(icon: Icon(Icons.settings_outlined),     selectedIcon: Icon(Icons.settings_rounded),            label: 'Settings'),
      ];
    }

    // ── REVIEWER ──────────────────────────────────────────────────────────────
    // 0=Home  1=Projects  2=MyTasks  3=Attendance  4=Leaves  5=Reports  6=Settings
    if (user.isReviewer) {
      return const [
        NavigationDestination(icon: Icon(Icons.home_outlined),              selectedIcon: Icon(Icons.home_rounded),                label: 'Home'),
        NavigationDestination(icon: Icon(Icons.business_center_outlined),   selectedIcon: Icon(Icons.business_center_rounded),     label: 'Projects'),
        NavigationDestination(icon: Icon(Icons.task_outlined),              selectedIcon: Icon(Icons.task_rounded),                label: 'My Tasks'),
        NavigationDestination(icon: Icon(Icons.access_time_outlined),       selectedIcon: Icon(Icons.access_time_filled_rounded),  label: 'Attendance'),
        NavigationDestination(icon: Icon(Icons.event_note_outlined),        selectedIcon: Icon(Icons.event_note_rounded),          label: 'Leaves'),
        NavigationDestination(icon: Icon(Icons.bar_chart_outlined),         selectedIcon: Icon(Icons.bar_chart_rounded),           label: 'Reports'),
        NavigationDestination(icon: Icon(Icons.settings_outlined),          selectedIcon: Icon(Icons.settings_rounded),            label: 'Settings'),
      ];
    }

    // ── ADMIN ─────────────────────────────────────────────────────────────────
    // 0=Home  1=Projects  2=Employees  3=Clients  4=Attendance
    // 5=Leaves  6=Reports  7=Dashboard  8=Settings
    if (user.isAdmin) {
      return const [
        NavigationDestination(icon: Icon(Icons.home_outlined),              selectedIcon: Icon(Icons.home_rounded),                label: 'Home'),
        NavigationDestination(icon: Icon(Icons.business_center_outlined),   selectedIcon: Icon(Icons.business_center_rounded),     label: 'Projects'),
        NavigationDestination(icon: Icon(Icons.people_outline_rounded),     selectedIcon: Icon(Icons.people_rounded),              label: 'Employees'),
        NavigationDestination(icon: Icon(Icons.business_outlined),          selectedIcon: Icon(Icons.business_rounded),            label: 'Clients'),
        NavigationDestination(icon: Icon(Icons.access_time_outlined),       selectedIcon: Icon(Icons.access_time_filled_rounded),  label: 'Attendance'),
        NavigationDestination(icon: Icon(Icons.event_note_outlined),        selectedIcon: Icon(Icons.event_note_rounded),          label: 'Leaves'),
        NavigationDestination(icon: Icon(Icons.bar_chart_outlined),         selectedIcon: Icon(Icons.bar_chart_rounded),           label: 'Reports'),
        NavigationDestination(icon: Icon(Icons.dashboard_outlined),         selectedIcon: Icon(Icons.dashboard_rounded),           label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.settings_outlined),          selectedIcon: Icon(Icons.settings_rounded),            label: 'Settings'),
      ];
    }

    // ── MANAGEMENT ────────────────────────────────────────────────────────────
    // 0=Home  1=Projects  2=Employees  3=Clients  4=Attendance
    // 5=Leaves  6=Reports  7=Dashboard  8=Settings
    if (user.isManagement) {
      return const [
        NavigationDestination(icon: Icon(Icons.home_outlined),              selectedIcon: Icon(Icons.home_rounded),                label: 'Home'),
        NavigationDestination(icon: Icon(Icons.business_center_outlined),   selectedIcon: Icon(Icons.business_center_rounded),     label: 'Projects'),
        NavigationDestination(icon: Icon(Icons.people_outline_rounded),     selectedIcon: Icon(Icons.people_rounded),              label: 'Employees'),
        NavigationDestination(icon: Icon(Icons.business_outlined),          selectedIcon: Icon(Icons.business_rounded),            label: 'Clients'),
        NavigationDestination(icon: Icon(Icons.access_time_outlined),       selectedIcon: Icon(Icons.access_time_filled_rounded),  label: 'Attendance'),
        NavigationDestination(icon: Icon(Icons.event_note_outlined),        selectedIcon: Icon(Icons.event_note_rounded),          label: 'Leaves'),
        NavigationDestination(icon: Icon(Icons.bar_chart_outlined),         selectedIcon: Icon(Icons.bar_chart_rounded),           label: 'Reports'),
        NavigationDestination(icon: Icon(Icons.dashboard_outlined),         selectedIcon: Icon(Icons.dashboard_rounded),           label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.settings_outlined),          selectedIcon: Icon(Icons.settings_rounded),            label: 'Settings'),
      ];
    }

    // ── TEAM LEADER / ENGINEER ────────────────────────────────────────────────
    // 0=Home  1=Projects  2=MyTasks  3=Attendance  4=Leaves  5=Reports  6=Settings
    if (user.isTeamLeader || user.isEngineer) {
      return const [
        NavigationDestination(icon: Icon(Icons.home_outlined),              selectedIcon: Icon(Icons.home_rounded),                label: 'Home'),
        NavigationDestination(icon: Icon(Icons.business_center_outlined),   selectedIcon: Icon(Icons.business_center_rounded),     label: 'Projects'),
        NavigationDestination(icon: Icon(Icons.task_outlined),              selectedIcon: Icon(Icons.task_rounded),                label: 'My Tasks'),
        NavigationDestination(icon: Icon(Icons.access_time_outlined),       selectedIcon: Icon(Icons.access_time_filled_rounded),  label: 'Attendance'),
        NavigationDestination(icon: Icon(Icons.event_note_outlined),        selectedIcon: Icon(Icons.event_note_rounded),          label: 'Leaves'),
        NavigationDestination(icon: Icon(Icons.bar_chart_outlined),         selectedIcon: Icon(Icons.bar_chart_rounded),           label: 'Reports'),
        NavigationDestination(icon: Icon(Icons.settings_outlined),          selectedIcon: Icon(Icons.settings_rounded),            label: 'Settings'),
      ];
    }

    // ── DC ────────────────────────────────────────────────────────────────────
    // 0=Home  1=Projects  2=MyTasks  3=Attendance  4=Leaves  5=Reports  6=Settings
    if (user.isDC) {
      return const [
        NavigationDestination(icon: Icon(Icons.home_outlined),              selectedIcon: Icon(Icons.home_rounded),                label: 'Home'),
        NavigationDestination(icon: Icon(Icons.business_center_outlined),   selectedIcon: Icon(Icons.business_center_rounded),     label: 'Projects'),
        NavigationDestination(icon: Icon(Icons.task_outlined),              selectedIcon: Icon(Icons.task_rounded),                label: 'My Tasks'),
        NavigationDestination(icon: Icon(Icons.access_time_outlined),       selectedIcon: Icon(Icons.access_time_filled_rounded),  label: 'Attendance'),
        NavigationDestination(icon: Icon(Icons.event_note_outlined),        selectedIcon: Icon(Icons.event_note_rounded),          label: 'Leaves'),
        NavigationDestination(icon: Icon(Icons.bar_chart_outlined),         selectedIcon: Icon(Icons.bar_chart_rounded),           label: 'Reports'),
        NavigationDestination(icon: Icon(Icons.settings_outlined),          selectedIcon: Icon(Icons.settings_rounded),            label: 'Settings'),
      ];
    }

    // Fallback
    return const [
      NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // _getBody — index MUST match _getNavItems order exactly for each role.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _getBody(UserModel user, int index) {

    // ── CLIENT ───────────────────────────────────────────────────────────────
    // 0=MyProjects  1=Settings
    if (user.isClient) {
      switch (index) {
        case 0:  return const ClientScreen();
        default: return const SettingsScreen();
      }
    }

    // ── ADMINISTRATION ────────────────────────────────────────────────────────
    // 0=Attendance  1=Leaves  2=Settings
    if (user.isAdministration) {
      switch (index) {
        case 0:  return const AttendanceScreen();
        case 1:  return const LeavesScreen();
        default: return const SettingsScreen();
      }
    }

    // ── REVIEWER ──────────────────────────────────────────────────────────────
    // 0=Home  1=Projects  2=MyTasks  3=Attendance  4=Leaves  5=Reports  6=Settings
    if (user.isReviewer) {
      switch (index) {
        case 0:  return _DashboardTab(user: user);
        case 1:  return const ProjectsScreen();
        case 2:  return const MyTasksScreen();
        case 3:  return const AttendanceScreen();
        case 4:  return const LeavesScreen();
        case 5:  return const ReportsScreen();
        default: return const SettingsScreen();
      }
    }

    // ── ADMIN ─────────────────────────────────────────────────────────────────
    // 0=Home  1=Projects  2=Employees  3=Clients  4=Attendance
    // 5=Leaves  6=Reports  7=Dashboard  8=Settings
    if (user.isAdmin) {
      switch (index) {
        case 0:  return _DashboardTab(user: user);
        case 1:  return const ProjectsScreen();
        case 2:  return const EmployeesScreen();
        case 3:  return const ClientsScreen();
        case 4:  return const AttendanceScreen();
        case 5:  return const LeavesScreen();
        case 6:  return const ReportsScreen();
        case 7:  return const ManagementDashboardScreen();
        default: return const SettingsScreen();
      }
    }

    // ── MANAGEMENT ────────────────────────────────────────────────────────────
    // 0=Home  1=Projects  2=Employees  3=Clients  4=Attendance
    // 5=Leaves  6=Reports  7=Dashboard  8=Settings
    if (user.isManagement) {
      switch (index) {
        case 0:  return _DashboardTab(user: user);
        case 1:  return const ProjectsScreen();
        case 2:  return const EmployeesScreen();
        case 3:  return const ClientsScreen();
        case 4:  return const AttendanceScreen();
        case 5:  return const LeavesScreen();
        case 6:  return const ReportsScreen();
        case 7:  return const ManagementDashboardScreen();
        default: return const SettingsScreen();
      }
    }

    // ── TEAM LEADER / ENGINEER ────────────────────────────────────────────────
    // 0=Home  1=Projects  2=MyTasks  3=Attendance  4=Leaves  5=Reports  6=Settings
    if (user.isTeamLeader || user.isEngineer) {
      switch (index) {
        case 0:  return _DashboardTab(user: user);
        case 1:  return const ProjectsScreen();
        case 2:  return const MyTasksScreen();
        case 3:  return const AttendanceScreen();
        case 4:  return const LeavesScreen();
        case 5:  return const ReportsScreen();
        default: return const SettingsScreen();
      }
    }

    // ── DC ────────────────────────────────────────────────────────────────────
    // 0=Home  1=Projects  2=DCTasks  3=Attendance  4=Leaves  5=Reports  6=Settings
    if (user.isDC) {
      switch (index) {
        case 0:  return _DashboardTab(user: user);
        case 1:  return const ProjectsScreen();
        case 2:  return const DCTasksScreen();
        case 3:  return const AttendanceScreen();
        case 4:  return const LeavesScreen();
        case 5:  return const ReportsScreen();
        default: return const SettingsScreen();
      }
    }

    return const SettingsScreen();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon 👋';
    return 'Good Evening 👋';
  }

  // ── Logout: clear all caches and reset providers ─────────────────────────
  Future<void> _performLogout() async {
    // Invalidate ALL providers BEFORE sign-out so all Firestore streams
    // are cancelled and recreated fresh when the next user logs in.
    // Invalidate repositories first — forces fresh Firestore instance.
    ref.invalidate(taskRepositoryProvider);
    ref.invalidate(projectRepositoryProvider);
    // Invalidate all derived providers
    ref.invalidate(currentUserProvider);
    ref.invalidate(projectsProvider);
    ref.invalidate(singleProjectProvider);
    ref.invalidate(allVisibleTasksProvider);
    ref.invalidate(projectTasksProvider);
    ref.invalidate(projectTaskStatsProvider);
    ref.invalidate(teamLeaderReviewTasksProvider);
    ref.invalidate(qcReviewTasksProvider);
    ref.invalidate(unreadNotificationsCountProvider);
    ref.invalidate(myNotificationsProvider);
    ref.invalidate(employeesProvider);

    // Clear all local storage and deselect office
    await ref.read(localStorageProvider).clearAll();
    await ref.read(selectedOfficeProvider.notifier).clearOffice();

    // Sign out — authStateChanges stream fires → AuthWrapper shows LoginScreen
    await FirebaseAuth.instance.signOut();
  }
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
                  child: Text('View all', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (projectsAsync.isLoading)
            const Center(child: CircularProgressIndicator())
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
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.business_center_outlined,
                      size: 36,
                      color: Theme.of(context).colorScheme.subtleText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No projects yet',
                    style: TextStyle(color: Theme.of(context).colorScheme.subtleText, fontSize: 14),
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

          // ── Attendance ───────────────────────────────────────────────────
          const SizedBox(height: 24),
          const DashSectionHeader(title: 'Attendance'),
          const SizedBox(height: 12),
          AttendanceDashCard(user: user),

          // ── Leaves ───────────────────────────────────────────────────────
          const SizedBox(height: 24),
          const DashSectionHeader(title: 'Leave'),
          const SizedBox(height: 12),
          LeavesDashSection(user: user),
          ApprovalsDashCard(user: user),

          // ── My Tasks ─────────────────────────────────────────────────────
          if (user.canSeeTasks) ...[
            const SizedBox(height: 24),
            const DashSectionHeader(title: 'My Tasks'),
            const SizedBox(height: 12),
            MyTasksDashSection(user: user),
          ],

          // ── Recent Notifications ─────────────────────────────────────────
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const DashSectionHeader(title: 'Recent Notifications'),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()),
                ),
                child: Text('View all',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          RecentNotificationsDashSection(user: user),
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
      decoration: AppDecorations.heroBannerOf(context),
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
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary, blurRadius: 8, spreadRadius: 2)],
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
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
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
        color: Theme.of(context).colorScheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha:0.12), blurRadius: 8, offset: const Offset(0, 2)),
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
            style: TextStyle(color: Theme.of(context).colorScheme.subtleText, fontSize: 11),
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
            color: count > 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.subtleText,
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
