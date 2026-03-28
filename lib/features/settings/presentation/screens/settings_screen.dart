import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mang_projects/features/auth/presentation/controllers/auth_providers.dart';

import '../../../../features/home/presentation/controllers/home_providers.dart';
import '../../../../features/home/data/models/user_model.dart';
import '../../../../features/office/presentation/controllers/office_providers.dart';
import '../../../../features/projects/presentation/controllers/project_providers.dart';
import '../../../../features/projects/presentation/controllers/task_providers.dart';
import '../../../../features/employees/presentation/controllers/employee_providers.dart';
import '../../../../features/notifications/presentation/controllers/notification_providers.dart';
import '../../../../features/office/presentation/controllers/office_settings_providers.dart';
import '../../../../features/office/data/models/office_model.dart';
import '../../../../features/office/data/models/office_settings_model.dart';
import '../../../office/presentation/screens/office_lists_screen.dart';
import '../../../../core/theme/app_theme.dart';

// ── Office stream provider ────────────────────────────────────────────────────
final officeStreamProvider = StreamProvider<OfficeModel?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(officeRepositoryProvider).watchOffice(user.officeId);
    },
    loading: () => const Stream.empty(),
    error: (_, _) => const Stream.empty(),
  );
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;
    final officeAsync = ref.watch(officeStreamProvider);
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.slate900,
      appBar: AppBar(
        backgroundColor: AppColors.slate850,
        automaticallyImplyLeading: false,
        title: const Text('Settings'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.slate700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile Card ────────────────────────────────────────────────
            _ProfileCard(user: user),
            const SizedBox(height: 28),

            // ── Office Settings (Admin only) ────────────────────────────────
            if (isAdmin) ...[
              _SectionHeader(title: 'Office Settings'),
              const SizedBox(height: 12),

              officeAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.cyan500),
                ),
                error: (_, _) => const Text(
                  'Error loading office settings',
                  style: TextStyle(color: AppColors.error),
                ),
                data: (office) => _WorkHoursCard(
                  office: office,
                  officeId: user?.officeId ?? '',
                  ref: ref,
                ),
              ),
              const SizedBox(height: 10),

              _SettingsTile(
                icon: Icons.list_alt_rounded,
                label: 'Manage Lists',
                iconColor: AppColors.info,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OfficeListsScreen()),
                ),
              ),
              const SizedBox(height: 10),

              _SettingsTile(
                icon: Icons.work_outline_rounded,
                label: 'Manage Job Titles',
                iconColor: AppColors.cyan500,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const JobTitlesManagementScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // ── App ─────────────────────────────────────────────────────────
            _SectionHeader(title: 'App'),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              label: 'App Version',
              iconColor: AppColors.slate400,
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.slate700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '1.0.0',
                  style: TextStyle(color: AppColors.slate300, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Account ──────────────────────────────────────────────────────
            _SectionHeader(title: 'Account'),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              label: 'Change Password',
              iconColor: AppColors.warning,
              onTap: () => showDialog(
                context: context,
                builder: (_) => const _ChangePasswordDialog(),
              ),
            ),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.logout_rounded,
              label: 'Logout',
              iconColor: AppColors.error,
              labelColor: AppColors.error,
              onTap: () async {
                final confirm = await _confirmLogout(context);
                if (confirm == true) {
                  // Invalidate ALL providers so all Firestore streams stop cleanly
                  ref.invalidate(currentUserProvider);
                  ref.invalidate(projectsProvider);
                  ref.invalidate(singleProjectProvider);
                  ref.invalidate(allVisibleTasksProvider);
                  ref.invalidate(projectTasksProvider);
                  ref.invalidate(projectTaskStatsProvider);
                  ref.invalidate(teamLeaderReviewTasksProvider);
                  ref.invalidate(qcReviewTasksProvider);
                  ref.invalidate(unreadNotificationsCountProvider);
                  ref.invalidate(employeesProvider);
                  // Clear local storage and office
                  await ref.read(localStorageProvider).clearAll();
                  await ref.read(selectedOfficeProvider.notifier).clearOffice();
                  // Sign out — authStateChanges fires → AuthWrapper shows LoginScreen
                  ref.invalidate(authStateProvider);
                  await FirebaseAuth.instance.signOut();
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
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
            SizedBox(width: 8),
            Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Job Titles Management Screen
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
  bool _initialized = false;
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
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.cyan500,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Title Label'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _groups[groupIdx].entries[entryIdx] = _JobTitleEntry(
          key: entry.key,
          label: result,
        );
      });
    }
  }

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
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(
                labelText: 'Key (e.g. senior_architect)',
                helperText: 'Lowercase letters and underscores only',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result == true &&
        labelCtrl.text.trim().isNotEmpty &&
        keyCtrl.text.trim().isNotEmpty) {
      setState(() {
        _groups[groupIdx].entries.add(
          _JobTitleEntry(
            key: keyCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
            label: labelCtrl.text.trim(),
          ),
        );
      });
    }
  }

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
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(
        () => _groups.add(_JobTitleGroupState(title: result, entries: [])),
      );
    }
  }

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
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true)
      setState(() => _groups[groupIdx].entries.removeAt(entryIdx));
  }

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(officeSettingsProvider);
    settingsAsync.whenData((settings) {
      if (!_initialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_initialized)
            setState(() => _initGroups(settings.effectiveJobTitleGroups));
        });
      }
    });

    if (!_initialized) {
      return Scaffold(
        backgroundColor: AppColors.slate900,
        appBar: AppBar(
          backgroundColor: AppColors.slate850,
          title: const Text('Manage Job Titles'),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.cyan500),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.slate900,
      appBar: AppBar(
        backgroundColor: AppColors.slate850,
        title: const Text('Manage Job Titles'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.slate700),
        ),
        actions: [
          TextButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.cyan400,
                    ),
                  )
                : const Icon(
                    Icons.save_rounded,
                    color: AppColors.cyan400,
                    size: 18,
                  ),
            label: Text(
              _saving ? 'Saving...' : 'Save',
              style: const TextStyle(
                color: AppColors.cyan400,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.cyan900.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cyan800.withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.cyan400,
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Customize job titles for your office. Press Save to apply changes.',
                    style: TextStyle(fontSize: 12, color: AppColors.slate300),
                  ),
                ),
              ],
            ),
          ),

          for (int gi = 0; gi < _groups.length; gi++) ...[
            _GroupHeader(title: _groups[gi].title, onAdd: () => _addEntry(gi)),
            const SizedBox(height: 8),
            for (int ei = 0; ei < _groups[gi].entries.length; ei++)
              _JobTitleTile(
                entry: _groups[gi].entries[ei],
                onEdit: () => _editEntry(gi, ei),
                onDelete: () => _deleteEntry(gi, ei),
              ),
            const SizedBox(height: 20),
          ],

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

