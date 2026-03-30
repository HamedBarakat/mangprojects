import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/controllers/home_providers.dart';
import '../controllers/notification_providers.dart';
import '../../../projects/presentation/screens/project_details_screen.dart';
import '../../../projects/presentation/controllers/project_providers.dart';
import '../../../../core/theme/app_theme.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(myNotificationsProvider);
    final repo = ref.watch(notificationRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.slate900,
      appBar: AppBar(
        backgroundColor: AppColors.slate850,
        title: const Text('Notifications'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.slate700),
        ),
        actions: [
          notificationsAsync.maybeWhen(
            data: (notifs) => notifs.any((n) => !n.isRead)
                ? TextButton.icon(
                    icon: const Icon(Icons.done_all_rounded, size: 16, color: AppColors.cyan400),
                    label:  Text('Mark all read',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13)),
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
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: AppColors.error))),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.slate800,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).colorScheme.border),
                    ),
                    child:  Icon(
                      Icons.notifications_none_rounded,
                      size: 44,
                      color: Theme.of(context).colorScheme.subtleText,
                    ),
                  ),
                  const SizedBox(height: 16),
                   Text(
                    'No notifications yet',
                    style: TextStyle(color: Theme.of(context).colorScheme.subtleText, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                   Text(
                    'You\'re all caught up!',
                    style: TextStyle(color: Theme.of(context).colorScheme.subtleText, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final n = notifications[i];
              return Dismissible(
                key: Key(n.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                ),
                onDismissed: (_) => repo.deleteNotification(n.id),
                child: InkWell(
                  onTap: () async {
                    if (!n.isRead) await repo.markAsRead(n.id);
                    if (context.mounted && n.projectId != null) {
                      _openProject(context, ref, n.projectId!);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.isRead ? AppColors.slate800 : AppColors.cyan900.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: n.isRead ? AppColors.slate700 : AppColors.cyan800.withOpacity(0.5),
                        width: n.isRead ? 1 : 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NotifIcon(type: n.type, isRead: n.isRead),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n.title,
                                style: TextStyle(
                                  color: n.isRead ? AppColors.slate200 : AppColors.slate100,
                                  fontWeight: n.isRead ? FontWeight.w400 : FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n.body,
                                style: TextStyle(color: Theme.of(context).colorScheme.subtleText, fontSize: 12),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _timeAgo(n.createdAt),
                                style: TextStyle(color: Theme.of(context).colorScheme.subtleText, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
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

// ── Notification Icon ─────────────────────────────────────────────────────────

class _NotifIcon extends StatelessWidget {
  final String type;
  final bool isRead;
  const _NotifIcon({required this.type, required this.isRead});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (type) {
      case 'task_assigned':
        icon = Icons.assignment_ind_outlined;
        color = AppColors.cyan500;
        break;
      case 'task_status_change':
        icon = Icons.autorenew_rounded;
        color = AppColors.info;
        break;
      case 'task_comment':
        icon = Icons.comment_outlined;
        color = AppColors.warning;
        break;
      case 'task_submitted':
        icon = Icons.send_rounded;
        color = AppColors.success;
        break;
      default:
        icon = Icons.notifications_outlined;
        color = AppColors.cyan500;
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

// ── Bell Icon with Badge ──────────────────────────────────────────────────────

class NotificationBellIcon extends ConsumerWidget {
  const NotificationBellIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            count > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded,
            color: count > 0 ? AppColors.cyan400 : AppColors.slate400,
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
