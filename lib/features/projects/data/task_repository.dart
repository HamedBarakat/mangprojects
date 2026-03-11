import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/task_model.dart';
import 'models/daily_log_model.dart';

class TaskRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _tasks => _db.collection('tasks');
  CollectionReference get _dailyLogs => _db.collection('daily_logs');
  CollectionReference get _projects => _db.collection('projects');

  // ── Create Task ────────────────────────────────────────────────────────────
  Future<String> createTask(TaskModel task) async {
    final doc = _tasks.doc();
    final newTask = TaskModel(
      id: doc.id,
      officeId: task.officeId,
      projectId: task.projectId,
      projectName: task.projectName,
      title: task.title,
      description: task.description,
      category: task.category,
      discipline: task.discipline,
      assignedTo: task.assignedTo,
      assignedToName: task.assignedToName,
      teamLeaderId: task.teamLeaderId,
      teamLeaderName: task.teamLeaderName,
      reviewerId: task.reviewerId,
      reviewerName: task.reviewerName,
      startDate: task.startDate,
      endDate: task.endDate,
      plannedHours: task.plannedHours,
      actualHours: 0,
      status: 'not_started',
      approvalStatus: 'pending',
      approvalNotes: '',
      approvedAt: null,
      createdBy: task.createdBy,
      createdAt: DateTime.now(),
      notes: task.notes,
    );
    await doc.set(newTask.toFirestore());
    await _updateProjectCompletion(task.projectId);
    return doc.id;
  }

  // ── Update Task ────────────────────────────────────────────────────────────
  Future<void> updateTask(TaskModel task) async {
    await _tasks.doc(task.id).update(task.toFirestore());
  }

  // ── Delete Task ────────────────────────────────────────────────────────────
  Future<void> deleteTask(String taskId) async {
    final taskDoc = await _tasks.doc(taskId).get();
    final projectId =
        (taskDoc.data() as Map<String, dynamic>?)?['projectId'] ?? '';
    await _tasks.doc(taskId).delete();
    if (projectId.isNotEmpty) await _updateProjectCompletion(projectId);
  }

  // ── Watch tasks for a project ──────────────────────────────────────────────
  Stream<List<TaskModel>> watchProjectTasks(String projectId) {
    return _tasks
        .where('projectId', isEqualTo: projectId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(TaskModel.fromFirestore).toList());
  }

  // ── Watch tasks assigned to engineer ──────────────────────────────────────
  Stream<List<TaskModel>> watchMyTasks({
    required String officeId,
    required String employeeId,
  }) {
    return _tasks
        .where('officeId', isEqualTo: officeId)
        .where('assignedTo', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(TaskModel.fromFirestore).toList());
  }

  // ── Watch tasks for review (Reviewer) ─────────────────────────────────────
  Stream<List<TaskModel>> watchTasksForReview({
    required String officeId,
    required String reviewerId,
  }) {
    return _tasks
        .where('officeId', isEqualTo: officeId)
        .where('reviewerId', isEqualTo: reviewerId)
        .where('status', isEqualTo: 'under_review')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(TaskModel.fromFirestore).toList());
  }

  // ── Watch tasks by team leader ─────────────────────────────────────────────
  Stream<List<TaskModel>> watchTeamTasks({
    required String officeId,
    required String teamLeaderId,
  }) {
    return _tasks
        .where('officeId', isEqualTo: officeId)
        .where('teamLeaderId', isEqualTo: teamLeaderId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(TaskModel.fromFirestore).toList());
  }

  // ── Update task status ─────────────────────────────────────────────────────
  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    await _tasks.doc(taskId).update({'status': status});
    final taskDoc = await _tasks.doc(taskId).get();
    final projectId =
        (taskDoc.data() as Map<String, dynamic>?)?['projectId'] ?? '';
    if (projectId.isNotEmpty) await _updateProjectCompletion(projectId);
  }

  // ── Submit task for review ─────────────────────────────────────────────────
  Future<void> submitForReview(String taskId) async {
    await _tasks.doc(taskId).update({'status': 'under_review'});
  }

  // ── Approve / Reject task (Reviewer) ──────────────────────────────────────
  Future<void> reviewTask({
    required String taskId,
    required String approvalStatus,
    required String notes,
    required String reviewerId,
  }) async {
    await _tasks.doc(taskId).update({
      'approvalStatus': approvalStatus,
      'approvalNotes': notes,
      'approvedAt': approvalStatus != 'rejected'
          ? Timestamp.fromDate(DateTime.now())
          : null,
      if (approvalStatus == 'approved') 'status': 'completed',
      if (approvalStatus == 'rejected') 'status': 'in_progress',
    });

    final taskDoc = await _tasks.doc(taskId).get();
    final projectId =
        (taskDoc.data() as Map<String, dynamic>?)?['projectId'] ?? '';
    if (projectId.isNotEmpty) await _updateProjectCompletion(projectId);
  }

  // ── Update project completion percentage ──────────────────────────────────
  Future<void> _updateProjectCompletion(String projectId) async {
    final snap = await _tasks.where('projectId', isEqualTo: projectId).get();
    final tasks = snap.docs.map(TaskModel.fromFirestore).toList();
    if (tasks.isEmpty) {
      await _projects.doc(projectId).update({'completionPercentage': 0.0});
      return;
    }
    final completed = tasks.where((t) => t.status == 'completed').length;
    final percentage = (completed / tasks.length) * 100;
    await _projects.doc(projectId).update({'completionPercentage': percentage});
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DAILY LOGS
  // ══════════════════════════════════════════════════════════════════════════

  Future<DailyLogModel> getOrCreateDailyLog({
    required String officeId,
    required String employeeId,
    required String employeeName,
    required String date,
    required double totalHours,
  }) async {
    final existing = await _dailyLogs
        .where('officeId', isEqualTo: officeId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isEqualTo: date)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return DailyLogModel.fromFirestore(existing.docs.first);
    }

    final doc = _dailyLogs.doc();
    final log = DailyLogModel(
      id: doc.id,
      officeId: officeId,
      employeeId: employeeId,
      employeeName: employeeName,
      date: date,
      totalHours: totalHours,
      distributedHours: 0,
      entries: [],
      isSubmitted: false,
      createdAt: DateTime.now(),
    );
    await doc.set(log.toFirestore());
    return log;
  }

  Stream<DailyLogModel?> watchDailyLog({
    required String officeId,
    required String employeeId,
    required String date,
  }) {
    return _dailyLogs
        .where('officeId', isEqualTo: officeId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isEqualTo: date)
        .limit(1)
        .snapshots()
        .map(
          (snap) => snap.docs.isEmpty
              ? null
              : DailyLogModel.fromFirestore(snap.docs.first),
        );
  }

  Future<void> updateLogEntries({
    required String logId,
    required List<DailyLogEntry> entries,
  }) async {
    final distributed = entries.fold(0.0, (sum, e) => sum + e.hours);
    await _dailyLogs.doc(logId).update({
      'entries': entries.map((e) => e.toMap()).toList(),
      'distributedHours': distributed,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    for (final entry in entries) {
      await _updateTaskActualHours(
        taskId: entry.taskId,
        logId: logId,
        hours: entry.hours,
      );
    }
  }

  Future<void> _updateTaskActualHours({
    required String taskId,
    required String logId,
    required double hours,
  }) async {
    final allLogs = await _dailyLogs
        .where('entries', arrayContains: {'taskId': taskId})
        .get();

    double total = 0;
    for (final doc in allLogs.docs) {
      final log = DailyLogModel.fromFirestore(doc);
      for (final entry in log.entries) {
        if (entry.taskId == taskId) total += entry.hours;
      }
    }
    await _tasks.doc(taskId).update({'actualHours': total});
  }

  Stream<List<DailyLogModel>> watchMonthlyLogs({
    required String officeId,
    required String employeeId,
    required String monthPrefix,
  }) {
    return _dailyLogs
        .where('officeId', isEqualTo: officeId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isGreaterThanOrEqualTo: '$monthPrefix-01')
        .where('date', isLessThanOrEqualTo: '$monthPrefix-31')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(DailyLogModel.fromFirestore).toList());
  }
}
