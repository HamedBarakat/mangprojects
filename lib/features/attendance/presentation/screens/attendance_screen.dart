import 'package:flutter/foundation.dart' show kIsWeb;
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
    final user = ref.watch(currentUserProvider).value;
    final canSeeAll = (user?.isAdmin ?? false) || (user?.isManagement ?? false);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Attendance'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: cs.outlineVariant),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: 'Daily Log',
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const DailyLogScreen()),
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
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 3, height: 16,
          decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 15)),
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
          icon: const Icon(Icons.more_time_rounded),
          onPressed: () => showModalBottomSheet(
            context: context, isScrollControlled: true,
            builder: (_) => _OvertimeRequestsSheet(),
          ),
        ),
        Positioned(
          top: 8, right: 8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final cs = Theme.of(context).colorScheme;

    return TextButton.icon(
      icon: Icon(Icons.calendar_month_outlined, size: 16, color: cs.primary),
      label: Text('${months[selected.month - 1]} ${selected.year}',
          style: TextStyle(color: cs.primary, fontSize: 13)),
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
  String? _locationStatus;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayAsync = ref.watch(todayRecordProvider);
    final user = ref.watch(currentUserProvider).value;

    final record = todayAsync.value;
    final isCheckedIn = record != null;
    final isCheckedOut = record?.isCheckedOut ?? false;
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: AppDecorations.heroBannerOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today_rounded, color: Colors.white54, size: 14),
              const SizedBox(width: 6),
              Text(_formatDate(now), style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const Spacer(),
              if (record?.hasLocation == true)
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: Colors.white70, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      record?.checkInAddress ?? 'Location saved',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
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
              style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: 3),
            ),

          const SizedBox(height: 14),
          if (isCheckedIn) _StatusChip(status: record.status),

          if (_locationStatus != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white70, size: 13),
                const SizedBox(width: 4),
                Text(_locationStatus!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ],

          const SizedBox(height: 18),

          if (_loading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (!isCheckedIn)
            _ActionButton(label: 'Check In', icon: Icons.login_rounded, filled: true, onTap: () => _doCheckIn(user))
          else if (!isCheckedOut)
            _ActionButton(label: 'Check Out', icon: Icons.logout_rounded, filled: false, onTap: () => _doCheckOut(user, record.id))
          else
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white70),
                SizedBox(width: 8),
                Text('Done for today!', style: TextStyle(color: Colors.white70)),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _doCheckIn(user) async {
    if (user == null) return;
    setState(() { _loading = true; _locationStatus = null; });

    double? lat, lng;
    String? address;

    // Try to get location (web uses browser geolocation)
    try {
      final pos = await ref.read(locationServiceProvider).getCurrentPosition();
      if (pos != null) {
        lat = pos['lat'];
        lng = pos['lng'];
        address = pos['address'];
        setState(() => _locationStatus = 'Location: ${address ?? 'saved'}');
      } else {
        setState(() => _locationStatus = 'Location not available');
      }
    } catch (_) {
      setState(() => _locationStatus = 'Location unavailable');
    }

    try {
      await ref.read(attendanceRepositoryProvider).checkIn(
        officeId: user.officeId,
        employeeId: user.uid,
        employeeName: user.name,
        employeeCode: user.employeeCode ?? '',
        lat: lat,
        lng: lng,
        address: address,
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

    double? lat, lng;
    try {
      final pos = await ref.read(locationServiceProvider).getCurrentPosition();
      if (pos != null) { lat = pos['lat']; lng = pos['lng']; }
    } catch (_) {}

    try {
      final isOvertime = await ref.read(attendanceRepositoryProvider)
          .checkOut(officeId: user.officeId, recordId: recordId, lat: lat, lng: lng);

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
        content: Text('You worked ~$extraHours extra hrs after end of shift.\n\nSubmit an overtime request?'),
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
                  const SnackBar(content: Text('Overtime request sent')),
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
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[d.weekday-1]}, ${d.day} ${months[d.month-1]} ${d.year}';
  }
  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('Error loading', style: TextStyle(color: AppColors.error)),
          data: (records) {
            if (records.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: AppDecorations.cardOf(context),
                child: Text('No check-ins yet today',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.subtleText)),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _AttendanceRecordTile(record: records[i], showName: true),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) => Row(
        children: [
          Expanded(child: _SummaryCard(label: 'Present', value: '${stats['present']??0}', icon: Icons.check_circle_outline_rounded, color: AppColors.success)),
          const SizedBox(width: 10),
          Expanded(child: _SummaryCard(label: 'Late', value: '${stats['late']??0}', icon: Icons.watch_later_outlined, color: AppColors.warning)),
          const SizedBox(width: 10),
          Expanded(child: _SummaryCard(label: 'Absent', value: '${stats['absent']??0}', icon: Icons.cancel_outlined, color: AppColors.error)),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Text('Error loading records', style: TextStyle(color: AppColors.error)),
      data: (records) {
        if (records.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: AppDecorations.cardOf(context),
            child: Column(
              children: [
                Icon(Icons.access_time_rounded, size: 48, color: Theme.of(context).colorScheme.subtleText),
                const SizedBox(height: 8),
                Text('No records this month', style: TextStyle(color: Theme.of(context).colorScheme.subtleText)),
              ],
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: records.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _AttendanceRecordTile(record: records[i], showName: false),
        );
      },
    );
  }
}

// ── Attendance Record Tile ────────────────────────────────────────────────────
class _AttendanceRecordTile extends StatelessWidget {
  final AttendanceModel record;
  final bool showName;
  const _AttendanceRecordTile({required this.record, required this.showName});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(record.status);
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppDecorations.cardOf(context),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: statusColor, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.4), blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showName)
                  Text(record.employeeName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurface)),
                Text(record.date, style: TextStyle(color: cs.subtleText, fontSize: 11)),
                if (record.hasLocation)
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 11, color: cs.primary),
                      const SizedBox(width: 2),
                      Text(
                        record.checkInAddress ?? 'Location recorded',
                        style: TextStyle(color: cs.primary, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmt(record.checkIn), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurface)),
              Text(record.checkOut != null ? _fmt(record.checkOut!) : '—',
                  style: TextStyle(color: cs.subtleText, fontSize: 11)),
              if (record.workDuration != null)
                Text(record.workDurationLabel, style: TextStyle(color: cs.primary, fontSize: 11)),
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
      default:        return AppColors.error;
    }
  }
  String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}

// ── Overtime Requests Sheet ───────────────────────────────────────────────────
class _OvertimeRequestsSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingOvertimeProvider);
    final user = ref.watch(currentUserProvider).value;
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.4, expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Overtime Requests', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          Expanded(
            child: pendingAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(child: Text('Error loading')),
              data: (requests) {
                if (requests.isEmpty) {
                  return Center(child: Text('No pending requests', style: TextStyle(color: cs.subtleText)));
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
                      decoration: AppDecorations.cardOf(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req['employeeName'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface)),
                          const SizedBox(height: 4),
                          Text('${req['date']}  •  ${req['extraHours']} hrs extra',
                              style: TextStyle(color: cs.subtleText, fontSize: 13)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => ref.read(attendanceRepositoryProvider).respondToOvertime(
                                      requestId: req['id'], adminId: user?.uid ?? '', approved: false),
                                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => ref.read(attendanceRepositoryProvider).respondToOvertime(
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
                foregroundColor: Theme.of(context).colorScheme.primary,
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
      default:        color = AppColors.error;    label = 'Absent';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
      decoration: AppDecorations.cardOf(context),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.subtleText, fontSize: 11)),
        ],
      ),
    );
  }
}
