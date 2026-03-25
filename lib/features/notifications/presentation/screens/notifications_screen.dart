import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/controllers/home_providers.dart';
import '../controllers/notification_providers.dart';
import '../../../projects/presentation/screens/project_details_screen.dart';
import '../../../projects/presentation/controllers/project_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final notificationsAsync = ref.watch(myNotificationsProvider);
    final repo = ref.watch(notificationRepositoryProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          notificationsAsync.maybeWhen(
            data: (notifs) => notifs.any((n) => !n.isRead)
                ? TextButton.icon(
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('Mark all read'),
                    onPressed: () async {
                      final user = ref.read(currentUserProvider).value;
                      if (user != null) await repo.markAllAsRead(user.uid);
                    },
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 64,
                    color: cs.onSurface.withOpacity(0.25),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.4),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, i) {
              final n = notifications[i];
              return Dismissible(
                key: Key(n.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: cs.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: cs.onErrorContainer,
                  ),
                ),
                onDismissed: (_) => repo.deleteNotification(n.id),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: _NotifIcon(type: n.type, isRead: n.isRead),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: n.isRead
                          ? FontWeight.normal
                          : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(n.body, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        _timeAgo(n.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                  tileColor: n.isRead
                      ? null
                      : cs.primaryContainer.withOpacity(0.18),
                  onTap: () async {
                    if (!n.isRead) await repo.markAsRead(n.id);
                    if (context.mounted && n.projectId != null) {
                      _openProject(context, ref, n.projectId!);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openProject(BuildContext context, WidgetRef ref, String projectId) {
    final projectAsync = ref.read(singleProjectProvider(projectId));
    final project = projectAsync.value;
    if (project == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProjectDetailsScreen(project: project)),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _NotifIcon extends StatelessWidget {
  final String type;
  final bool isRead;
  const _NotifIcon({required this.type, required this.isRead});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    IconData icon;
    Color color;
    switch (type) {
      case 'task_assigned':
        icon = Icons.assignment_ind_outlined;
        color = Colors.teal;
        break;
      case 'task_status_change':
        icon = Icons.autorenew_rounded;
        color = cs.primary;
        break;
      case 'task_comment':
        icon = Icons.comment_outlined;
        color = Colors.orange;
        break;
      case 'task_submitted':
        icon = Icons.send_rounded;
        color = Colors.green;
        break;
      default:
        icon = Icons.notifications_outlined;
        color = cs.primary;
    }

    return Stack(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, size: 20, color: color),
        ),
        if (!isRead)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Bell Icon مع Badge (للـ nav bar أو الـ AppBar) ──────────────────────────
class NotificationBellIcon extends ConsumerWidget {
  const NotificationBellIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final countAsync = ref.watch(unreadNotificationsCountProvider);
    final count = countAsync.value ?? 0;

    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            count > 0
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
            color: Colors.white,
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: count > 9 ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: count > 9 ? BorderRadius.circular(8) : null,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
