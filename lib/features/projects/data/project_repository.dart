import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/project_model.dart';
import 'models/task_model.dart';

class ProjectRepository {
  final _db = FirebaseFirestore.instance;

  // ── Projects ──────────────────────────────────────────────────────────────

  Stream<List<ProjectModel>> watchProjects(String officeId) {
    return _db
        .collection('projects')
        .where('officeId', isEqualTo: officeId)
        
        .snapshots()
        .map((snap) => snap.docs.map(ProjectModel.fromFirestore).toList());
  }

  // ── Watch single project real-time ────────────────────────────────────────
  Stream<ProjectModel?> watchSingleProject(String projectId) {
    return _db
        .collection('projects')
        .doc(projectId)
        .snapshots()
        .map((doc) => doc.exists ? ProjectModel.fromFirestore(doc) : null);
  }

  Future<ProjectModel?> getProject(String projectId) async {
    final doc = await _db.collection('projects').doc(projectId).get();
    if (!doc.exists) return null;
    return ProjectModel.fromFirestore(doc);
  }

  Future<String> addProject(Map<String, dynamic> data) async {
    final doc = await _db.collection('projects').add(data);
    return doc.id;
  }

  Future<void> updateProject(String projectId, Map<String, dynamic> data) async {
    await _db.collection('projects').doc(projectId).update(data);
  }

  Future<void> updateProjectCompletion(String projectId) async {
    final tasks = await _db
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .get();

    if (tasks.docs.isEmpty) return;

    double total = 0;
    for (final doc in tasks.docs) {
      total += (doc.data()['completionPercentage'] ?? 0).toDouble();
    }

    final avg = total / tasks.docs.length;
    await _db.collection('projects').doc(projectId).update({
      'completionPercentage': avg,
    });
  }

  Future<String> generateProjectCode(String officeId) async {
    final snap = await _db
        .collection('projects')
        .where('officeId', isEqualTo: officeId)
        .get();

    int maxNum = 0;
    for (final doc in snap.docs) {
      final code = doc.data()['projectCode'] as String? ?? '';
      if (code.startsWith('PRJ')) {
        final num = int.tryParse(code.substring(3)) ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }
    return 'PRJ${(maxNum + 1).toString().padLeft(3, '0')}';
  }

  // ── Tasks ─────────────────────────────────────────────────────────────────

  Stream<List<TaskModel>> watchTasks(String projectId) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(TaskModel.fromFirestore).toList();
          list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return list;
        });
  }

  Future<void> addTask(String projectId, Map<String, dynamic> data) async {
    await _db.collection('projects').doc(projectId).collection('tasks').add(data);
    await updateProjectCompletion(projectId);
  }

  Future<void> updateTask(String projectId, String taskId, Map<String, dynamic> data) async {
    await _db
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .doc(taskId)
        .update(data);
    await updateProjectCompletion(projectId);
  }

  Future<void> updateTaskCompletion(String projectId, String taskId, double percentage) async {
    await _db
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .doc(taskId)
        .update({'completionPercentage': percentage});
    await updateProjectCompletion(projectId);
  }
}
