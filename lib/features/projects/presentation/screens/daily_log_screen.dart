import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/controllers/home_providers.dart';
import '../../../projects/data/models/daily_log_model.dart';
import '../../../projects/data/models/task_model.dart';
import '../../../projects/data/task_repository.dart';
import '../../../projects/presentation/controllers/task_providers.dart';
import '../../../attendance/presentation/controllers/attendance_providers.dart';

class DailyLogScreen extends ConsumerStatefulWidget {
  const DailyLogScreen({super.key});

  @override
  ConsumerState<DailyLogScreen> createState() => _DailyLogScreenState();
}

class _DailyLogScreenState extends ConsumerState<DailyLogScreen> {
  final Map<String, double> _hoursMap = {}; // taskId → hours
  bool _saving = false;

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider).value;
    final logAsync = ref.watch(todayDailyLogProvider);
    final myTasksAsync = ref.watch(myTasksProvider);
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Log',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${today.day}/${today.month}/${today.year}',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
      body: logAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (log) {
          // لو مفيش log لليوم ده
          if (log == null) {
            return _CreateLogView(
              onCreateLog: () async {
                final user = ref.read(currentUserProvider).value;
                if (user == null) return;
                // جيب الـ attendance record الموجود
                final attendance = ref.read(todayRecordProvider).value;
                if (attendance == null) return;

                final totalHours = attendance.checkOut != null
                    ? attendance.checkOut!
                              .difference(attendance.checkIn)
                              .inMinutes /
                          60
                    : DateTime.now().difference(attendance.checkIn).inMinutes /
                          60;

                await ref
                    .read(taskRepositoryProvider)
                    .getOrCreateDailyLog(
                      officeId: user.officeId,
                      employeeId: user.uid,
                      employeeName: user.name,
                      date: _dateKey(DateTime.now()),
                      totalHours: totalHours,
                    );
              },
            );
          }

          // Initialize hours map from existing log
          if (_hoursMap.isEmpty && log.entries.isNotEmpty) {
            for (final entry in log.entries) {
              _hoursMap[entry.taskId] = entry.hours;
            }
          }

          final distributed = _hoursMap.values.fold(0.0, (s, h) => s + h);
          final remaining = log.totalHours - distributed;

          return myTasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (tasks) {
              // فلتر tasks اللي شغالة النهارده
              final activeTasks = tasks
                  .where(
                    (t) =>
                        t.status == 'in_progress' ||
                        t.status == 'not_started' ||
                        t.status == 'under_review',
                  )
                  .toList();

              return Column(
                children: [
                  // ── Summary Card ────────────────────────────────────
                  _SummaryCard(
                    totalHours: log.totalHours,
                    distributed: distributed,
                    remaining: remaining,
                  ),

                  // ── Tasks List ──────────────────────────────────────
                  Expanded(
                    child: activeTasks.isEmpty
                        ? _NoTasksView()
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: activeTasks.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _TaskHoursTile(
                              task: activeTasks[i],
                              hours: _hoursMap[activeTasks[i].id] ?? 0,
                              totalHours: log.totalHours,
                              remaining: remaining,
                              onChanged: (v) {
                                setState(() {
                                  _hoursMap[activeTasks[i].id] = v;
                                });
                              },
                            ),
                          ),
                  ),

                  // ── Save Button ─────────────────────────────────────
                  _SaveBar(
                    distributed: distributed,
                    totalHours: log.totalHours,
                    saving: _saving,
                    onSave: () => _save(log, activeTasks),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _save(DailyLogModel log, List<TaskModel> tasks) async {
    setState(() => _saving = true);
    try {
      final entries = _hoursMap.entries.where((e) => e.value > 0).map((e) {
        final task = tasks.firstWhere(
          (t) => t.id == e.key,
          orElse: () => tasks.first,
        );
        return DailyLogEntry(
          taskId: task.id,
          taskTitle: task.title,
          projectId: task.projectId,
          projectName: task.projectName,
          hours: e.value,
        );
      }).toList();

      await ref
          .read(taskRepositoryProvider)
          .updateLogEntries(logId: log.id, entries: entries);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily log saved ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double totalHours;
  final double distributed;
  final double remaining;

  const _SummaryCard({
    required this.totalHours,
    required this.distributed,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isComplete = remaining <= 0;
    final isOver = distributed > totalHours;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isComplete
            ? Colors.green.withOpacity(0.1)
            : isOver
            ? Colors.orange.withOpacity(0.1)
            : cs.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete
              ? Colors.green.withOpacity(0.3)
              : isOver
              ? Colors.orange.withOpacity(0.3)
              : cs.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _HourStat(
                  label: 'Total Hours',
                  value: totalHours,
                  color: cs.primary,
                ),
              ),
              Expanded(
                child: _HourStat(
                  label: 'Distributed',
                  value: distributed,
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: _HourStat(
                  label: isOver ? 'Over by' : 'Remaining',
                  value: remaining.abs(),
                  color: isOver ? Colors.orange : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: totalHours > 0
                  ? (distributed / totalHours).clamp(0.0, 1.0)
                  : 0,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                isComplete
                    ? Colors.green
                    : isOver
                    ? Colors.orange
                    : cs.primary,
              ),
              minHeight: 8,
            ),
          ),
          if (isComplete) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'All hours distributed!',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HourStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _HourStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${value.toStringAsFixed(1)}h',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: color.withOpacity(0.7), fontSize: 11),
        ),
      ],
    );
  }
}

// ── Task Hours Tile ───────────────────────────────────────────────────────────

class _TaskHoursTile extends StatelessWidget {
  final TaskModel task;
  final double hours;
  final double totalHours;
  final double remaining;
  final ValueChanged<double> onChanged;

  const _TaskHoursTile({
    required this.task,
    required this.hours,
    required this.totalHours,
    required this.remaining,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hours > 0
              ? cs.primary.withOpacity(0.3)
              : cs.outlineVariant.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.projectName,
                        style: TextStyle(
                          color: cs.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Hours display
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: hours > 0
                        ? cs.primary.withOpacity(0.1)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${hours.toStringAsFixed(1)}h',
                    style: TextStyle(
                      color: hours > 0
                          ? cs.primary
                          : cs.onSurface.withOpacity(0.4),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Slider
            Row(
              children: [
                const Text('0', style: TextStyle(fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: hours,
                    min: 0,
                    max: totalHours,
                    divisions: (totalHours * 2).toInt().clamp(1, 48),
                    onChanged: (v) {
                      // لا تسمح بتجاوز الساعات المتبقية
                      final maxAllowed = hours + remaining;
                      if (v <= maxAllowed || v < hours) {
                        onChanged(v);
                      }
                    },
                  ),
                ),
                Text(
                  '${totalHours.toStringAsFixed(0)}h',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),

            // Quick buttons
            Row(
              children: [
                _QuickBtn(label: '0.5h', onTap: () => _set(0.5)),
                _QuickBtn(label: '1h', onTap: () => _set(1)),
                _QuickBtn(label: '2h', onTap: () => _set(2)),
                _QuickBtn(label: '4h', onTap: () => _set(4)),
                _QuickBtn(label: '8h', onTap: () => _set(8)),
                const Spacer(),
                // Manual input button
                GestureDetector(
                  onTap: () => _showManualInput(context),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: cs.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _set(double v) {
    final maxAllowed = hours + remaining;
    if (v <= maxAllowed) onChanged(v);
  }

  void _showManualInput(BuildContext context) {
    final controller = TextEditingController(
      text: hours > 0 ? hours.toStringAsFixed(1) : '',
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Hours for "${task.title}"'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            suffixText: 'hours',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text);
              if (v != null) {
                final maxAllowed = hours + remaining;
                if (v <= maxAllowed) {
                  onChanged(v);
                }
              }
              Navigator.pop(context);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Save Bar ──────────────────────────────────────────────────────────────────

class _SaveBar extends StatelessWidget {
  final double distributed;
  final double totalHours;
  final bool saving;
  final VoidCallback onSave;

  const _SaveBar({
    required this.distributed,
    required this.totalHours,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded),
          label: Text(saving ? 'Saving...' : 'Save Daily Log'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty States ──────────────────────────────────────────────────────────────

class _NoAttendanceView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.login_rounded,
            size: 64,
            color: cs.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No attendance record for today',
            style: TextStyle(
              color: cs.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check in first to log your hours',
            style: TextStyle(
              color: cs.onSurface.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoTasksView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_outlined,
            size: 64,
            color: cs.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No active tasks today',
            style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }
}

class _CreateLogView extends StatelessWidget {
  final VoidCallback onCreateLog;
  const _CreateLogView({required this.onCreateLog});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.edit_note_rounded,
            size: 64,
            color: cs.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No log for today yet',
            style: TextStyle(
              color: cs.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreateLog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Daily Log'),
          ),
        ],
      ),
    );
  }
}
