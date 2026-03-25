import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/task_activity_providers.dart';

class TaskActivityWidget extends ConsumerWidget {
  final String taskId;

  const TaskActivityWidget({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(taskActivitiesProvider(taskId));

    return activitiesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),

      error: (e, _) {
        final errorText = e.toString();

        debugPrint('🔥 FIRESTORE ERROR START');
        debugPrint(errorText);
        debugPrint('🔥 FIRESTORE ERROR END');

        final match = RegExp(r'https://[^\s]+').firstMatch(errorText);
        final url = match?.group(0);

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Firestore index required',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (url != null)
                ElevatedButton(
                  onPressed: () {
                    debugPrint('👉 INDEX LINK: $url');
                  },
                  child: const Text('Print Link'),
                ),
            ],
          ),
        );
      },

      data: (activities) {
        if (activities.isEmpty) {
          return const Center(child: Text('No activity yet'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final a = activities[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "[${a.userName}] - ${a.createdAt}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(a.type.toUpperCase()),
                  if (a.message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(a.message),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
