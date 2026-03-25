import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_activity_model.dart';

class TaskActivityRepository {
  final _firestore = FirebaseFirestore.instance;

  Stream<List<TaskActivity>> watchActivities(String taskId) {
    return _firestore
        .collection('task_activities')
        .where('taskId', isEqualTo: taskId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TaskActivity.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> addActivity(TaskActivity activity) async {
    print('🔥 ADDING ACTIVITY NOW');
    await _firestore.collection('task_activities').add(activity.toMap());
    print('✅ ACTIVITY ADDED');
  }
}
