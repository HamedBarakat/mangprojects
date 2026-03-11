import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/home/presentation/controllers/home_providers.dart';
import '../../../../features/home/data/models/user_model.dart';
import '../../../../features/office/presentation/controllers/office_providers.dart';
import '../../../../features/office/presentation/controllers/office_settings_providers.dart';
import '../../../../features/office/data/models/office_model.dart';
import '../../../../features/office/data/models/office_settings_model.dart';
import '../../../office/presentation/screens/office_lists_screen.dart';

// ── Office stream provider ────────────────────────────────────────────────────
final officeStreamProvider = StreamProvider<OfficeModel?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(officeRepositoryProvider).watchOffice(user.officeId);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;
    final officeAsync = ref.watch(officeStreamProvider);
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile Card ──────────────────────────────────────────────────
            _ProfileCard(user: user),

            const SizedBox(height: 24),

            // ── Office Settings (Admin only) ──────────────────────────────────
            if (isAdmin) ...[
              _SectionTitle('Office Settings'),
              const SizedBox(height: 12),

              // Work Hours
              officeAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error loading office settings'),
                data: (office) => _WorkHoursCard(
                  office: office,
                  officeId: user?.officeId ?? '',
                  ref: ref,
                ),
              ),
              const SizedBox(height: 12),

              // Manage Lists (projectTypes, disciplines, departments, taskCategories)
              _SettingsTile(
                icon: Icons.list_alt_rounded,
                label: 'Manage Lists',
                iconColor: Colors.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OfficeListsScreen()),
                ),
              ),
              const SizedBox(height: 12),

              // ── Job Titles Management ──────────────────────────────────────
              _SettingsTile(
                icon: Icons.work_outline_rounded,
                label: 'Manage Job Titles',
                iconColor: Colors.teal,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const JobTitlesManagementScreen(),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],

            // ── App Settings ──────────────────────────────────────────────────
            _SectionTitle('App'),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              label: 'App Version',
              trailing: Text(
                '1.0.0',
                style: TextStyle(
                  color: cs.onSurface.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Logout ────────────────────────────────────────────────────────
            _SectionTitle('Account'),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.logout_rounded,
              label: 'Logout',
              iconColor: Colors.red,
              labelColor: Colors.red,
              onTap: () async {
                final confirm = await _confirmLogout(context);
                if (confirm == true) {
                  await FirebaseAuth.instance.signOut();
                  await ref.read(localStorageProvider).clearAll();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmLogout(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Job Titles Management Screen — Firestore connected
// ══════════════════════════════════════════════════════════════════════════════

class JobTitlesManagementScreen extends ConsumerStatefulWidget {
  const JobTitlesManagementScreen({super.key});

  @override
  ConsumerState<JobTitlesManagementScreen> createState() =>
      _JobTitlesManagementScreenState();
}

class _JobTitlesManagementScreenState
    extends ConsumerState<JobTitlesManagementScreen> {
  List<_JobTitleGroupState> _groups = [];
  bool _initialized = false; // تحميل مرة واحدة بس بعد ما الـ data تجي
  bool _saving = false;

  void _initGroups(List<JobTitleGroup> source) {
    _groups = source.map((g) {
      return _JobTitleGroupState(
        title: g.title,
        entries: g.titles.entries
            .map((e) => _JobTitleEntry(key: e.key, label: e.value))
            .toList(),
      );
    }).toList();
    _initialized = true;
  }

  // ── Edit label ──────────────────────────────────────────────────────────────
  Future<void> _editEntry(int groupIdx, int entryIdx) async {
    final entry = _groups[groupIdx].entries[entryIdx];
    final ctrl = TextEditingController(text: entry.label);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Job Title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _groups[groupIdx].title,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Title Label',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _groups[groupIdx].entries[entryIdx] =
            _JobTitleEntry(key: entry.key, label: result);
      });
    }
  }

  // ── Add entry to group ──────────────────────────────────────────────────────
  Future<void> _addEntry(int groupIdx) async {
    final keyCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add to "${_groups[groupIdx].title}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Title Label (e.g. Senior Architect)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(
                labelText: 'Key (e.g. senior_architect)',
                helperText: 'Lowercase letters and underscores only',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (result == true &&
        labelCtrl.text.trim().isNotEmpty &&
        keyCtrl.text.trim().isNotEmpty) {
      setState(() {
        _groups[groupIdx].entries.add(_JobTitleEntry(
          key: keyCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
          label: labelCtrl.text.trim(),
        ));
      });
    }
  }

  // ── Add new group ───────────────────────────────────────────────────────────
  Future<void> _addGroup() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Group'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Group Name (e.g. Surveying)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _groups.add(_JobTitleGroupState(title: result, entries: []));
      });
    }
  }

  // ── Delete entry ────────────────────────────────────────────────────────────
  Future<void> _deleteEntry(int groupIdx, int entryIdx) async {
    final label = _groups[groupIdx].entries[entryIdx].label;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Job Title'),
        content: Text('Delete "$label"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _groups[groupIdx].entries.removeAt(entryIdx));
    }
  }

  // ── Save to Firestore ───────────────────────────────────────────────────────
  Future<void> _save() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final groupData = _groups.map((g) {
        return JobTitleGroupData(
          title: g.title,
          titles: {for (final e in g.entries) e.key: e.label},
        );
      }).toList();

      await ref
          .read(officeSettingsRepositoryProvider)
          .saveJobTitleGroups(officeId: user.officeId, groups: groupData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job titles saved ✓'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ✅ watch الـ provider — لما الـ data تجي نحمل الـ groups مرة واحدة
    final settingsAsync = ref.watch(officeSettingsProvider);
    settingsAsync.whenData((settings) {
      if (!_initialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_initialized) {
            setState(() => _initGroups(settings.effectiveJobTitleGroups));
          }
        });
      }
    });

    // Loading state
    if (!_initialized) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: cs.surface,
          elevation: 0,
          title: const Text('Manage Job Titles',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: const Text(
          'Manage Job Titles',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving...' : 'Save'),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: cs.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Customize job titles for your office. Press Save to apply changes.',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.7)),
                  ),
                ),
              ],
            ),
          ),

          // Groups
          for (int gi = 0; gi < _groups.length; gi++) ...[
            _GroupHeader(
              title: _groups[gi].title,
              onAdd: () => _addEntry(gi),
            ),
            const SizedBox(height: 8),
            for (int ei = 0; ei < _groups[gi].entries.length; ei++)
              _JobTitleTile(
                entry: _groups[gi].entries[ei],
                onEdit: () => _editEntry(gi, ei),
                onDelete: () => _deleteEntry(gi, ei),
              ),
            const SizedBox(height: 20),
          ],

          // Add new group button
          OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add New Group'),
            onPressed: _addGroup,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Local state classes ───────────────────────────────────────────────────────
