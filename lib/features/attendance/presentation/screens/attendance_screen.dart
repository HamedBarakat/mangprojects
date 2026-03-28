import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/home/presentation/controllers/home_providers.dart';
import '../../data/models/attendance_model.dart';
import '../controllers/attendance_providers.dart';
import '../../../projects/presentation/screens/daily_log_screen.dart';
import '../../../projects/presentation/controllers/task_providers.dart';
import '../../../../core/theme/app_theme.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;
    final isAdmin = user?.isAdmin ?? false;
    final canSeeAll = isAdmin || (user?.isManagement ?? false);

    return Scaffold(
      backgroundColor: AppColors.slate900,
      appBar: AppBar(
        backgroundColor: AppColors.slate850,
        automaticallyImplyLeading: false,
        title: const Text('Attendance'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.slate700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            color: AppColors.slate300,
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
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TodayCard(),
            const SizedBox(height: 24),
            if (canSeeAll) ...[_TodayAllSection(), const SizedBox(height: 24)],
            _SectionHeader(title: 'This Month'),
            const SizedBox(height: 12),
            _MonthlyStatsRow(),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Records'),
            const SizedBox(height: 12),
            _MonthlyRecordsList(),
          ],
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(color: AppColors.cyan500, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: AppColors.slate100, fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }
}

// ── Overtime Badge ────────────────────────────────────────────────────────────

class _OvertimeBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingOvertimeCountProvider);
    if (count == 0) return const SizedBox.shrink();

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.more_time_rounded, color: AppColors.slate300),
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => _OvertimeRequestsSheet(),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
            child: Text('$count',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

// ── Month Picker ──────────────────────────────────────────────────────────────

class _MonthPickerButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMonthProvider);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return TextButton.icon(
      icon: const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.cyan400),
      label: Text(
        '${months[selected.month - 1]} ${selected.year}',
        style: const TextStyle(color: AppColors.cyan400, fontSize: 13),
      ),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selected,
          firstDate: DateTime(2024),
          lastDate: DateTime.now(),
          initialDatePickerMode: DatePickerMode.year,
        );
        if (picked != null) {
          ref.read(selectedMonthProvider.notifier).state = DateTime(picked.year, picked.month);
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
    final now = DateTime.now();
    final todayAsync = ref.watch(todayRecordProvider);
    final user = ref.watch(currentUserProvider).value;

    final record = todayAsync.value;
    final isCheckedIn = record != null;
    final isCheckedOut = record?.isCheckedOut ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: AppDecorations.heroBanner(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today_rounded, color: Colors.white54, size: 14),
              const SizedBox(width: 6),
              Text(_formatDate(now), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),

          if (isCheckedIn)
            Row(
              children: [
                _TimeInfo(label: 'Check In', time: _formatTime(record.checkIn), icon: Icons.login_rounded),
                if (isCheckedOut) ...[
                  const SizedBox(width: 24),
                  _TimeInfo(label: 'Check Out', time: _formatTime(record.checkOut!), icon: Icons.logout_rounded),
                  const SizedBox(width: 24),
                  _TimeInfo(label: 'Duration', time: record.workDurationLabel, icon: Icons.timer_outlined),
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
                letterSpacing: 3,
              ),
            ),

          const SizedBox(height: 14),
          if (isCheckedIn) _StatusChip(status: record.status),
          const SizedBox(height: 18),

          if (_loading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (!isCheckedIn)
            _ActionButton(label: 'Check In', icon: Icons.login_rounded, filled: true, onTap: () => _doCheckIn(user))
          else if (!isCheckedOut)
            _ActionButton(label: 'Check Out', icon: Icons.logout_rounded, filled: false, onTap: () => _doCheckOut(user, record.id))
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.cyan300),
                const SizedBox(width: 8),
                const Text('Done for today!', style: TextStyle(color: Colors.white70)),
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
      await ref.read(attendanceRepositoryProvider).checkIn(
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
      final isOvertime = await ref.read(attendanceRepositoryProvider)
          .checkOut(officeId: user.officeId, recordId: recordId);

      final record = ref.read(todayRecordProvider).value;
      if (record != null) {
        final totalHours = record.checkOut!.difference(record.checkIn).inMinutes / 60;
        await ref.read(taskRepositoryProvider).getOrCreateDailyLog(
          officeId: user.officeId,
          employeeId: user.uid,
          employeeName: user.name,
          date: _dateKey(DateTime.now()),
          totalHours: totalHours,
        );
      }

      if (mounted && isOvertime) _showOvertimeDialog(user, recordId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showOvertimeDialog(user, String recordId) {
    final record = ref.read(todayRecordProvider).value;
    if (record == null) return;
    final extraHours = (DateTime.now().difference(record.checkIn).inMinutes / 60).toStringAsFixed(1);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Overtime Detected'),
        content: Text('You worked ~$extraHours extra hrs after end of shift.\n\nSubmit an overtime request for admin approval?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No Thanks')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(attendanceRepositoryProvider).requestOvertime(
                officeId: user.officeId,
                employeeId: user.uid,
                employeeName: user.name,
                attendanceRecordId: recordId,
                date: _dateKey(DateTime.now()),
                extraHours: double.tryParse(extraHours) ?? 0,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Overtime request sent to admin')),
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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ── Today All Section ─────────────────────────────────────────────────────────

class _TodayAllSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAllAsync = ref.watch(todayAllAttendanceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: "Today's Attendance"),
        const SizedBox(height: 12),
        todayAllAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.cyan500)),
          error: (_, _) => const Text('Error loading', style: TextStyle(color: AppColors.error)),
          data: (records) {
            if (records.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: AppDecorations.card(),
                child: const Text(
                  'No check-ins yet today',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.slate400),
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
    final statsAsync = ref.watch(myMonthlyStatsProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.cyan500)),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) => Row(
        children: [
          Expanded(child: _SummaryCard(label: 'Present', value: '${stats['present'] ?? 0}', icon: Icons.check_circle_outline_rounded, color: AppColors.success)),
          const SizedBox(width: 10),
          Expanded(child: _SummaryCard(label: 'Late', value: '${stats['late'] ?? 0}', icon: Icons.watch_later_outlined, color: AppColors.warning)),
          const SizedBox(width: 10),
          Expanded(child: _SummaryCard(label: 'Absent', value: '${stats['absent'] ?? 0}', icon: Icons.cancel_outlined, color: AppColors.error)),
        ],
      ),
    );
  }
}

// ── Monthly Records List ──────────────────────────────────────────────────────

class _MonthlyRecordsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(myMonthlyRecordsProvider);

    return recordsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.cyan500)),
      error: (_, _) => const Text('Error loading records', style: TextStyle(color: AppColors.error)),
      data: (records) {
        if (records.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: AppDecorations.card(),
            child: const Column(
              children: [
                Icon(Icons.access_time_rounded, size: 48, color: AppColors.slate600),
                SizedBox(height: 8),
                Text('No records this month', style: TextStyle(color: AppColors.slate400)),
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
    final statusColor = _statusColor(record.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppDecorations.card(),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: statusColor.withOpacity(0.5), blurRadius: 4)]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.employeeName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.slate100)),
                Text(record.date,
                    style: const TextStyle(color: AppColors.slate500, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatTime(record.checkIn),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.slate200)),
              Text(record.checkOut != null ? _formatTime(record.checkOut!) : '—',
                  style: const TextStyle(color: AppColors.slate500, fontSize: 11)),
            ],
          ),
          const SizedBox(width: 10),
          _StatusChip(status: record.status),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'present': return AppColors.success;
      case 'late':    return AppColors.warning;
      case 'absent':  return AppColors.error;
      default:        return AppColors.slate400;
    }
  }

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ── Overtime Requests Sheet ───────────────────────────────────────────────────

