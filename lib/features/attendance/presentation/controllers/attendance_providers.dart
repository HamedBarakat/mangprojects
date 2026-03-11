import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/attendance_model.dart';
import '../../data/attendance_repository.dart';
import '../../../../features/home/presentation/controllers/home_providers.dart';

// ── Repository ────────────────────────────────────────────────────────────────
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository();
});

// ── Today's record للموظف الحالي ─────────────────────────────────────────────
final todayRecordProvider = StreamProvider<AttendanceModel?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(attendanceRepositoryProvider).watchTodayRecord(
            officeId: user.officeId,
            employeeId: user.uid,
          );
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// ── هل الموظف عمل check-in النهارده؟ ────────────────────────────────────────
final isCheckedInProvider = Provider<bool>((ref) {
  final todayAsync = ref.watch(todayRecordProvider);
  return todayAsync.when(
    data: (record) => record != null,
    loading: () => false,
    error: (_, __) => false,
  );
});

// ── هل الموظف عمل check-out النهارده؟ ───────────────────────────────────────
final isCheckedOutProvider = Provider<bool>((ref) {
  final todayAsync = ref.watch(todayRecordProvider);
  return todayAsync.when(
    data: (record) => record?.isCheckedOut ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
});

// ── كل الحضور النهارده (Admin view) ──────────────────────────────────────────
final todayAllAttendanceProvider = StreamProvider<List<AttendanceModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref
          .watch(attendanceRepositoryProvider)
          .watchTodayAll(user.officeId);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// ── Selected month state ──────────────────────────────────────────────────────
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// ── Monthly records للموظف الحالي ────────────────────────────────────────────
final myMonthlyRecordsProvider = StreamProvider<List<AttendanceModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);

  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(attendanceRepositoryProvider).watchMonthlyRecords(
            officeId: user.officeId,
            employeeId: user.uid,
            year: selectedMonth.year,
            month: selectedMonth.month,
          );
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// ── Monthly stats للموظف الحالي ──────────────────────────────────────────────
final myMonthlyStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final userAsync = ref.watch(currentUserProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);

  return userAsync.when(
    data: (user) async {
      if (user == null) return {'present': 0, 'late': 0, 'absent': 0};
      return await ref.watch(attendanceRepositoryProvider).getMonthlyStats(
            officeId: user.officeId,
            employeeId: user.uid,
            year: selectedMonth.year,
            month: selectedMonth.month,
          );
    },
    loading: () async => {'present': 0, 'late': 0, 'absent': 0},
    error: (_, __) async => {'present': 0, 'late': 0, 'absent': 0},
  );
});

// ── Pending overtime requests (Admin) ────────────────────────────────────────
final pendingOvertimeProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null || !user.isAdmin) return const Stream.empty();
      return ref
          .watch(attendanceRepositoryProvider)
          .watchPendingOvertimeRequests(user.officeId);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// ── Pending overtime count — للـ badge في الـ nav ────────────────────────────
final pendingOvertimeCountProvider = Provider<int>((ref) {
  final pendingAsync = ref.watch(pendingOvertimeProvider);
  return pendingAsync.when(
    data: (list) => list.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
