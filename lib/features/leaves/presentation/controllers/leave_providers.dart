import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/leave_repository.dart';
import '../../data/models/leave_request_model.dart';
import '../../../../features/home/presentation/controllers/home_providers.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>((_) => LeaveRepository());

// ── My leave requests ─────────────────────────────────────────────────────────
final myLeavesProvider = StreamProvider<List<LeaveRequestModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(leaveRepositoryProvider).watchMyLeaves(user.uid);
    },
    loading: () => const Stream.empty(),
    error: (_, _) => const Stream.empty(),
  );
});

// ── Pending approvals ─────────────────────────────────────────────────────────
// Admin sees all pending in office; approver job titles see only their queue
final pendingLeaveApprovalsProvider = StreamProvider<List<LeaveRequestModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      if (user.isAdmin) {
        // Admin sees everything pending
        return ref.watch(leaveRepositoryProvider).watchPendingApprovals(user.officeId);
      }
      // Non-admin: only where currentApproverJobTitle matches theirs
      if (LeaveRepository.isApproverJobTitle(user.jobTitle)) {
        return ref
            .watch(leaveRepositoryProvider)
            .watchPendingApprovalsForJobTitle(user.officeId, user.jobTitle);
      }
      return const Stream.empty();
    },
    loading: () => const Stream.empty(),
    error: (_, _) => const Stream.empty(),
  );
});

final pendingLeaveCountProvider = Provider<int>((ref) {
  return ref.watch(pendingLeaveApprovalsProvider).when(
    data: (list) => list.length,
    loading: () => 0,
    error: (_, _) => 0,
  );
});

// ── All leaves (admin view) ───────────────────────────────────────────────────
final allLeavesProvider = StreamProvider<List<LeaveRequestModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null || !user.isAdmin) return const Stream.empty();
      return ref.watch(leaveRepositoryProvider).watchAllLeaves(user.officeId);
    },
    loading: () => const Stream.empty(),
    error: (_, _) => const Stream.empty(),
  );
});

// ── Leave balance ─────────────────────────────────────────────────────────────
final leaveBalanceProvider = FutureProvider<Map<String, int>>((ref) async {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) async {
      if (user == null) return {'total': 21, 'used': 0, 'remaining': 21};
      return ref.watch(leaveRepositoryProvider).getLeaveBalance(
        user.uid,
        DateTime.now().year,
      );
    },
    loading: () async => {'total': 21, 'used': 0, 'remaining': 21},
    error: (_, _) async => {'total': 21, 'used': 0, 'remaining': 21},
  );
});
