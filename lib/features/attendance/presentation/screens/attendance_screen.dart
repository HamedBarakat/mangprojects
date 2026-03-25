import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/home/presentation/controllers/home_providers.dart';
import '../../data/models/attendance_model.dart';
import '../controllers/attendance_providers.dart';
import '../../../projects/presentation/screens/daily_log_screen.dart';
import '../../../projects/data/task_repository.dart';
import '../../../projects/presentation/controllers/task_providers.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;
    final isAdmin = user?.isAdmin ?? false;
    final canSeeAll =
        isAdmin || (user?.isManagement ?? false); // management يشوف كل الحضور

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Attendance',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: 'Daily Log',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DailyLogScreen()),
            ),
          ),
          if (canSeeAll) _OvertimeBadge(),
          _MonthPickerButton(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TodayCard(),
            const SizedBox(height: 24),
            if (canSeeAll) ...[_TodayAllSection(), const SizedBox(height: 24)],
            Text(
              'This Month',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _MonthlyStatsRow(),
            const SizedBox(height: 24),
            Text(
              'Records',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _MonthlyRecordsList(),
          ],
        ),
      ),
    );
  }
}

// ── Overtime Badge (Admin) ─────────────────────────────────────────────────────

class _OvertimeBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingOvertimeCountProvider);
    if (count == 0) return const SizedBox.shrink();

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.more_time_rounded),
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => _OvertimeRequestsSheet(),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Month Picker ───────────────────────────────────────────────────────────────

class _MonthPickerButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMonthProvider);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return TextButton.icon(
      icon: const Icon(Icons.calendar_month_outlined, size: 18),
      label: Text('${months[selected.month - 1]} ${selected.year}'),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selected,
          firstDate: DateTime(2024),
          lastDate: DateTime.now(),
          initialDatePickerMode: DatePickerMode.year,
        );
        if (picked != null) {
          ref.read(selectedMonthProvider.notifier).state = DateTime(
            picked.year,
            picked.month,
          );
        }
      },
    );
  }
}

// ── Today Card ────────────────────────────────────────────────────────────────

