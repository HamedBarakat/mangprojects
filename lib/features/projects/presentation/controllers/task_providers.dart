import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/home/presentation/controllers/home_providers.dart';
import '../../../../features/attendance/data/attendance_repository.dart';
import '../../data/models/task_model.dart';
import '../../data/models/daily_log_model.dart';
import '../../data/task_repository.dart';

// ── Repository ────────────────────────────────────────────────────────────────
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

// ══════════════════════════════════════════════════════════════════════════════
// TASKS
// ══════════════════════════════════════════════════════════════════════════════

// ── Selected Project ID (for filtering tasks) ─────────────────────────────────
final selectedProjectIdProvider = StateProvider<String?>((ref) => null);

// ── Tasks for selected project ────────────────────────────────────────────────
final projectTasksProvider = StreamProvider.family<List<TaskModel>, String>(
  (ref, projectId) {
    return ref.watch(taskRepositoryProvider).watchProjectTasks(projectId);
  },
);

// ── My tasks (Engineer view) ──────────────────────────────────────────────────
final myTasksProvider = StreamProvider<List<TaskModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(taskRepositoryProvider).watchMyTasks(
            officeId: user.officeId,
            employeeId: user.uid,
          );
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// ── Team tasks (Team Leader view) ─────────────────────────────────────────────
final teamTasksProvider = StreamProvider<List<TaskModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(taskRepositoryProvider).watchTeamTasks(
            officeId: user.officeId,
            teamLeaderId: user.uid,
          );
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// ── Tasks for review (Reviewer view) ─────────────────────────────────────────
final tasksForReviewProvider = StreamProvider<List<TaskModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(taskRepositoryProvider).watchTasksForReview(
            officeId: user.officeId,
            reviewerId: user.uid,
          );
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// ── Task counts by status (for project summary) ────────────────────────────────
final projectTaskStatsProvider =
    Provider.family<Map<String, int>, String>((ref, projectId) {
  final tasksAsync = ref.watch(projectTasksProvider(projectId));
  return tasksAsync.when(
    data: (tasks) => {
      'total':        tasks.length,
      'not_started':  tasks.where((t) => t.status == 'not_started').length,
      'in_progress':  tasks.where((t) => t.status == 'in_progress').length,
      'under_review': tasks.where((t) => t.status == 'under_review').length,
      'completed':    tasks.where((t) => t.status == 'completed').length,
      'rejected':     tasks.where((t) => t.approvalStatus == 'rejected').length,
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

// ── Pending review count (badge for Reviewer) ─────────────────────────────────
final pendingReviewCountProvider = Provider<int>((ref) {
  final tasksAsync = ref.watch(tasksForReviewProvider);
  return tasksAsync.when(
    data: (tasks) => tasks.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// ══════════════════════════════════════════════════════════════════════════════
// DAILY LOGS
// ══════════════════════════════════════════════════════════════════════════════

// ── Today's date key ──────────────────────────────────────────────────────────
String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ── Today's daily log ─────────────────────────────────────────────────────────
final todayDailyLogProvider = StreamProvider<DailyLogModel?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(taskRepositoryProvider).watchDailyLog(
            officeId: user.officeId,
            employeeId: user.uid,
            date: _dateKey(DateTime.now()),
          );
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// ── Monthly logs ──────────────────────────────────────────────────────────────
final selectedLogMonthProvider = StateProvider<DateTime>(
  (ref) => DateTime(DateTime.now().year, DateTime.now().month),
);

final myMonthlyLogsProvider = StreamProvider<List<DailyLogModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  final month = ref.watch(selectedLogMonthProvider);
  final prefix =
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(taskRepositoryProvider).watchMonthlyLogs(
            officeId: user.officeId,
            employeeId: user.uid,
            monthPrefix: prefix,
          );
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// ── Total actual hours this month ─────────────────────────────────────────────
final myMonthlyHoursProvider = Provider<double>((ref) {
  final logsAsync = ref.watch(myMonthlyLogsProvider);
  return logsAsync.when(
    data: (logs) => logs.fold(0.0, (sum, log) => sum + log.distributedHours),
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});
