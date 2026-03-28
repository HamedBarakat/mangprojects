import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/project_providers.dart';
import '../widgets/project_card.dart';
import 'add_edit_project_screen.dart';
import 'project_details_screen.dart';
import '../../../../features/home/presentation/controllers/home_providers.dart';
import '../../../../features/office/presentation/controllers/office_settings_providers.dart';
import '../../../../core/theme/app_theme.dart';

/// ProjectsScreen — ConsumerWidget (no TabController at top level).
/// The TabController lives inside _TeamLeaderProjectsView, which has its own
/// lifecycle with SingleTickerProviderStateMixin — completely safe.
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final isAdmin = user?.isAdmin ?? false;
    final isTeamLeader = user?.isTeamLeader ?? false;

    return Scaffold(
      backgroundColor: AppColors.slate900,
      appBar: AppBar(
        backgroundColor: AppColors.slate850,
        title: const Text('Projects'),
        actions: [
          if (isAdmin)
            Container(
              margin: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.cyan500.withValues(alpha: 0.12),
                  foregroundColor: AppColors.cyan400,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddEditProjectScreen(),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: isTeamLeader
          ? const _TeamLeaderProjectsView()
          : const _ProjectsList(showOnlyMine: false),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditProjectScreen()),
              ),
              backgroundColor: AppColors.cyan500,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Project',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}

// ── Team Leader Tabbed View ───────────────────────────────────────────────────
// Separate StatefulWidget: owns ONE TabController for its entire lifetime.
// No recreation inside build() — that was the crash cause.

class _TeamLeaderProjectsView extends StatefulWidget {
  const _TeamLeaderProjectsView();

  @override
  State<_TeamLeaderProjectsView> createState() =>
      _TeamLeaderProjectsViewState();
}

class _TeamLeaderProjectsViewState extends State<_TeamLeaderProjectsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.slate850,
          child: TabBar(
            controller: _tab,
            tabs: const [
              Tab(text: 'My Projects'),
              Tab(text: 'All Projects'),
            ],
          ),
        ),
        Container(height: 1, color: AppColors.slate700),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              _ProjectsList(showOnlyMine: true),
              _ProjectsList(showOnlyMine: false),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Projects List ─────────────────────────────────────────────────────────────

class _ProjectsList extends ConsumerWidget {
  final bool showOnlyMine;
  const _ProjectsList({required this.showOnlyMine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    final statusFilter = ref.watch(projectStatusFilterProvider);

    final projects = showOnlyMine
        ? ref.watch(filteredMyProjectsProvider)
        : ref.watch(filteredProjectsProvider);

    return Column(
      children: [
        // ── Filter Bar ────────────────────────────────────────────────
        Container(
          color: AppColors.slate850,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: statusFilter == 'all',
                      color: AppColors.slate300,
                      onTap: () => ref
                          .read(projectStatusFilterProvider.notifier)
                          .state = 'all',
                    ),
                    _FilterChip(
                      label: 'Active',
                      selected: statusFilter == 'active',
                      color: AppColors.success,
                      onTap: () => ref
                          .read(projectStatusFilterProvider.notifier)
                          .state = 'active',
                    ),
                    _FilterChip(
                      label: 'Completed',
                      selected: statusFilter == 'completed',
                      color: AppColors.cyan500,
                      onTap: () => ref
                          .read(projectStatusFilterProvider.notifier)
                          .state = 'completed',
                    ),
                    _FilterChip(
                      label: 'Suspended',
                      selected: statusFilter == 'suspended',
                      color: AppColors.warning,
                      onTap: () => ref
                          .read(projectStatusFilterProvider.notifier)
                          .state = 'suspended',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, _) {
                  final projectTypes = ref.watch(projectTypesProvider);
                  final typeFilter = ref.watch(projectTypeFilterProvider);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All Types',
                          selected: typeFilter == 'all',
                          color: AppColors.slate300,
                          onTap: () => ref
                              .read(projectTypeFilterProvider.notifier)
                              .state = 'all',
                        ),
                        ...projectTypes.map(
                          (type) => _FilterChip(
                            label: type,
                            selected: typeFilter == type,
                            color: AppColors.cyan600,
                            onTap: () => ref
                                .read(projectTypeFilterProvider.notifier)
                                .state = type,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        Container(height: 1, color: AppColors.slate700),

        // ── List ──────────────────────────────────────────────────────
        Expanded(
          child: projectsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.cyan500),
            ),
            error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: AppColors.error)),
            ),
            data: (_) {
              if (projects.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.slate800,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.slate700),
                        ),
                        child: const Icon(Icons.business_center_outlined,
                            size: 44, color: AppColors.slate500),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        showOnlyMine
                            ? 'No projects assigned to you'
                            : 'No projects found',
                        style: const TextStyle(
                            color: AppColors.slate400,
                            fontSize: 15,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      const Text('Try adjusting your filters',
                          style: TextStyle(
                              color: AppColors.slate500, fontSize: 12)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final project = projects[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ProjectCard(
                      project: project,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProjectDetailsScreen(project: project),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : AppColors.slate800,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.6)
                  : AppColors.slate600,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : AppColors.slate400,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