class _GroupHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  const _GroupHeader({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.cyan500,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.cyan400,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.add_circle_outline_rounded,
            color: AppColors.cyan500,
            size: 20,
          ),
          onPressed: onAdd,
          tooltip: 'Add to $title',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

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
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.slate800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate700),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: const Icon(
          Icons.work_outline_rounded,
          color: AppColors.slate500,
          size: 20,
        ),
        title: Text(
          entry.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.slate200,
          ),
        ),
        subtitle: Text(
          entry.key,
          style: const TextStyle(fontSize: 11, color: AppColors.slate500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppColors.cyan600,
              ),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppColors.error,
              ),
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
    final customTitles = ref
        .watch(officeSettingsProvider)
        .valueOrNull
        ?.effectiveJobTitles;
    final titleLabel = user?.jobTitleLabelFrom(customTitles) ?? '—';
    final roleColor = AppStatusColors.forRole(user?.role ?? '');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.heroBanner(),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  titleLabel,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user?.roleLabel ?? '—',
                    style: TextStyle(
                      color: roleColor == AppColors.cyan500
                          ? AppColors.cyan200
                          : Colors.white,
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
    final workHours =
        _endTime.hour -
        _startTime.hour +
        (_endTime.minute - _startTime.minute) / 60;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.cyan500.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: AppColors.cyan500,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Work Hours',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.slate100,
                    ),
                  ),
                  Text(
                    '${workHours.toStringAsFixed(1)} hrs/day',
                    style: const TextStyle(
                      color: AppColors.slate400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TimePicker(
                  label: 'Start Time',
                  icon: Icons.login_rounded,
                  time: _startTime,
                  color: AppColors.success,
                  onTap: () => _pickTime(isStart: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimePicker(
                  label: 'End Time',
                  icon: Icons.logout_rounded,
                  time: _endTime,
                  color: AppColors.cyan500,
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
        if (isStart)
          _startTime = picked;
        else
          _endTime = picked;
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
      await ref
          .read(officeRepositoryProvider)
          .updateWorkHours(
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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                Icon(icon, color: color, size: 13),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
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
              style: TextStyle(color: color.withOpacity(0.5), fontSize: 10),
            ),
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
          decoration: BoxDecoration(
            color: AppColors.cyan500,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.slate100,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

// ── Settings Tile ─────────────────────────────────────────────────────────────

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.slate800,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.slate700),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.slate400).withOpacity(0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.slate400,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor ?? AppColors.slate200,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            if (trailing != null) trailing!,
            if (onTap != null && trailing == null)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.slate600,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Change Password Dialog ────────────────────────────────────────────────────

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentCtrl.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newCtrl.text.trim());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully ✓'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = switch (e.code) {
          'wrong-password' => 'Current password is incorrect.',
          'weak-password' => 'New password is too weak (min 6 chars).',
          'requires-recent-login' => 'Please logout and login again first.',
          _ => 'Error: ${e.message}',
        };
      });
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: AppColors.warning, size: 20),
          SizedBox(width: 8),
          Text('Change Password'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentCtrl,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newCtrl,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'Minimum 6 characters';
                  if (v == _currentCtrl.text)
                    return 'Must be different from current';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v != _newCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _changePassword,
          style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Change'),
        ),
      ],
    );
  }
}
