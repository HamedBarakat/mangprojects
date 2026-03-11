import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/project_providers.dart';
import '../widgets/project_card.dart';
import 'add_edit_project_screen.dart';
import 'project_details_screen.dart';
import '../../../../features/home/presentation/controllers/home_providers.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final projects = ref.watch(filteredProjectsProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final statusFilter = ref.watch(projectStatusFilterProvider);
    final typeFilter = ref.watch(projectTypeFilterProvider);
    final userAsync = ref.watch(currentUserProvider);

    final isAdmin = userAsync.value?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: const Text(
          'Projects',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditProjectScreen()),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Filters ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                // Status filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: statusFilter == 'all',
                        onTap: () =>
                            ref
                                    .read(projectStatusFilterProvider.notifier)
                                    .state =
                                'all',
                      ),
                      _FilterChip(
                        label: 'Active',
                        selected: statusFilter == 'active',
                        color: Colors.green,
                        onTap: () =>
                            ref
                                    .read(projectStatusFilterProvider.notifier)
                                    .state =
                                'active',
                      ),
                      _FilterChip(
                        label: 'Completed',
                        selected: statusFilter == 'completed',
                        color: Colors.blue,
                        onTap: () =>
                            ref
                                    .read(projectStatusFilterProvider.notifier)
                                    .state =
                                'completed',
                      ),
                      _FilterChip(
                        label: 'Suspended',
                        selected: statusFilter == 'suspended',
                        color: Colors.orange,
                        onTap: () =>
                            ref
                                    .read(projectStatusFilterProvider.notifier)
                                    .state =
                                'suspended',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Type filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All Types',
                        selected: typeFilter == 'all',
                        onTap: () =>
                            ref.read(projectTypeFilterProvider.notifier).state =
                                'all',
                      ),
                      _FilterChip(
                        label: 'Design',
                        selected: typeFilter == 'design',
                        onTap: () =>
                            ref.read(projectTypeFilterProvider.notifier).state =
                                'design',
                      ),
                      _FilterChip(
                        label: 'Exec. Drawings',
                        selected: typeFilter == 'executive_drawings',
                        color: Colors.blue.shade700,
                        onTap: () =>
                            ref.read(projectTypeFilterProvider.notifier).state =
                                'executive_drawings',
                      ),
                      _FilterChip(
                        label: 'Supervision',
                        selected: typeFilter == 'supervision',
                        color: Colors.orange.shade700,
                        onTap: () =>
                            ref.read(projectTypeFilterProvider.notifier).state =
                                'supervision',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── List ─────────────────────────────────────────────────────
          Expanded(
            child: projectsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (_) {
                if (projects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.business_center_outlined,
                          size: 64,
                          color: cs.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No projects found',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
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
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditProjectScreen()),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Project'),
            )
          : null,
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? c : c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : c,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