class _JobTitleGroupState {
  String title;
  List<_JobTitleEntry> entries;
  _JobTitleGroupState({required this.title, required this.entries});
}

class _JobTitleEntry {
  final String key;
  final String label;
  const _JobTitleEntry({required this.key, required this.label});
}

// ── Group Header ──────────────────────────────────────────────────────────────
class _GroupHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  const _GroupHeader({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: cs.primary,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.add_circle_outline_rounded, color: cs.primary),
          onPressed: onAdd,
          tooltip: 'Add to $title',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

// ── Job Title Tile ────────────────────────────────────────────────────────────
class _JobTitleTile extends StatelessWidget {
  final _JobTitleEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _JobTitleTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Icon(
          Icons.work_outline_rounded,
          color: cs.primary.withOpacity(0.6),
          size: 20,
        ),
        title: Text(
          entry.label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          entry.key,
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurface.withOpacity(0.4),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  size: 18, color: cs.primary.withOpacity(0.7)),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile Card ──────────────────────────────────────────────────────────────

class _ProfileCard extends ConsumerWidget {
  final UserModel? user;
  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    // ✅ custom job titles من الـ office settings
    final customTitles = ref.watch(officeSettingsProvider).valueOrNull
        ?.effectiveJobTitles;
    final titleLabel = user?.jobTitleLabelFrom(customTitles) ?? '—';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_rounded, color: cs.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? '—',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  titleLabel,
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _roleColor(user?.role, cs).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user?.roleLabel ?? '—',
                    style: TextStyle(
                      color: _roleColor(user?.role, cs),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String? role, ColorScheme cs) {
    switch (role) {
      case 'admin':          return Colors.deepPurple;
      case 'engineer':       return cs.primary;
      case 'team_leader':    return Colors.teal;
      case 'reviewer':       return Colors.indigo;
      case 'management':     return Colors.brown;
      case 'administration': return Colors.blueGrey;
      case 'client':         return Colors.orange;
      default:               return Colors.grey;
    }
  }
}

// ── Work Hours Card ───────────────────────────────────────────────────────────

class _WorkHoursCard extends ConsumerStatefulWidget {
  final OfficeModel? office;
  final String officeId;
  final WidgetRef ref;

  const _WorkHoursCard({
    required this.office,
    required this.officeId,
    required this.ref,
  });

  @override
  ConsumerState<_WorkHoursCard> createState() => _WorkHoursCardState();
}

class _WorkHoursCardState extends ConsumerState<_WorkHoursCard> {
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startTime = _parseTime(widget.office?.workStartTime ?? '09:00');
    _endTime = _parseTime(widget.office?.workEndTime ?? '17:00');
  }

  @override
  void didUpdateWidget(_WorkHoursCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.office != widget.office) {
      _startTime = _parseTime(widget.office?.workStartTime ?? '09:00');
      _endTime = _parseTime(widget.office?.workEndTime ?? '17:00');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final workHours =
        _endTime.hour -
        _startTime.hour +
        (_endTime.minute - _startTime.minute) / 60;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.schedule_rounded, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Work Hours',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    '${workHours.toStringAsFixed(1)} hrs/day',
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _TimePicker(
                  label: 'Start Time',
                  icon: Icons.login_rounded,
                  time: _startTime,
                  color: Colors.green,
                  onTap: () => _pickTime(isStart: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimePicker(
                  label: 'End Time',
                  icon: Icons.logout_rounded,
                  time: _endTime,
                  color: cs.primary,
                  onTap: () => _pickTime(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_saving ? 'Saving...' : 'Save Work Hours'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      helpText: isStart ? 'Select Start Time' : 'Select End Time',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;

    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(officeRepositoryProvider).updateWorkHours(
            officeId: widget.officeId,
            workStartTime: _formatTime(_startTime),
            workEndTime: _formatTime(_endTime),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Work hours updated successfully ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ── Time Picker Tile ──────────────────────────────────────────────────────────

class _TimePicker extends StatelessWidget {
  final String label;
  final IconData icon;
  final TimeOfDay time;
  final Color color;
  final VoidCallback onTap;

  const _TimePicker({
    required this.label,
    required this.icon,
    required this.time,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Tap to change',
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.4),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? cs.onSurface.withOpacity(0.7),
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor ?? cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null) trailing!,
            if (onTap != null && trailing == null)
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurface.withOpacity(0.3),
              ),
          ],
        ),
      ),
    );
  }
}
