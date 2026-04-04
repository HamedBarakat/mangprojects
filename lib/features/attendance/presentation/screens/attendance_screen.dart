import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/home/presentation/controllers/home_providers.dart';
import '../../data/models/attendance_model.dart';
import '../controllers/attendance_providers.dart';
import '../../../projects/presentation/screens/daily_log_screen.dart';
import '../../../projects/presentation/controllers/task_providers.dart';
import '../../../../core/theme/app_theme.dart';

// ── Team day provider (family) ────────────────────────────────────────────────
class _TeamDayKey {
  final String officeId;
  final String date;
  const _TeamDayKey(this.officeId, this.date);
  @override bool operator ==(Object o) => o is _TeamDayKey && o.officeId == officeId && o.date == date;
  @override int get hashCode => Object.hash(officeId, date);
}

final _teamDayProvider = StreamProvider.family<List<AttendanceModel>, _TeamDayKey>((ref, key) {
  return ref.watch(attendanceRepositoryProvider).watchDayAttendance(key.officeId, key.date);
});

// ── Root Screen ───────────────────────────────────────────────────────────────
class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final canSeeTeam = (user?.isAdmin ?? false) || (user?.isManagement ?? false);

    if (canSeeTeam) {
      return DefaultTabController(
        length: 2,
        child: _AttendanceScaffold(canSeeTeam: true),
      );
    }
    return _AttendanceScaffold(canSeeTeam: false);
  }
}

class _AttendanceScaffold extends ConsumerWidget {
  final bool canSeeTeam;
  const _AttendanceScaffold({required this.canSeeTeam});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Attendance'),
        bottom: canSeeTeam
            ? PreferredSize(
                preferredSize: const Size.fromHeight(49),
                child: Column(
                  children: [
                    Container(height: 1, color: cs.outlineVariant),
                    const TabBar(
                      tabs: [
                        Tab(text: 'My Attendance'),
                        Tab(text: 'Team'),
                      ],
                    ),
                  ],
                ),
              )
            : PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: cs.outlineVariant),
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
          if (canSeeTeam) _OvertimeBadge(),
          _MonthPickerButton(),
        ],
      ),
      body: canSeeTeam
          ? const TabBarView(
              children: [_MyAttendanceTab(), _TeamAttendanceTab()],
            )
          : const _MyAttendanceTab(),
    );
  }
}

// ── My Attendance Tab ─────────────────────────────────────────────────────────
class _MyAttendanceTab extends ConsumerWidget {
  const _MyAttendanceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CheckInCard(),
          const SizedBox(height: 20),
          _MonthlySummaryRow(),
          const SizedBox(height: 20),
          _SectionHeader(title: 'Monthly Record'),
          const SizedBox(height: 12),
          const _MonthlyAttendanceTable(),
        ],
      ),
    );
  }
}

// ── Team Attendance Tab ───────────────────────────────────────────────────────
class _TeamAttendanceTab extends ConsumerStatefulWidget {
  const _TeamAttendanceTab();

  @override
  ConsumerState<_TeamAttendanceTab> createState() => _TeamAttendanceTabState();
}

class _TeamAttendanceTabState extends ConsumerState<_TeamAttendanceTab> {
  DateTime _day = DateTime.now();