class _OvertimeRequestsSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.slate600, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Overtime Requests',
                style: TextStyle(color: AppColors.slate100, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Container(height: 1, color: AppColors.slate700),
          Expanded(
            child: pendingAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.cyan500)),
              error: (_, _) => const Center(child: Text('Error loading')),
              data: (requests) {
                if (requests.isEmpty) {
                  return const Center(child: Text('No pending requests', style: TextStyle(color: AppColors.slate400)));
                }
                return ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final req = requests[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: AppDecorations.card(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req['employeeName'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate100)),
                          const SizedBox(height: 4),
                          Text('${req['date']}  •  ${req['extraHours']} hrs extra',
                              style: const TextStyle(color: AppColors.slate400, fontSize: 13)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async => ref.read(attendanceRepositoryProvider).respondToOvertime(
                                    requestId: req['id'], adminId: user?.uid ?? '', approved: false),
                                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () async => ref.read(attendanceRepositoryProvider).respondToOvertime(
                                    requestId: req['id'], adminId: user?.uid ?? '', approved: true),
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
  const _TimeInfo({required this.label, required this.time, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white54, size: 12),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
        Text(time, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.cyan800,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
                padding: const EdgeInsets.symmetric(vertical: 14),
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
      case 'present': color = AppColors.success; label = 'Present'; break;
      case 'late':    color = AppColors.warning;  label = 'Late'; break;
      case 'absent':  color = AppColors.error;    label = 'Absent'; break;
      default:        color = AppColors.slate400;  label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
        ],
      ),
    );
  }
}
