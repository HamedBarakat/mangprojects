import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';
import '../../../attendance/data/models/attendance_model.dart';
import '../../../attendance/presentation/screens/attendance_screen.dart';
import '../../../leaves/data/models/leave_request_model.dart';
import '../../../leaves/data/leave_repository.dart';
import '../../../leaves/presentation/screens/leaves_screen.dart';
import '../../../notifications/data/models/notification_model.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../projects/presentation/screens/my_tasks_screen.dart';
import '../../../projects/presentation/controllers/task_providers.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Section header — matches the style used in _DashboardTab
// ══════════════════════════════════════════════════════════════════════════════

class DashSectionHeader extends StatelessWidget {
  final String title;
  const DashSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

// ── Small tap-card wrapper ────────────────────────────────────────────────────
class _TapCard extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _TapCard({this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: cs.primary.withOpacity(0.08),
      child: Container(
        decoration: AppDecorations.cardOf(context, radius: 12),
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// A — Attendance Card
// ══════════════════════════════════════════════════════════════════════════════

class AttendanceDashCard extends StatelessWidget {
  final UserModel user;
  const AttendanceDashCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final today = _todayString();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('employeeId', isEqualTo: user.uid)
          .where('date', isEqualTo: today)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _TapCard(
            child: const SizedBox(
              height: 48,
              child: Center(child: LinearProgressIndicator()),
            ),
          );
        }

        AttendanceModel? record;
        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          record = AttendanceModel.fromFirestore(snap.data!.docs.first);
        }

        String statusText;
        Color dotColor;
        if (record == null) {
          statusText = 'Not checked in yet';
          dotColor = Colors.amber;
        } else if (!record.isCheckedOut) {
          final t = record.checkIn;
          statusText =
              'Checked in at ${_fmt(t)}';
          dotColor = Colors.green;
        } else {
          final t = record.checkOut!;
          statusText = 'Checked out at ${_fmt(t)}';
          dotColor = Colors.grey;
        }

        return _TapCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AttendanceScreen()),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: dotColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.access_time_rounded, color: dotColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Attendance Today',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: TextStyle(fontSize: 12, color: dotColor),
                    ),
                  ],
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ══════════════════════════════════════════════════════════════════════════════
// B — Leaves Section  (balance card + pending request card, side by side)
// ══════════════════════════════════════════════════════════════════════════════

class LeavesDashSection extends StatelessWidget {
  final UserModel user;
  const LeavesDashSection({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _LeaveBalanceCard(user: user)),
        const SizedBox(width: 12),
        Expanded(child: _PendingLeaveCard(user: user)),
      ],
    );
  }
}

// ── Leave Balance card ────────────────────────────────────────────────────────
class _LeaveBalanceCard extends StatelessWidget {
  final UserModel user;
  const _LeaveBalanceCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('leaveBalances')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        int remaining = user.annualLeaveDays;
        if (snap.hasData && snap.data!.exists) {
          final d = snap.data!.data() as Map<String, dynamic>?;
          remaining = (d?['remainingDays'] as num?)?.toInt() ??
              (d?['remaining'] as num?)?.toInt() ??
              user.annualLeaveDays;
        }

        return _TapCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LeavesScreen()),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.beach_access_rounded,
                  color: cs.primary, size: 20),
              const SizedBox(height: 8),
              Text(
                '$remaining',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Leave Balance',
                style: TextStyle(
                    fontSize: 11, color: cs.subtleText),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Pending Leave Request card ────────────────────────────────────────────────
class _PendingLeaveCard extends StatelessWidget {
  final UserModel user;
  const _PendingLeaveCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('leave_requests')
          .where('employeeId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        LeaveRequestModel? pending;
        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          pending =
              LeaveRequestModel.fromFirestore(snap.data!.docs.first);
        }

        final bool loading = snap.connectionState == ConnectionState.waiting;

        return _TapCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LeavesScreen()),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.hourglass_top_rounded,
                  color: Colors.amber, size: 20),
              const SizedBox(height: 8),
              loading
                  ? const LinearProgressIndicator()
                  : pending == null
                      ? Text(
                          'No pending\nrequests',
                          style: TextStyle(
                              fontSize: 12, color: cs.subtleText),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pending.typeLabel,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_fmtDate(pending.startDate)} → ${_fmtDate(pending.endDate)}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.amber.shade700),
                            ),
                          ],
                        ),
            ],
          ),
        );
      },
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day} ${_monthAbbr(d.month)}';

  String _monthAbbr(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}

