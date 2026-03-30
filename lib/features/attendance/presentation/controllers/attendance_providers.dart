import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mang_projects/core/services/location_service.dart';

import '../../data/models/attendance_model.dart';
import '../../data/attendance_repository.dart';
import '../../../../features/home/presentation/controllers/home_providers.dart';

// ── Repository & Services ─────────────────────────────────────────────────────
final attendanceRepositoryProvider = Provider<AttendanceRepository>((_) => AttendanceRepository());
final locationServiceProvider = Provider<LocationService>((_) => LocationService());

// ── Today's record for current user ──────────────────────────────────────────
final todayRecordProvider = StreamProvider<AttendanceModel?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(attendanceRepositoryProvider)
          .watchTodayRecord(officeId: user.officeId, employeeId: user.uid);
    },
    loading: () => const Stream.empty(),
    error: (_, _) => const Stream.empty(),
  );
});

final isCheckedInProvider = Provider<bool>((ref) {
  return ref.watch(todayRecordProvider).when(
    data: (r) => r != null, loading: () => false, error: (_, _) => false,
  );
});

final isCheckedOutProvider = Provider<bool>((ref) {
  return ref.watch(todayRecordProvider).when(
    data: (r) => r?.isCheckedOut ?? false, loading: () => false, error: (_, _) => false,
  );
});

// ── All attendance today (Admin/Management view) ───────────────────────────────
final todayAllAttendanceProvider = StreamProvider<List<AttendanceModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(attendanceRepositoryProvider).watchTodayAll(user.officeId);
    },
    loading: () => const Stream.empty(),
    error: (_, _) => const Stream.empty(),
  );
});

// ── Selected month ────────────────────────────────────────────────────────────
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// ── Monthly records for current user ─────────────────────────────────────────
final myMonthlyRecordsProvider = StreamProvider<List<AttendanceModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  final month = ref.watch(selectedMonthProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(attendanceRepositoryProvider).watchMonthlyRecords(
        officeId: user.officeId,
        employeeId: user.uid,
        year: month.year,
        month: month.month,
      );
    },
    loading: () => const Stream.empty(),
    error: (_, _) => const Stream.empty(),
  );
});

// ── Monthly stats ─────────────────────────────────────────────────────────────
final myMonthlyStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final userAsync = ref.watch(currentUserProvider);
  final month = ref.watch(selectedMonthProvider);
  return userAsync.when(
    data: (user) async {
      if (user == null) return {'present': 0, 'late': 0, 'absent': 0};
      return ref.watch(attendanceRepositoryProvider).getMonthlyStats(
        officeId: user.officeId,
        employeeId: user.uid,
        year: month.year,
        month: month.month,
      );
    },
    loading: () async => {'present': 0, 'late': 0, 'absent': 0},
    error: (_, _) async => {'present': 0, 'late': 0, 'absent': 0},
  );
});

// ── Pending overtime requests ─────────────────────────────────────────────────
final pendingOvertimeProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null || !user.isAdmin) return const Stream.empty();
      return ref.watch(attendanceRepositoryProvider).watchPendingOvertimeRequests(user.officeId);
    },
    loading: () => const Stream.empty(),
    error: (_, _) => const Stream.empty(),
  );
});

final pendingOvertimeCountProvider = Provider<int>((ref) {
  return ref.watch(pendingOvertimeProvider).when(
    data: (list) => list.length, loading: () => 0, error: (_, _) => 0,
  );
});
