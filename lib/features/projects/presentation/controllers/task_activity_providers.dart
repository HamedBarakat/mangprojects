import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/task_activity_model.dart';
import '../../data/repositories/task_activity_repository.dart';

final taskActivityRepositoryProvider = Provider(
  (ref) => TaskActivityRepository(),
);

final taskActivitiesProvider =
    StreamProvider.family<List<TaskActivity>, String>((ref, taskId) {
      final repo = ref.watch(taskActivityRepositoryProvider);
      return repo.watchActivities(taskId).map((list) {
        final sorted = list.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return sorted;
      });
    });
