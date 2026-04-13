import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mang_projects/features/auth/presentation/controllers/auth_providers.dart';

import '../../../home/data/models/user_model.dart';
import '../../../home/presentation/controllers/home_providers.dart';
import '../../data/models/daily_log_model.dart';
import '../../data/models/task_attachment_model.dart';
import '../../data/models/task_comment_model.dart';
import '../../data/models/task_model.dart';
import '../../data/task_collaboration_repository.dart';
import '../../data/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(FirebaseFirestore.instance);
});

final taskCollaborationRepositoryProvider =
    Provider<TaskCollaborationRepository>((ref) {
      return TaskCollaborationRepository(firestore: FirebaseFirestore.instance);
    });

final projectTasksProvider = StreamProvider.family<List<TaskModel>, String>((
  ref,
  projectId,
) {
  // ✅ CRITICAL FIX: Watch effectiveUidProvider — the same auth signal used
  // by allVisibleTasksProvider. When uid=null (after logout) → empty stream.
  // When uid returns (after login) → Riverpod rebuilds this provider automatically.
  final uid = ref.watch(effectiveUidProvider);
  if (uid == null) return const Stream.empty();

  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const Stream.empty();

  return ref
      .watch(taskRepositoryProvider)
      .watchProjectTasks(projectId, officeId: user.officeId);
});

final myTasksProvider = StreamProvider<List<TaskModel>>((ref) async* {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    yield const <TaskModel>[];
    return;
  }

  final repo = ref.watch(taskRepositoryProvider);
  Stream<List<TaskModel>> stream;

  if (user.isReviewer) {
    stream = repo.watchTasksByReviewer(user.uid);
  } else {
    stream = repo.watchTasksByEngineer(user.uid);
  }

  await for (final tasks in stream) {
    if (user.isTeamLeader) {
      // ✅ FIX: isTeamLeader only, not canManageTasks (which includes Admin)
      final map = <String, TaskModel>{};
      for (final task in tasks) {
        map[task.id] = task;
      }
      final list = map.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      yield list;
    } else {
      yield tasks;
    }
  }
});

final singleTaskProvider = StreamProvider.family<TaskModel?, String>((
  ref,
  taskId,
) {
  return ref.watch(taskRepositoryProvider).watchTaskById(taskId);
});

final projectTaskStatsProvider =
    FutureProvider.family<Map<String, int>, String>((ref, projectId) async {
      // ✅ Wait for valid auth via effectiveUidProvider
      final uid = ref.watch(effectiveUidProvider);
      if (uid == null) return {};
      final user = ref.watch(currentUserProvider).value;
      if (user == null) return {};
      return ref
          .watch(taskRepositoryProvider)
          .getProjectTaskStats(projectId, officeId: user.officeId);
    });

final teamLeaderReviewTasksProvider =
    StreamProvider.autoDispose<List<TaskModel>>((ref) async* {
      final uid = ref.watch(effectiveUidProvider);
      if (uid == null) {
        yield const <TaskModel>[];
        return;
      }

      final user = await ref.watch(currentUserProvider.future);
      if (user == null || !user.isTeamLeader) {
        yield const <TaskModel>[];
        return;
      }

      final repo = ref.watch(taskRepositoryProvider);

      await for (final tasks in repo.watchTasksByTeamLeader(uid)) {
        final filtered =
            tasks.where((t) => t.status == 'team_leader_review').toList()
              ..sort((a, b) => a.endDate.compareTo(b.endDate));
        yield filtered;
      }
    });

final pendingTeamLeaderReviewTasksProvider = teamLeaderReviewTasksProvider;

final qcReviewTasksProvider = StreamProvider.autoDispose<List<TaskModel>>((
  ref,
) async* {
  // 🔥 مهم جداً لإعادة البناء بعد logout/login
  final uid = ref.watch(effectiveUidProvider);
  if (uid == null) {
    yield const <TaskModel>[];
    return;
  }

  final user = await ref.watch(currentUserProvider.future);
  if (user == null || !user.isReviewer) {
    yield const <TaskModel>[];
    return;
  }

  final repo = ref.watch(taskRepositoryProvider);

  // QC يرى فقط مهام المراجعة الخاصة به
  await for (final tasks in repo.watchTasksByReviewer(uid)) {
    final filtered = tasks.where((t) => t.status == 'qc_review').toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));

    yield filtered;
  }
});

final pendingQcReviewTasksProvider = qcReviewTasksProvider;

final pendingTeamLeaderReviewCountProvider = Provider<int>((ref) {
  final value = ref.watch(teamLeaderReviewTasksProvider);
  return value.maybeWhen(data: (tasks) => tasks.length, orElse: () => 0);
});

final qcTasksProvider = qcReviewTasksProvider;

final teamLeaderTasksProvider = teamLeaderReviewTasksProvider;

final pendingQcReviewCountProvider = Provider<int>((ref) {
  final value = ref.watch(qcReviewTasksProvider);
  return value.maybeWhen(data: (tasks) => tasks.length, orElse: () => 0);
});

