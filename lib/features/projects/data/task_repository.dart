import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/task_model.dart';
import 'models/daily_log_model.dart';
import 'repositories/task_activity_repository.dart';
import 'models/task_activity_model.dart';
import '../../notifications/data/notification_repository.dart';

class TaskRepository {
  final FirebaseFirestore _firestore;

  TaskRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> get _tasksRef =>
      _firestore.collection('tasks');

  CollectionReference<Map<String, dynamic>> get _projectsRef =>
      _firestore.collection('projects');

  final TaskActivityRepository _activityRepository = TaskActivityRepository();
  final NotificationRepository _notifRepo = NotificationRepository();

  // ───────────────────────────────────────────────────────────────────────────
  // Helpers
  // ───────────────────────────────────────────────────────────────────────────

  int _resolveProgress({required String status, double? inProgressValue}) {
    switch (status) {
      case 'not_started':
        return 0;
      case 'in_progress':
        final value = (inProgressValue ?? 0).round();
        if (value < 0) return 0;
        if (value > 60) return 60;
        return value;
      case 'team_leader_review':
        return 70;
      case 'qc_review':
        return 80;
      case 'client_review':
        return 90;
      case 'completed':
        return 100;
      default:
        return 0;
    }
  }

  Future<TaskModel?> _getTask(String taskId) async {
    final doc = await _tasksRef.doc(taskId).get();
    if (!doc.exists) return null;
    return TaskModel.fromFirestore(doc);
  }

