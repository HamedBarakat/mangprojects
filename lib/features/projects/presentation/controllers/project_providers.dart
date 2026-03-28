import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/project_repository.dart';
import '../../../../features/home/presentation/controllers/home_providers.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository();
});

// ── Watch all projects ────────────────────────────────────────────────────────
final projectsProvider = StreamProvider<List<ProjectModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(projectRepositoryProvider).watchProjects(user.officeId);
    },
    loading: () => const Stream.empty(),
    error: (_, _) => const Stream.empty(),
  );
});

// ── Watch single project real-time ────────────────────────────────────────────
final singleProjectProvider = StreamProvider.family<ProjectModel?, String>((
  ref,
  projectId,
) {
  return ref.watch(projectRepositoryProvider).watchSingleProject(projectId);
});

// ── Filter state ──────────────────────────────────────────────────────────────
final projectStatusFilterProvider = StateProvider<String>((ref) => 'all');
final projectTypeFilterProvider = StateProvider<String>((ref) => 'all');

// ── Filtered ALL projects (Admin / Reviewer يشوفوا الكل) ─────────────────────
final filteredProjectsProvider = Provider<List<ProjectModel>>((ref) {
  final projectsAsync = ref.watch(projectsProvider);
  final statusFilter = ref.watch(projectStatusFilterProvider);
  final typeFilter = ref.watch(projectTypeFilterProvider);

  return projectsAsync.when(
    data: (projects) {
      var filtered = projects;
      if (statusFilter != 'all') {
        filtered = filtered.where((p) => p.status == statusFilter).toList();
      }
      if (typeFilter != 'all') {
        filtered = filtered.where((p) => p.type == typeFilter).toList();
      }
      return filtered;
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

// ── Filtered MY projects (Team Leader: فقط المشاريع اللي هو teamLeader عليها) ─
final filteredMyProjectsProvider = Provider<List<ProjectModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  final projectsAsync = ref.watch(projectsProvider);
  final statusFilter = ref.watch(projectStatusFilterProvider);
  final typeFilter = ref.watch(projectTypeFilterProvider);

  return projectsAsync.when(
    data: (projects) {
      var filtered = projects;

      // Team Leader يشوف مشاريعه هو فقط
      if (user != null && user.isTeamLeader) {
        filtered = filtered.where((p) => p.teamLeaderId == user.uid).toList();
      }

      if (statusFilter != 'all') {
        filtered = filtered.where((p) => p.status == statusFilter).toList();
      }
      if (typeFilter != 'all') {
        filtered = filtered.where((p) => p.type == typeFilter).toList();
      }
      return filtered;
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

// ── Watch tasks for a project ─────────────────────────────────────────────────
final tasksProvider = StreamProvider.family<List<TaskModel>, String>((
  ref,
  projectId,
) {
  return ref.watch(projectRepositoryProvider).watchTasks(projectId);
});

// ── Project code generator ────────────────────────────────────────────────────
final projectCodeProvider = FutureProvider<String>((ref) async {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) async {
      if (user == null) return 'PRJ001';
      return await ref
          .watch(projectRepositoryProvider)
          .generateProjectCode(user.officeId);
    },
    loading: () async => 'PRJ001',
    error: (_, _) async => 'PRJ001',
  );
});

// ── Active projects count ─────────────────────────────────────────────────────
final activeProjectsCountProvider = Provider<int>((ref) {
  final projectsAsync = ref.watch(projectsProvider);
  return projectsAsync.when(
    data: (projects) => projects.where((p) => p.status == 'active').length,
    loading: () => 0,
    error: (_, _) => 0,
  );
});

// ── Projects by client ────────────────────────────────────────────────────────
final projectsByClientProvider = Provider.family<List<ProjectModel>, String>((
  ref,
  clientId,
) {
  final projectsAsync = ref.watch(projectsProvider);
  return projectsAsync.when(
    data: (projects) => projects.where((p) => p.clientId == clientId).toList(),
    loading: () => [],
    error: (_, _) => [],
  );
});