// ══════════════════════════════════════════════════════════════════════════════
// C — Approvals Card  (only shown if count > 0)
// ══════════════════════════════════════════════════════════════════════════════

class ApprovalsDashCard extends StatelessWidget {
  final UserModel user;
  const ApprovalsDashCard({super.key, required this.user});

  bool get _canApprove =>
      user.isAdmin ||
      user.isManagement ||
      LeaveRepository.isApproverJobTitle(user.jobTitle);

  @override
  Widget build(BuildContext context) {
    if (!_canApprove) return const SizedBox.shrink();

    // Build the query depending on whether the user is admin/management
    // (sees all pending in their office) or a specific approver by job title.
    Query query = FirebaseFirestore.instance
        .collection('leave_requests')
        .where('officeId', isEqualTo: user.officeId)
        .where('status', isEqualTo: 'pending');

    if (!user.isAdmin && !user.isManagement) {
      query = query.where(
          'currentApproverJobTitle', isEqualTo: user.jobTitle);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final count = snap.data!.docs.length;
        if (count == 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _TapCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeavesScreen()),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.assignment_turned_in_outlined,
                      color: Colors.amber, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$count leave request${count == 1 ? '' : 's'} awaiting your approval',
                    style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.amber, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// D — My Tasks Section  (3 mini count cards)
// ══════════════════════════════════════════════════════════════════════════════

class MyTasksDashSection extends ConsumerWidget {
  final UserModel user;
  const MyTasksDashSection({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(myTasksProvider);

    return tasksAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: LinearProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (tasks) {
        final todo =
            tasks.where((t) => t.status == 'not_started').length;
        final inProgress =
            tasks.where((t) => t.status == 'in_progress').length;
        final done =
            tasks.where((t) => t.status == 'completed').length;

        return Row(
          children: [
            Expanded(
              child: _MiniTaskCard(
                icon: Icons.list_alt_rounded,
                label: 'To Do',
                count: todo,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniTaskCard(
                icon: Icons.autorenew_rounded,
                label: 'In Progress',
                count: inProgress,
                color: Colors.amber,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniTaskCard(
                icon: Icons.check_circle_outline_rounded,
                label: 'Done',
                count: done,
                color: AppColors.success,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniTaskCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _MiniTaskCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _TapCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyTasksScreen()),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.subtleText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// E — Recent Notifications  (last 3)
// ══════════════════════════════════════════════════════════════════════════════

class RecentNotificationsDashSection extends StatelessWidget {
  final UserModel user;
  const RecentNotificationsDashSection({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No recent notifications',
              style: TextStyle(color: cs.subtleText, fontSize: 13),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final n = NotificationModel.fromFirestore(doc);
            final ago = _timeAgo(n.createdAt);
            return InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationsScreen()),
              ),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconForType(n.type),
                        color: cs.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (n.body.isNotEmpty)
                            Text(
                              n.body,
                              style: TextStyle(
                                  fontSize: 11, color: cs.subtleText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(ago,
                        style: TextStyle(
                            fontSize: 10, color: cs.subtleText)),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'task_assigned':
        return Icons.assignment_ind_outlined;
      case 'task_status_change':
        return Icons.swap_horiz_rounded;
      case 'task_comment':
        return Icons.comment_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }
}