  Future<void> _logActivity({
    required TaskModel task,
    required String type,
    required String message,
    required String userName,
    required String userRole,
  }) async {
    await _activityRepository.addActivity(
      TaskActivity(
        id: '',
        taskId: task.id,
        officeId: task.officeId,
        type: type,
        message: message,
        userName: userName,
        userRole: userRole,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _recalculateProjectCompletion(String projectId) async {
    final snapshot = await _tasksRef
        .where('projectId', isEqualTo: projectId)
        .get();

    if (snapshot.docs.isEmpty) {
      await _projectsRef.doc(projectId).update({'completionPercentage': 0});
      return;
    }

    double total = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      total += ((data['progress'] ?? 0) as num).toDouble();
    }

    final average = total / snapshot.docs.length;

    await _projectsRef.doc(projectId).update({'completionPercentage': average});
  }

  Map<String, dynamic> _withUpdatedAt(Map<String, dynamic> data) {
    return {...data, 'updatedAt': Timestamp.now()};
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Streams / Queries
  // ───────────────────────────────────────────────────────────────────────────

  Stream<List<TaskModel>> watchProjectTasks(String projectId) {
    return _tasksRef
        .where('projectId', isEqualTo: projectId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(TaskModel.fromFirestore).toList()
                ..sort((a, b) => a.endDate.compareTo(b.endDate)),
        );
  }

  Stream<List<TaskModel>> watchTasksByEngineer(String engineerId) {
    return _tasksRef
        .where('assignedEngineerIds', arrayContains: engineerId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(TaskModel.fromFirestore).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<TaskModel>> watchTasksByReviewer(String reviewerId) {
    return _tasksRef
        .where('reviewerId', isEqualTo: reviewerId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(TaskModel.fromFirestore).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<TaskModel>> watchTasksByTeamLeader(String teamLeaderId) {
    return _tasksRef
        .where('teamLeaderId', isEqualTo: teamLeaderId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(TaskModel.fromFirestore).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<TaskModel?> watchTaskById(String taskId) {
    return _tasksRef.doc(taskId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return TaskModel.fromFirestore(doc);
    });
  }

  Future<Map<String, int>> getProjectTaskStats(String projectId) async {
    final snapshot = await _tasksRef
        .where('projectId', isEqualTo: projectId)
        .get();

    int total = 0;
    int notStarted = 0;
    int inProgress = 0;
    int teamLeaderReview = 0;
    int qcReview = 0;
    int clientReview = 0;
    int completed = 0;
    int overdue = 0;

    for (final doc in snapshot.docs) {
      final task = TaskModel.fromFirestore(doc);
      total++;

      switch (task.status) {
        case 'not_started':
          notStarted++;
          break;
        case 'in_progress':
          inProgress++;
          break;
        case 'team_leader_review':
          teamLeaderReview++;
          break;
        case 'qc_review':
          qcReview++;
          break;
        case 'client_review':
          clientReview++;
          break;
        case 'completed':
          completed++;
          break;
      }

      if (task.isOverdue) overdue++;
    }

    return {
      'total': total,
      'not_started': notStarted,
      'in_progress': inProgress,
      'team_leader_review': teamLeaderReview,
      'qc_review': qcReview,
      'client_review': clientReview,
      'completed': completed,
      'overdue': overdue,
    };
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CRUD
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> createTask(TaskModel task, {String createdByName = ''}) async {
    final data = task.copyWith(
      status: 'not_started',
      progress: 0,
      createdAt: DateTime.now(),
    );

    await _tasksRef.add(_withUpdatedAt(data.toFirestore()));
    await _recalculateProjectCompletion(data.projectId);

    // إشعار إسناد task جديدة
    try {
      final officeWide = await _notifRepo.fetchOfficeWideStakeholders(data.officeId);
      await _notifRepo.sendTaskAssignedNotification(
        officeId: data.officeId,
        taskId: data.id.isEmpty ? '' : data.id,
        taskTitle: data.title,
        projectId: data.projectId,
        projectName: data.projectName,
        engineerIds: data.assignedEngineerIds,
        reviewerId: data.reviewerId,
        teamLeaderId: data.teamLeaderId,
        officeWideIds: officeWide,
        assignedByName: createdByName,
      );
    } catch (_) {}
  }

  Future<void> updateTask(TaskModel task) async {
    await _tasksRef.doc(task.id).update(_withUpdatedAt(task.toFirestore()));

    await _recalculateProjectCompletion(task.projectId);
  }

  Future<void> deleteTask(String taskId) async {
    final task = await _getTask(taskId);
    if (task == null) return;

    if (task.status != 'completed') {
      throw Exception('Cannot delete task before completion');
    }
    await _tasksRef.doc(taskId).delete();
    await _recalculateProjectCompletion(task.projectId);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Progress
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> updateTaskProgress({
    required String taskId,
    required double progressValue,
  }) async {
    final task = await _getTask(taskId);
    if (task == null) return;

    if (task.status != 'in_progress') {
      throw Exception(
        'Progress can only be updated while task is in progress.',
      );
    }

    final resolved = _resolveProgress(
      status: 'in_progress',
      inProgressValue: progressValue,
    );

    await _tasksRef
        .doc(taskId)
        .update(_withUpdatedAt({'progress': resolved.toDouble()}));

    await _recalculateProjectCompletion(task.projectId);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Workflow
  // ───────────────────────────────────────────────────────────────────────────

  // ── Notification helper ────────────────────────────────────────────────────
  Future<void> _notify({
    required TaskModel task,
    required String newStatus,
    required String changedByName,
  }) async {
    try {
      final officeWide =
          await _notifRepo.fetchOfficeWideStakeholders(task.officeId);
      await _notifRepo.sendTaskStatusNotification(
        officeId: task.officeId,
        taskId: task.id,
        taskTitle: task.title,
        projectId: task.projectId,
        projectName: task.projectName,
        newStatus: newStatus,
        changedByName: changedByName,
        engineerIds: task.assignedEngineerIds,
        teamLeaderId: task.teamLeaderId,
        reviewerId: task.reviewerId,
        officeWideIds: officeWide,
      );
    } catch (_) {
      // Notifications are non-blocking — don't break the workflow
    }
  }

  // ── Workflow ────────────────────────────────────────────────────────────────

  Future<void> startTask(String taskId, {String userName = ''}) async {
    final task = await _getTask(taskId);
    if (task == null) return;

    await _tasksRef.doc(taskId).update(_withUpdatedAt({
      'status': 'in_progress',
      'progress': _resolveProgress(
        status: 'in_progress',
        inProgressValue: task.progress,
      ).toDouble(),
    }));

    await _recalculateProjectCompletion(task.projectId);
    await _notify(task: task.copyWith(status: 'in_progress'),
        newStatus: 'in_progress', changedByName: userName);
  }

  Future<void> submitToTeamLeaderReview(String taskId,
      {String userName = ''}) async {
    final task = await _getTask(taskId);
    if (task == null) return;

    await _tasksRef.doc(taskId).update(_withUpdatedAt({
      'status': 'team_leader_review',
      'progress': 70.0,
      'teamLeaderReviewedAt': null,
      'teamLeaderReviewNotes': '',
    }));

    await _recalculateProjectCompletion(task.projectId);
    await _notify(task: task, newStatus: 'team_leader_review',
        changedByName: userName);
  }

  Future<void> teamLeaderApproveToQc({
    required String taskId,
    String notes = '',
    String userName = '',
  }) async {
    final task = await _getTask(taskId);
    if (task == null) return;

    await _tasksRef.doc(taskId).update(_withUpdatedAt({
      'status': 'qc_review',
      'progress': 80.0,
      'teamLeaderReviewNotes': notes,
      'teamLeaderReviewedAt': Timestamp.now(),
      'qcReviewNotes': '',
      'qcReviewedAt': null,
    }));

    await _recalculateProjectCompletion(task.projectId);
    await _notify(task: task, newStatus: 'qc_review', changedByName: userName);
  }

  Future<void> teamLeaderRejectToInProgress({
    required String taskId,
    required String notes,
    double? backToProgress,
    String userName = '',
  }) async {
    final task = await _getTask(taskId);
    if (task == null) return;

    final resolvedProgress = _resolveProgress(
      status: 'in_progress',
      inProgressValue: backToProgress ?? task.progress,
    );

    await _tasksRef.doc(taskId).update(_withUpdatedAt({
      'status': 'in_progress',
      'progress': resolvedProgress.toDouble(),
      'teamLeaderReviewNotes': notes,
      'teamLeaderReviewedAt': Timestamp.now(),
    }));

    await _recalculateProjectCompletion(task.projectId);
    await _notify(task: task, newStatus: 'in_progress',
        changedByName: userName);
  }

  Future<void> qcApproveToClient({
    required String taskId,
    String notes = '',
    String userName = '',
  }) async {
    final task = await _getTask(taskId);
    if (task == null) return;

    await _tasksRef.doc(taskId).update(_withUpdatedAt({
      'status': 'client_review',
      'progress': 90.0,
      'qcReviewNotes': notes,
      'qcReviewedAt': Timestamp.now(),
      'submittedToClientAt': Timestamp.now(),
      'clientReviewRound': task.clientReviewRound + 1,
      'clientReviewNotes': '',
      'clientReviewedAt': null,
    }));

    await _recalculateProjectCompletion(task.projectId);
    await _notify(task: task, newStatus: 'client_review',
        changedByName: userName);
  }

  Future<void> qcRejectToTeamLeader({
    required String taskId,
    required String notes,
    String userName = '',
  }) async {
    final task = await _getTask(taskId);
    if (task == null) return;

    await _tasksRef.doc(taskId).update(_withUpdatedAt({
      'status': 'team_leader_review',
      'progress': 70.0,
      'qcReviewNotes': notes,
      'qcReviewedAt': Timestamp.now(),
    }));

    await _recalculateProjectCompletion(task.projectId);
    await _notify(task: task, newStatus: 'team_leader_review',
        changedByName: userName);
  }

  Future<void> clientApproveTask({
    required String taskId,
    String notes = '',
    String userName = '',
  }) async {
    final task = await _getTask(taskId);
    if (task == null) return;

    await _tasksRef.doc(taskId).update(_withUpdatedAt({
      'status': 'completed',
      'progress': 100.0,
      'clientReviewNotes': notes,
      'clientReviewedAt': Timestamp.now(),
    }));

    await _logActivity(
      task: task,
      type: 'client_approve',
      message: notes.isEmpty ? 'Client approved task' : notes,
      userName: userName,
      userRole: 'client',
    );

    await _recalculateProjectCompletion(task.projectId);
    await _notify(task: task, newStatus: 'completed', changedByName: userName);
  }

  Future<void> clientRejectToQc({
    required String taskId,
    required String notes,
    required String userName,
  }) async {
    final task = await _getTask(taskId);
    if (task == null) return;

    await _tasksRef.doc(taskId).update(_withUpdatedAt({
      'status': 'qc_review',
      'progress': 80.0,
      'clientReviewNotes': notes,
      'clientReviewedAt': Timestamp.now(),
    }));

    await _logActivity(
      task: task,
      type: 'client_reject',
      message: notes.isEmpty ? 'Client rejected task' : notes,
      userName: userName,
      userRole: 'client',
    );

    await _recalculateProjectCompletion(task.projectId);
    await _notify(task: task, newStatus: 'qc_review', changedByName: userName);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DAILY LOGS
  // ───────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _dailyLogsRef =>
      _firestore.collection('daily_logs');

  Future<DailyLogModel> getOrCreateDailyLog({
    required String officeId,
    required String employeeId,
    required String employeeName,
    required String date,
    required double totalHours,
  }) async {
    final existing = await _dailyLogsRef
        .where('officeId', isEqualTo: officeId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isEqualTo: date)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return DailyLogModel.fromFirestore(existing.docs.first);
    }

    final doc = await _dailyLogsRef.add({
      'officeId': officeId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'date': date,
      'totalHours': totalHours,
      'entries': const [],
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    final created = await doc.get();
    return DailyLogModel.fromFirestore(created);
  }

  Future<void> updateLogEntries({
    required String logId,
    required List<DailyLogEntry> entries,
  }) async {
    await _dailyLogsRef.doc(logId).update({
      'entries': entries
          .map(
            (e) => {
              'taskId': e.taskId,
              'taskTitle': e.taskTitle,
              'projectId': e.projectId,
              'projectName': e.projectName,
              'hours': e.hours,
            },
          )
          .toList(),
      'updatedAt': Timestamp.now(),
    });
  }

  Stream<DailyLogModel?> watchDailyLog({
    required String officeId,
    required String employeeId,
    required String date,
  }) {
    return _dailyLogsRef
        .where('officeId', isEqualTo: officeId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isEqualTo: date)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return DailyLogModel.fromFirestore(snapshot.docs.first);
        });
  }

  Stream<List<DailyLogModel>> watchMonthlyLogs({
    required String officeId,
    required String employeeId,
    required String monthPrefix,
  }) {
    return _dailyLogsRef
        .where('officeId', isEqualTo: officeId)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(DailyLogModel.fromFirestore)
              .where((log) => log.date.startsWith(monthPrefix))
              .toList(),
        );
  }

  Future<void> deleteAttachment({
    required String taskId,
    required String attachmentId,
  }) async {
    final firestore = FirebaseFirestore.instance;

    // 🔥 حذف من Firestore
    await firestore
        .collection('tasks')
        .doc(taskId)
        .collection('attachments')
        .doc(attachmentId)
        .delete();

    // ⚠️ مبدئيًا بدون حذف من Storage (نضيفه بعدين لو حبيت)
  }
}