final clientReviewTasksProvider = Provider.family<List<TaskModel>, String>((
  ref,
  projectId,
) {
  final tasksAsync = ref.watch(projectTasksProvider(projectId));
  return tasksAsync.when(
    data: (tasks) =>
        tasks.where((t) => t.status == 'client_review').toList()..sort((a, b) {
          final aTime = a.submittedToClientAt ?? a.createdAt;
          final bTime = b.submittedToClientAt ?? b.createdAt;
          return bTime.compareTo(aTime);
        }),
    loading: () => const [],
    error: (_, _) => const [],
  );
});

final pendingClientReviewCountProvider = Provider.family<int, String>((
  ref,
  projectId,
) {
  return ref.watch(clientReviewTasksProvider(projectId)).length;
});

final todayDailyLogProvider = StreamProvider<DailyLogModel?>((ref) async* {
  final user = await ref.watch(currentUserProvider.future);
  final now = DateTime.now();
  final date =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  if (user == null) {
    yield null;
    return;
  }

  yield* ref
      .watch(taskRepositoryProvider)
      .watchDailyLog(officeId: user.officeId, employeeId: user.uid, date: date);
});

final selectedLogMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final monthlyDailyLogsProvider = StreamProvider<List<DailyLogModel>>((
  ref,
) async* {
  final user = await ref.watch(currentUserProvider.future);
  final month = ref.watch(selectedLogMonthProvider);
  final monthPrefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';

  if (user == null) {
    yield const <DailyLogModel>[];
    return;
  }

  yield* ref
      .watch(taskRepositoryProvider)
      .watchMonthlyLogs(
        officeId: user.officeId,
        employeeId: user.uid,
        monthPrefix: monthPrefix,
      );
});

class TaskScope {
  final String officeId;
  final String projectId;
  final String taskId;

  const TaskScope({
    required this.officeId,
    required this.projectId,
    required this.taskId,
  });

  @override
  bool operator ==(Object other) {
    return other is TaskScope &&
        other.officeId == officeId &&
        other.projectId == projectId &&
        other.taskId == taskId;
  }

  @override
  int get hashCode => Object.hash(officeId, projectId, taskId);
}

final taskCommentsProvider =
    StreamProvider.family<List<TaskComment>, TaskScope>((ref, scope) {
      return ref
          .watch(taskCollaborationRepositoryProvider)
          .watchTaskComments(
            officeId: scope.officeId,
            projectId: scope.projectId,
            taskId: scope.taskId,
          );
    });

final taskAttachmentsProvider =
    StreamProvider.family<List<TaskAttachment>, TaskScope>((ref, scope) {
      return ref
          .watch(taskCollaborationRepositoryProvider)
          .watchTaskAttachments(
            officeId: scope.officeId,
            projectId: scope.projectId,
            taskId: scope.taskId,
          );
    });

final addTaskCommentControllerProvider = Provider<AddTaskCommentController>((
  ref,
) {
  return AddTaskCommentController(ref);
});

final uploadTaskAttachmentControllerProvider =
    Provider<UploadTaskAttachmentController>((ref) {
      return UploadTaskAttachmentController(ref);
    });

final deleteTaskAttachmentControllerProvider =
    Provider<DeleteTaskAttachmentController>((ref) {
      return DeleteTaskAttachmentController(ref);
    });

class AddTaskCommentController {
  final Ref ref;
  AddTaskCommentController(this.ref);

  Future<void> submit({
    required String officeId,
    required String projectId,
    required String taskId,
    required String text,
    required UserModel user,
  }) async {
    final value = text.trim();
    if (value.isEmpty) return;

    await ref
        .read(taskCollaborationRepositoryProvider)
        .addComment(
          officeId: officeId,
          projectId: projectId,
          taskId: taskId,
          authorId: user.uid,
          authorName: user.name,
          authorRole: user.role,
          text: value,
        );
  }
}

class UploadTaskAttachmentController {
  final Ref ref;
  UploadTaskAttachmentController(this.ref);

  Future<void> submit({
    required String officeId,
    required String projectId,
    required String taskId,
    required UserModel user,
    File? file,
    Uint8List? bytes,
    String? fileName,
  }) async {
    await ref
        .read(taskCollaborationRepositoryProvider)
        .uploadAttachment(
          officeId: officeId,
          projectId: projectId,
          taskId: taskId,
          uploadedBy: user.uid,
          uploaderName: user.name,
          uploaderRole: user.role,
          file: file,
          bytes: bytes,
          fileName: fileName,
        );
  }
}

class DeleteTaskAttachmentController {
  final Ref ref;
  DeleteTaskAttachmentController(this.ref);

  Future<void> submit({
    required String officeId,
    required String projectId,
    required String taskId,
    required String attachmentId,
    required String storagePath,
  }) async {
    await ref
        .read(taskCollaborationRepositoryProvider)
        .deleteAttachment(
          officeId: officeId,
          projectId: projectId,
          taskId: taskId,
          attachmentId: attachmentId,
          storagePath: storagePath,
        );
  }
}