class _TodayCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends ConsumerState<_TodayCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final todayAsync = ref.watch(todayRecordProvider);
    final user = ref.watch(currentUserProvider).value;

    final record = todayAsync.value;
    final isCheckedIn = record != null;
    final isCheckedOut = record?.isCheckedOut ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                _formatDate(now),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Times row
          if (isCheckedIn)
            Row(
              children: [
                _TimeInfo(
                  label: 'Check In',
                  time: _formatTime(record.checkIn),
                  icon: Icons.login_rounded,
                ),
                if (isCheckedOut) ...[
                  const SizedBox(width: 24),
                  _TimeInfo(
                    label: 'Check Out',
                    time: _formatTime(record.checkOut!),
                    icon: Icons.logout_rounded,
                  ),
                  const SizedBox(width: 24),
                  _TimeInfo(
                    label: 'Duration',
                    time: record.workDurationLabel,
                    icon: Icons.timer_outlined,
                  ),
                ],
              ],
            )
          else
            Text(
              _formatTime(now),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),

          const SizedBox(height: 12),
          if (isCheckedIn) _StatusChip(status: record.status),
          const SizedBox(height: 16),

          // Action button
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (!isCheckedIn)
            _ActionButton(
              label: 'Check In',
              icon: Icons.login_rounded,
              filled: true,
              onTap: () => _doCheckIn(user),
            )
          else if (!isCheckedOut)
            _ActionButton(
              label: 'Check Out',
              icon: Icons.logout_rounded,
              filled: false,
              onTap: () => _doCheckOut(user, record.id),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  'Done for today!',
                  style: TextStyle(color: Colors.white.withOpacity(0.85)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _doCheckIn(user) async {
    if (user == null) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .checkIn(
            officeId: user.officeId,
            employeeId: user.uid,
            employeeName: user.name,
            employeeCode: user.employeeCode ?? '',
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doCheckOut(user, String recordId) async {
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final isOvertime = await ref
          .read(attendanceRepositoryProvider)
          .checkOut(officeId: user.officeId, recordId: recordId);

      // ── Create Daily Log تلقائي بعد الـ Check Out ──────────
      final record = ref.read(todayRecordProvider).value;
      if (record != null) {
        final totalHours =
            record.checkOut!.difference(record.checkIn).inMinutes / 60;
        await ref
            .read(taskRepositoryProvider)
            .getOrCreateDailyLog(
              officeId: user.officeId,
              employeeId: user.uid,
              employeeName: user.name,
              date: _dateKey(DateTime.now()),
              totalHours: totalHours,
            );
      }
      // ────────────────────────────────────────────────────────

      if (mounted && isOvertime) _showOvertimeDialog(user, recordId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showOvertimeDialog(user, String recordId) {
    final record = ref.read(todayRecordProvider).value;
    if (record == null) return;
    final extraHours =
        (DateTime.now().difference(record.checkIn).inMinutes / 60)
            .toStringAsFixed(1);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Overtime Detected'),
        content: Text(
          'You worked ~$extraHours extra hrs after end of shift.\n\nSubmit an overtime request for admin approval?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No Thanks'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(attendanceRepositoryProvider)
                  .requestOvertime(
                    officeId: user.officeId,
                    employeeId: user.uid,
                    employeeName: user.name,
                    attendanceRecordId: recordId,
                    date: _dateKey(DateTime.now()),
                    extraHours: double.tryParse(extraHours) ?? 0,
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Overtime request sent to admin'),
                  ),
                );
              }
            },
            child: const Text('Request Overtime'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ── Today All Section (Admin) ─────────────────────────────────────────────────

class _TodayAllSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final todayAllAsync = ref.watch(todayAllAttendanceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Attendance",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        todayAllAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('Error loading'),
          data: (records) {
            if (records.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'No check-ins yet today',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _AttendanceRecordTile(record: records[i]),
            );
          },
        ),
      ],
    );
  }
}

// ── Monthly Stats Row ─────────────────────────────────────────────────────────

class _MonthlyStatsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(myMonthlyStatsProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) => Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'Present',
              value: '${stats['present'] ?? 0}',
              icon: Icons.check_circle_outline_rounded,
              color: Colors.green,
              cs: cs,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              label: 'Late',
              value: '${stats['late'] ?? 0}',
              icon: Icons.watch_later_outlined,
              color: Colors.orange,
              cs: cs,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              label: 'Absent',
              value: '${stats['absent'] ?? 0}',
              icon: Icons.cancel_outlined,
              color: Colors.red,
              cs: cs,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Monthly Records List ──────────────────────────────────────────────────────

class _MonthlyRecordsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final recordsAsync = ref.watch(myMonthlyRecordsProvider);

    return recordsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Text('Error loading records'),
      data: (records) {
        if (records.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 48,
                  color: cs.onSurface.withOpacity(0.25),
                ),
                const SizedBox(height: 8),
                Text(
                  'No records this month',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.45)),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: records.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _AttendanceRecordTile(record: records[i]),
        );
      },
    );
  }
}

// ── Attendance Record Tile ────────────────────────────────────────────────────

class _AttendanceRecordTile extends StatelessWidget {
  final AttendanceModel record;
  const _AttendanceRecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _statusColor(record.status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.employeeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  record.date,
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(record.checkIn),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                record.checkOut != null ? _formatTime(record.checkOut!) : '—',
                style: TextStyle(
                  color: cs.onSurface.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          _StatusChip(status: record.status),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ── Overtime Requests Sheet (Admin) ───────────────────────────────────────────

class _OvertimeRequestsSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final pendingAsync = ref.watch(pendingOvertimeProvider);
    final user = ref.watch(currentUserProvider).value;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Overtime Requests',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: pendingAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(child: Text('Error loading')),
              data: (requests) {
                if (requests.isEmpty) {
                  return Center(
                    child: Text(
                      'No pending requests',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                    ),
                  );
                }
                return ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: requests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final req = requests[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req['employeeName'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${req['date']}  •  ${req['extraHours']} hrs extra',
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    await ref
                                        .read(attendanceRepositoryProvider)
                                        .respondToOvertime(
                                          requestId: req['id'],
                                          adminId: user?.uid ?? '',
                                          approved: false,
                                        );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () async {
                                    await ref
                                        .read(attendanceRepositoryProvider)
                                        .respondToOvertime(
                                          requestId: req['id'],
                                          adminId: user?.uid ?? '',
                                          approved: true,
                                        );
                                  },
                                  child: const Text('Approve'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _TimeInfo extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  const _TimeInfo({
    required this.label,
    required this.time,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        Text(
          time,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'present':
        color = Colors.green;
        label = 'Present';
        break;
      case 'late':
        color = Colors.orange;
        label = 'Late';
        break;
      case 'absent':
        color = Colors.red;
        label = 'Absent';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final ColorScheme cs;
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
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
              color: cs.onSurface.withOpacity(0.55),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