  String _dk(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final cs = Theme.of(context).colorScheme;

    final teamAsync = user == null
        ? const AsyncValue<List<AttendanceModel>>.loading()
        : ref.watch(_teamDayProvider(_TeamDayKey(user.officeId, _dk(_day))));

    const ms = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const ds = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final dayLabel = '${ds[_day.weekday - 1]}, ${_day.day} ${ms[_day.month - 1]} ${_day.year}';
    final isToday = _dk(_day) == _dk(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Day Navigator ──────────────────────────────────────────────────
          Row(
            children: [
              _NavArrow(
                icon: Icons.chevron_left_rounded,
                onTap: () => setState(() => _day = _day.subtract(const Duration(days: 1))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate: _day,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                    );
                    if (p != null) setState(() => _day = p);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: cs.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: cs.primary),
                        const SizedBox(width: 8),
                        Text(
                          isToday ? 'Today  ·  $dayLabel' : dayLabel,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _NavArrow(
                icon: Icons.chevron_right_rounded,
                onTap: isToday
                    ? null
                    : () => setState(() => _day = _day.add(const Duration(days: 1))),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Team List ──────────────────────────────────────────────────────
          teamAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorCard(message: e.toString()),
            data: (records) {
              if (records.isEmpty) {
                return _EmptyCard(
                  icon: Icons.people_outline_rounded,
                  message: 'No check-ins recorded for this day',
                );
              }
              final present = records.where((r) => r.status == 'present').length;
              final late = records.where((r) => r.status == 'late').length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      _StatChip('Present', '$present', AppColors.success),
                      _StatChip('Late', '$late', AppColors.warning),
                      _StatChip('Total', '${records.length}', cs.primary),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: records.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _TeamTile(record: records[i]),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Monthly Summary Row ───────────────────────────────────────────────────────
class _MonthlySummaryRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(myMonthlyRecordsProvider);

    return recordsAsync.when(
      loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
      error: (_, _) => const SizedBox.shrink(),
      data: (records) {
        final present = records.where((r) => r.status == 'present').length;
        final late = records.where((r) => r.status == 'late').length;
        final absent = records.where((r) => r.status == 'absent').length;
        final totalMin = records
            .where((r) => r.workDuration != null)
            .fold(0, (s, r) => s + r.workDuration!.inMinutes);
        final h = totalMin ~/ 60;
        final m = totalMin % 60;
        final hoursLabel = m > 0 ? '${h}h ${m}m' : '${h}h';

        return Row(
          children: [
            Expanded(child: _SummaryCard(label: 'Present', value: '$present', icon: Icons.check_circle_outline_rounded, color: AppColors.success)),
            const SizedBox(width: 8),
            Expanded(child: _SummaryCard(label: 'Late', value: '$late', icon: Icons.watch_later_outlined, color: AppColors.warning)),
            const SizedBox(width: 8),
            Expanded(child: _SummaryCard(label: 'Absent', value: '$absent', icon: Icons.cancel_outlined, color: AppColors.error)),
            const SizedBox(width: 8),
            Expanded(child: _SummaryCard(
              label: 'Hours',
              value: hoursLabel,
              icon: Icons.timer_outlined,
              color: Theme.of(context).colorScheme.primary,
            )),
          ],
        );
      },
    );
  }
}

// ── Monthly Attendance Table ──────────────────────────────────────────────────
class _MonthlyAttendanceTable extends ConsumerWidget {
  const _MonthlyAttendanceTable();

  static const _headers = ['Date', 'Day', 'In', 'Out', 'Duration', 'Status', 'OT'];
  static const _widths = [70.0, 46.0, 74.0, 74.0, 76.0, 86.0, 54.0];
  static const _hPad = 14.0;
  static double get _rowWidth => _widths.fold(0.0, (s, w) => s + w) + _hPad * 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(myMonthlyRecordsProvider);
    final month = ref.watch(selectedMonthProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return recordsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorCard(message: 'Failed to load records: ${e.toString()}'),
      data: (records) {
        final recordMap = <String, AttendanceModel>{for (final r in records) r.date: r};
        final now = DateTime.now();
        final today = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
        final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: cs.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _rowWidth,
              child: Column(
                children: [
                  // ── Header ───────────────────────────────────────────────
                  _buildHeader(cs),
                  Divider(height: 1, thickness: 1, color: cs.outlineVariant),
                  // ── Data rows (newest first) ──────────────────────────
                  ...List.generate(daysInMonth, (i) {
                    final dayNum = daysInMonth - i;
                    final date = DateTime(month.year, month.month, dayNum);
                    final dateStr = '${month.year}-${month.month.toString().padLeft(2,'0')}-${dayNum.toString().padLeft(2,'0')}';
                    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
                    final isFuture = dateStr.compareTo(today) > 0;
                    final isToday = dateStr == today;
                    final record = recordMap[dateStr];
                    return _TableDataRow(
                      date: date,
                      dateStr: dateStr,
                      record: record,
                      isWeekend: isWeekend,
                      isFuture: isFuture,
                      isToday: isToday,
                      isDark: isDark,
                      widths: _widths,
                      hPad: _hPad,
                      isLast: i == daysInMonth - 1,
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: 10),
      child: Row(
        children: List.generate(_headers.length, (i) => SizedBox(
          width: _widths[i],
          child: Text(
            _headers[i],
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.subtleText,
              letterSpacing: 0.3,
            ),
          ),
        )),
      ),
    );
  }
}

class _TableDataRow extends StatelessWidget {
  final DateTime date;
  final String dateStr;
  final AttendanceModel? record;
  final bool isWeekend;
  final bool isFuture;
  final bool isToday;
  final bool isDark;
  final List<double> widths;
  final double hPad;
  final bool isLast;

  const _TableDataRow({
    required this.date,
    required this.dateStr,
    required this.record,
    required this.isWeekend,
    required this.isFuture,
    required this.isToday,
    required this.isDark,
    required this.widths,
    required this.hPad,
    required this.isLast,
  });

  static const _ms = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static const _ds = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

  String _ft(DateTime? d) {
    if (d == null) return '—';
    return '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ── Row background ──────────────────────────────────────────────────────
    Color? rowBg;
    if (isWeekend) {
      rowBg = isDark ? Colors.white.withValues(alpha: 0.025) : Colors.black.withValues(alpha: 0.025);
    } else if (record != null && !isFuture) {
      final base = switch (record!.status) {
        'present' => AppColors.success,
        'late' => AppColors.warning,
        _ => AppColors.error,
      };
      rowBg = base.withValues(alpha: isDark ? 0.07 : 0.05);
    } else if (!isFuture && !isToday) {
      rowBg = AppColors.error.withValues(alpha: isDark ? 0.04 : 0.03);
    }

    // ── Status ──────────────────────────────────────────────────────────────
    final (statusLabel, statusColor) = _resolveStatus(cs);

    // ── Overtime ────────────────────────────────────────────────────────────
    String otLabel = '—';
    Color otColor = cs.subtleText;
    if (record?.workDuration != null) {
      final extra = record!.workDuration!.inMinutes - 480; // > 8h
      if (extra > 0) {
        final h = extra ~/ 60;
        final m = extra % 60;
        otLabel = h > 0 ? (m > 0 ? '${h}h ${m}m' : '${h}h') : '${m}m';
        otColor = AppColors.warning;
      }
    }

    // ── Text dim ────────────────────────────────────────────────────────────
    final dimText = isWeekend || isFuture;
    final textColor = dimText ? cs.subtleText : cs.onSurface;

    return Column(
      children: [
        Container(
          color: rowBg,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
            child: Row(
              children: [
                // Date
                SizedBox(
                  width: widths[0],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${date.day} ${_ms[date.month - 1]}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                          color: isToday ? cs.primary : textColor,
                        ),
                      ),
                      if (isToday)
                        Text('Today', style: TextStyle(fontSize: 9, color: cs.primary)),
                    ],
                  ),
                ),
                // Day
                SizedBox(
                  width: widths[1],
                  child: Text(
                    _ds[date.weekday - 1],
                    style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
                  ),
                ),
                // Check In
                SizedBox(
                  width: widths[2],
                  child: Text(
                    record != null ? _ft(record!.checkIn) : '—',
                    style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
                  ),
                ),
                // Check Out
                SizedBox(
                  width: widths[3],
                  child: Text(
                    _ft(record?.checkOut),
                    style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                  ),
                ),
                // Duration
                SizedBox(
                  width: widths[4],
                  child: Text(
                    record?.workDurationLabel ?? '—',
                    style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                  ),
                ),
                // Status badge
                SizedBox(
                  width: widths[5],
                  child: _buildStatusBadge(statusLabel, statusColor, cs),
                ),
                // OT
                SizedBox(
                  width: widths[6],
                  child: Text(
                    otLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: otColor,
                      fontWeight: otLabel != '—' ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, thickness: 0.5, color: cs.outlineVariant.withValues(alpha: 0.5)),
      ],
    );
  }

  Widget _buildStatusBadge(String label, Color color, ColorScheme cs) {
    if (isWeekend) {
      return Text(label, style: TextStyle(fontSize: 10, color: cs.subtleText));
    }
    if (isFuture || (isToday && record == null)) {
      return Text(label, style: TextStyle(fontSize: 10, color: color));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  (String, Color) _resolveStatus(ColorScheme cs) {
    if (isWeekend) return ('Weekend', cs.subtleText);
    if (isFuture) return ('—', cs.subtleText);
    if (isToday && record == null) return ('Pending', cs.primary);
    if (record == null) return ('Absent', AppColors.error);
    return switch (record!.status) {
      'present' => ('Present', AppColors.success),
      'late' => ('Late', AppColors.warning),
      _ => ('Absent', AppColors.error),
    };
  }
}

// ── Team Tile ─────────────────────────────────────────────────────────────────
class _TeamTile extends StatelessWidget {
  final AttendanceModel record;
  const _TeamTile({required this.record});

  String _ft(DateTime? d) {
    if (d == null) return '—';
    return '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = switch (record.status) {
      'present' => AppColors.success,
      'late' => AppColors.warning,
      _ => AppColors.error,
    };
    final statusLabel = switch (record.status) {
      'present' => 'Present',
      'late' => 'Late',
      _ => 'Absent',
    };
    final initials = record.employeeName.trim().split(' ')
        .take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppDecorations.cardOf(context),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials.isNotEmpty ? initials : '?',
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.employeeName,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurface),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _InfoChip(Icons.login_rounded, _ft(record.checkIn), cs.subtleText),
                    if (record.checkOut != null) ...[
                      const SizedBox(width: 10),
                      _InfoChip(Icons.logout_rounded, _ft(record.checkOut), cs.subtleText),
                      const SizedBox(width: 10),
                      _InfoChip(Icons.timer_outlined, record.workDurationLabel, cs.primary),
                    ],
                  ],
                ),
                if (record.hasLocation && record.checkInAddress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 11, color: cs.primary),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            record.checkInAddress!,
                            style: TextStyle(fontSize: 10, color: cs.primary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Check In Card ─────────────────────────────────────────────────────────────
class _CheckInCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends ConsumerState<_CheckInCard> {
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: AppDecorations.heroBannerOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date row ────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.today_rounded, color: Colors.white54, size: 14),
              const SizedBox(width: 6),
              Text(_fmtDate(now), style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const Spacer(),
              if (record?.hasLocation == true)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.white70, size: 12),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          record!.checkInAddress ?? 'Location saved',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Times ───────────────────────────────────────────────────────
          if (isCheckedIn)
            Wrap(
              spacing: 24,
              children: [
                _TimeInfo(label: 'Check In', time: _ft(record.checkIn), icon: Icons.login_rounded),
                if (isCheckedOut) ...[
                  _TimeInfo(label: 'Check Out', time: _ft(record.checkOut!), icon: Icons.logout_rounded),
                  _TimeInfo(label: 'Duration', time: record.workDurationLabel, icon: Icons.timer_outlined),
                ],
              ],
            )
          else
            Text(
              _ft(now),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),

          const SizedBox(height: 12),
          if (isCheckedIn) _StatusChip(status: record.status),

          if (_locationStatus != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white70, size: 13),
                const SizedBox(width: 4),
                Text(_locationStatus!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ],

          const SizedBox(height: 18),
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

  // ── Check In Logic ────────────────────────────────────────────────────────
  Future<void> _doCheckIn(user) async {
    if (user == null) return;
    setState(() { _loading = true; _locationStatus = null; });

    double? lat, lng;
    String? address;
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
        lat: lat, lng: lng, address: address,
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

  // ── Check Out Logic ───────────────────────────────────────────────────────
  Future<void> _doCheckOut(user, String recordId) async {
    if (user == null) return;
    setState(() => _loading = true);

    double? lat, lng;
    try {
      final pos = await ref.read(locationServiceProvider).getCurrentPosition();
      if (pos != null) { lat = pos['lat']; lng = pos['lng']; }
    } catch (_) {}

    try {
      final isOvertime = await ref
          .read(attendanceRepositoryProvider)
          .checkOut(officeId: user.officeId, recordId: recordId, lat: lat, lng: lng);

      final record = ref.read(todayRecordProvider).value;
      if (record != null && record.checkOut != null) {
        final totalHours = record.checkOut!.difference(record.checkIn).inMinutes / 60;
        await ref.read(taskRepositoryProvider).getOrCreateDailyLog(
          officeId: user.officeId,
          employeeId: user.uid,
          employeeName: user.name,
          date: _dk(DateTime.now()),
          totalHours: totalHours,
        );
      }
      if (mounted && isOvertime) _showOvertimeDialog(user, recordId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showOvertimeDialog(user, String recordId) {
    final record = ref.read(todayRecordProvider).value;
    if (record == null) return;
    final extra = (DateTime.now().difference(record.checkIn).inMinutes / 60).toStringAsFixed(1);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Overtime Detected'),
        content: Text('You worked ~$extra extra hours.\n\nSubmit an overtime request?'),
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
                date: _dk(DateTime.now()),
                extraHours: double.tryParse(extra) ?? 0,
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

  String _ft(DateTime d) =>
      '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  String _fmtDate(DateTime d) {
    const ms = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const ds = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${ds[d.weekday-1]}, ${d.day} ${ms[d.month-1]} ${d.year}';
  }
  String _dk(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
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
            context: context,
            isScrollControlled: true,
            builder: (_) => _OvertimeSheet(),
          ),
        ),
        Positioned(
          top: 8, right: 8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
            child: Text(
              '$count',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
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
    const ms = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final cs = Theme.of(context).colorScheme;
    return TextButton.icon(
      icon: Icon(Icons.calendar_month_outlined, size: 16, color: cs.primary),
      label: Text(
        '${ms[selected.month - 1]} ${selected.year}',
        style: TextStyle(color: cs.primary, fontSize: 13),
      ),
      onPressed: () async {
        final p = await showDatePicker(
          context: context,
          initialDate: selected,
          firstDate: DateTime(2024),
          lastDate: DateTime.now(),
          initialDatePickerMode: DatePickerMode.year,
        );
        if (p != null) {
          ref.read(selectedMonthProvider.notifier).state = DateTime(p.year, p.month);
        }
      },
    );
  }
}

// ── Overtime Requests Sheet ───────────────────────────────────────────────────
class _OvertimeSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingOvertimeProvider);
    final user = ref.watch(currentUserProvider).value;
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Overtime Requests',
              style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          Expanded(
            child: pendingAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(child: Text('Error loading')),
              data: (reqs) {
                if (reqs.isEmpty) {
                  return Center(
                    child: Text('No pending requests', style: TextStyle(color: cs.subtleText)),
                  );
                }
                return ListView.separated(
                  controller: ctrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: reqs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final req = reqs[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: AppDecorations.cardOf(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req['employeeName'] ?? '',
                            style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${req['date']}  •  ${req['extraHours']} hrs extra',
                            style: TextStyle(color: cs.subtleText, fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => ref
                                      .read(attendanceRepositoryProvider)
                                      .respondToOvertime(
                                          requestId: req['id'],
                                          adminId: user?.uid ?? '',
                                          approved: false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(color: AppColors.error),
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => ref
                                      .read(attendanceRepositoryProvider)
                                      .respondToOvertime(
                                          requestId: req['id'],
                                          adminId: user?.uid ?? '',
                                          approved: true),
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

// ══════════════════════════════════════════════════════════════════════════════
// Shared Small Widgets
// ══════════════════════════════════════════════════════════════════════════════

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

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: AppDecorations.cardOf(context),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.subtleText, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavArrow({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.border),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onTap,
        color: onTap != null ? cs.onSurface : cs.subtleText,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 12))),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: AppDecorations.cardOf(context),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.subtleText),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.subtleText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

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
    final (label, color) = switch (status) {
      'present' => ('Present', AppColors.success),
      'late' => ('Late', AppColors.warning),
      _ => ('Absent', AppColors.error),
    };
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