final taskByIdProvider = StreamProvider.family<TaskModel?, String>((
  ref,
  taskId,
) {
  final firestore = FirebaseFirestore.instance;
  return firestore.collection('tasks').doc(taskId).snapshots().map((doc) {
    if (!doc.exists) return null;
    return TaskModel.fromFirestore(doc);
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// allVisibleTasksProvider — FIXED VERSION
//
// Routing logic (priority order):
//   1. CLIENT          → tasks where clientId == linkedClientId
//   2. DC              → tasks where status == client_review (officeId scoped)
//                        ⚠️ DC must come BEFORE canSeeAllProjects because
//                           canSeeAllProjects currently includes DC
//   3. ADMIN / MGMT / REVIEWER (canSeeAllTasks) → all tasks in office
//   4. TEAM LEADER     → tasks where teamLeaderId == uid
//   5. ENGINEER        → tasks where assignedEngineerIds arrayContains uid
// ═══════════════════════════════════════════════════════════════════════════════

final allVisibleTasksProvider = StreamProvider.autoDispose<List<TaskModel>>((
  ref,
) {
  // 🔥 IMPORTANT: Force rebuild after logout/login
  final uid = ref.watch(effectiveUidProvider);
  if (uid == null) return const Stream.empty();

  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const Stream.empty();

  final firestore = FirebaseFirestore.instance;

  // ── 1. CLIENT ────────────────────────────────────────────────────────────
  if (user.isClient) {
    return firestore
        .collection('tasks')
        .where('clientId', isEqualTo: user.linkedClientId)
        .snapshots()
        .map((s) => s.docs.map((d) => TaskModel.fromFirestore(d)).toList());
  }

  // ── 2. DC ────────────────────────────────────────────────────────────────
  if (user.isDC) {
    return firestore
        .collection('tasks')
        .where('officeId', isEqualTo: user.officeId)
        .where('status', isEqualTo: 'client_review')
        .snapshots()
        .map((s) => s.docs.map((d) => TaskModel.fromFirestore(d)).toList());
  }

  // ── 3. ADMIN + REVIEWER + MANAGEMENT ─────────────────────────────────────
  if (user.canSeeAllProjects) {
    return firestore
        .collection('tasks')
        .where('officeId', isEqualTo: user.officeId)
        .snapshots()
        .map((s) => s.docs.map((d) => TaskModel.fromFirestore(d)).toList());
  }

  // ── 4. TEAM LEADER ───────────────────────────────────────────────────────
  if (user.isTeamLeader) {
    return firestore
        .collection('tasks')
        .where('teamLeaderId', isEqualTo: uid) // 🔥 use uid not user.uid
        .snapshots()
        .map((s) => s.docs.map((d) => TaskModel.fromFirestore(d)).toList());
  }

  // ── 5. ENGINEER ──────────────────────────────────────────────────────────
  return firestore
      .collection('tasks')
      .where('assignedEngineerIds', arrayContains: uid) // 🔥 use uid
      .snapshots()
      .map((s) => s.docs.map((d) => TaskModel.fromFirestore(d)).toList());
});

// ══════════════════════════════════════════════════════════════════════════════
// Overdue Tasks Provider — for management dashboard & alerts
// Tasks past endDate that are not completed
// ══════════════════════════════════════════════════════════════════════════════

final overdueTasksProvider = StreamProvider.autoDispose<List<TaskModel>>((ref) {
  final uid = ref.watch(effectiveUidProvider);
  if (uid == null) return const Stream.empty();

  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const Stream.empty();

  // Only visible to users who can see all projects
  if (!user.canSeeAllProjects) return const Stream.empty();

  final firestore = FirebaseFirestore.instance;
  return firestore
      .collection('tasks')
      .where('officeId', isEqualTo: user.officeId)
      .snapshots()
      .map((s) {
        final now = DateTime.now();
        return s.docs
            .map((d) => TaskModel.fromFirestore(d))
            .where((t) =>
                t.status != 'completed' &&
                t.endDate.isBefore(now))
            .toList()
          ..sort((a, b) => a.endDate.compareTo(b.endDate));
      });
});

final overdueTasksCountProvider = Provider<int>((ref) {
  return ref.watch(overdueTasksProvider).when(
    data: (tasks) => tasks.length,
    loading: () => 0,
    error: (_, _) => 0,
  );
});

// ── All tasks by project for management overview ───────────────────────────────
final allOfficeTasksProvider = StreamProvider.autoDispose<List<TaskModel>>((ref) {
  final uid = ref.watch(effectiveUidProvider);
  if (uid == null) return const Stream.empty();

  final user = ref.watch(currentUserProvider).value;
  if (user == null || !user.canSeeAllProjects) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('tasks')
      .where('officeId', isEqualTo: user.officeId)
      .snapshots()
      .map((s) => s.docs.map((d) => TaskModel.fromFirestore(d)).toList());
});
