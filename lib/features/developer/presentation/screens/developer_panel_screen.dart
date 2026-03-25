import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../features/office/data/models/office_model.dart';
import '../../../../features/home/data/models/user_model.dart';
import '../../../../features/auth/presentation/controllers/auth_providers.dart';
import '../../data/developer_repository.dart';
import '../controllers/developer_providers.dart';

// ══════════════════════════════════════════════════════════════════════════════
// DEVELOPER PANEL SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class DeveloperPanelScreen extends ConsumerStatefulWidget {
  const DeveloperPanelScreen({super.key});

  @override
  ConsumerState<DeveloperPanelScreen> createState() =>
      _DeveloperPanelScreenState();
}

class _DeveloperPanelScreenState extends ConsumerState<DeveloperPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: const Text(
                'DEV',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Developer Panel',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white54),
            onPressed: _logout,
            tooltip: 'Sign out',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white38,
          indicatorColor: Colors.amber,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.business_rounded, size: 18), text: 'Offices'),
            Tab(
              icon: Icon(Icons.people_outline_rounded, size: 18),
              text: 'Users',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_OfficesTab(), _UsersTab()],
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text(
                'New Office',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showCreateOfficeSheet(context),
            )
          : null,
    );
  }

  void _showCreateOfficeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateOfficeSheet(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// OFFICES TAB
// ══════════════════════════════════════════════════════════════════════════════

class _OfficesTab extends ConsumerWidget {
  const _OfficesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(developerRepositoryProvider);
    return StreamBuilder<List<OfficeModel>>(
      stream: repo.watchAllOffices(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.amber),
          );
        }
        final offices = snap.data ?? [];
        if (offices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business_outlined, size: 48, color: Colors.white24),
                const SizedBox(height: 12),
                const Text(
                  'No offices yet',
                  style: TextStyle(color: Colors.white38),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap + to create the first office',
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: offices.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) => _OfficeCard(office: offices[i]),
        );
      },
    );
  }
}

class _OfficeCard extends ConsumerWidget {
  final OfficeModel office;
  const _OfficeCard({required this.office});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(developerRepositoryProvider);
    final isActive = office.isActive;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111E35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withOpacity(0.12)
                        : Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.business_rounded,
                    color: isActive ? Colors.green : Colors.red,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        office.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${office.code}',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Suspended',
                              style: TextStyle(
                                color: isActive ? Colors.green : Colors.red,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Toggle button
                Switch(
                  value: isActive,
                  activeThumbColor: Colors.green,
                  inactiveThumbColor: Colors.red,
                  onChanged: (val) => val
                      ? _activate(context, ref, repo)
                      : _suspend(context, ref, repo),
                ),
              ],
            ),
          ),
          // Work hours + created at
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 13,
                  color: Colors.white38,
                ),
                const SizedBox(width: 4),
                Text(
                  '${office.workStartTime} – ${office.workEndTime}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const Spacer(),
                if (office.createdAt != null)
                  Text(
                    _fmtDate(office.createdAt!),
                    style: const TextStyle(color: Colors.white24, fontSize: 11),
                  ),
              ],
            ),
          ),
          // Logo upload row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: _LogoUploadRow(office: office),
          ),
        ],
      ),
    );
  }

  Future<void> _activate(
    BuildContext context,
    WidgetRef ref,
    DeveloperRepository repo,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _DevDialog(
        title: 'Activate Office',
        message:
            'Activate "${office.name}"? Users will be able to log in again.',
        confirmLabel: 'Activate',
        confirmColor: Colors.green,
      ),
    );
    if (confirm == true) {
      await repo.toggleOfficeStatus(officeId: office.id, isActive: true);
    }
  }

  Future<void> _suspend(
    BuildContext context,
    WidgetRef ref,
    DeveloperRepository repo,
  ) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111E35),
        title: const Text(
          'Suspend Office',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Suspend "${office.name}"?\nAll users will be locked out.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Reason (optional)',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await repo.toggleOfficeStatus(
        officeId: office.id,
        isActive: false,
        suspendReason: reasonCtrl.text.trim(),
      );
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ══════════════════════════════════════════════════════════════════════════════
// LOGO UPLOAD ROW
// ══════════════════════════════════════════════════════════════════════════════

class _LogoUploadRow extends ConsumerStatefulWidget {
  final OfficeModel office;
  const _LogoUploadRow({required this.office});

  @override
  ConsumerState<_LogoUploadRow> createState() => _LogoUploadRowState();
}

class _LogoUploadRowState extends ConsumerState<_LogoUploadRow> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 75,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final base64 = base64Encode(bytes);
      final ext = picked.name.split('.').last.toLowerCase();
      final dataUrl = 'data:image/$ext;base64,$base64';

      // Check size — Firestore doc limit is 1MB
      if (bytes.lengthInBytes > 800 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Image too large. Please choose a smaller image (< 800KB).',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await FirebaseFirestore.instance
          .collection('offices')
          .doc(widget.office.id)
          .update({'logo': dataUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo uploaded ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeLogo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111E35),
        title: const Text('Remove Logo', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to remove the office logo?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _uploading = true);
    try {
      await FirebaseFirestore.instance
          .collection('offices')
          .doc(widget.office.id)
          .update({'logo': FieldValue.delete()});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo removed ✓'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLogo = widget.office.logo.isNotEmpty;

    return Row(
      children: [
        // Logo preview
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white.withOpacity(0.06),
            border: Border.all(color: Colors.white12),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasLogo
              ? (widget.office.logo.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(widget.office.logo.split(',').last),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white24,
                          size: 18,
                        ),
                      )
                    : Image.network(
                        widget.office.logo,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white24,
                          size: 18,
                        ),
                      ))
              : const Icon(
                  Icons.image_outlined,
                  color: Colors.white24,
                  size: 18,
                ),
        ),

        const SizedBox(width: 10),

        // Label
        Expanded(
          child: Text(
            hasLogo ? 'Logo uploaded' : 'No logo yet',
            style: TextStyle(
              color: hasLogo ? Colors.white54 : Colors.white24,
              fontSize: 12,
            ),
          ),
        ),

        // Actions
        if (_uploading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.amber,
            ),
          )
        else ...[
          // Upload / Replace button
          GestureDetector(
            onTap: _pickAndUpload,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Text(
                hasLogo ? 'Replace' : 'Upload',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (hasLogo) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _removeLogo,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.25)),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  size: 14,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// USERS TAB
// ══════════════════════════════════════════════════════════════════════════════

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  OfficeModel? _selectedOffice;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(developerRepositoryProvider);
    return Column(
      children: [
        // Office selector
        StreamBuilder<List<OfficeModel>>(
          stream: repo.watchAllOffices(),
          builder: (context, snap) {
            final offices = snap.data ?? [];

            // Reset selected office if it no longer exists in the list
            if (_selectedOffice != null &&
                !offices.any((o) => o.id == _selectedOffice!.id)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _selectedOffice = null);
              });
            }

            // Sync selected office with updated data
            if (_selectedOffice != null) {
              final updated = offices.where((o) => o.id == _selectedOffice!.id);
              if (updated.isNotEmpty && updated.first != _selectedOffice) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedOffice = updated.first);
                });
              }
            }

            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF111E35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<OfficeModel>(
                  value: offices.any((o) => o.id == _selectedOffice?.id)
                      ? offices.firstWhere((o) => o.id == _selectedOffice!.id)
                      : null,
                  hint: const Text(
                    'Select office',
                    style: TextStyle(color: Colors.white38),
                  ),
                  dropdownColor: const Color(0xFF111E35),
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white38,
                  ),
                  items: offices
                      .map(
                        (o) => DropdownMenuItem(
                          value: o,
                          child: Text(
                            o.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (o) => setState(() => _selectedOffice = o),
                ),
              ),
            );
          },
        ),

        // Users list
        Expanded(
          child: _selectedOffice == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white24,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select an office above',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                )
              : _UsersList(office: _selectedOffice!),
        ),
      ],
    );
  }
}

class _UsersList extends ConsumerStatefulWidget {
  final OfficeModel office;
  const _UsersList({required this.office});

  @override
  ConsumerState<_UsersList> createState() => _UsersListState();
}

class _UsersListState extends ConsumerState<_UsersList> {
  List<UserModel>? _users;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void didUpdateWidget(_UsersList old) {
    super.didUpdateWidget(old);
    if (old.office.id != widget.office.id) _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final users = await ref
        .read(developerRepositoryProvider)
        .getOfficeUsers(widget.office.id);
    if (mounted)
      setState(() {
        _users = users;
        _loading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
    final users = _users ?? [];
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 40, color: Colors.white24),
            const SizedBox(height: 10),
            const Text(
              'No users found',
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _UserCard(user: users[i], onRefresh: _loadUsers),
    );
  }
}

class _UserCard extends ConsumerWidget {
  final UserModel user;
  final VoidCallback onRefresh;
  const _UserCard({required this.user, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = user.adminFlag || user.role == 'admin';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111E35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAdmin ? Colors.amber.withOpacity(0.25) : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isAdmin
                  ? Colors.amber.withOpacity(0.12)
                  : Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAdmin
                  ? Icons.admin_panel_settings_rounded
                  : Icons.person_outline_rounded,
              color: isAdmin ? Colors.amber : Colors.white54,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Admin',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (user.role.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.roleLabel,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          // Edit button
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: Colors.white38,
              size: 18,
            ),
            onPressed: () => _showEditSheet(context, ref),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditUserSheet(user: user, onSaved: onRefresh),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CREATE OFFICE BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _CreateOfficeSheet extends ConsumerStatefulWidget {
  const _CreateOfficeSheet();

  @override
  ConsumerState<_CreateOfficeSheet> createState() => _CreateOfficeSheetState();
}

class _CreateOfficeSheetState extends ConsumerState<_CreateOfficeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _adminPassCtrl = TextEditingController();
  bool _saving = false;
  bool _obscurePass = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      print('=== Creating office: ${_nameCtrl.text.trim()} ===');
      final creds = ref.read(devCredentialsProvider);
      if (creds == null) throw Exception('Session expired, please re-login');
      await ref
          .read(developerRepositoryProvider)
          .createOffice(
            officeName: _nameCtrl.text.trim(),
            officeCode: _codeCtrl.text.trim(),
            adminName: _adminNameCtrl.text.trim(),
            adminEmail: _adminEmailCtrl.text.trim(),
            adminPassword: _adminPassCtrl.text.trim(),
            devEmail: creds.email,
            devPassword: creds.password,
          );
      print('=== Office created successfully ===');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Office "${_nameCtrl.text.trim()}" created ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stack) {
      print('=== ERROR creating office: $e ===');
      print('=== STACK: $stack ===');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF111E35),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create New Office',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Office info
                    _DevLabel('Office Name'),
                    _DevField(
                      controller: _nameCtrl,
                      hint: 'e.g. Afaq Engineering',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    _DevLabel('Office Code'),
                    _DevField(
                      controller: _codeCtrl,
                      hint: 'e.g. AFAQ2026',
                      caps: TextCapitalization.characters,
                      validator: (v) {
                        if (v!.isEmpty) return 'Required';
                        if (v.length < 4) return 'Min 4 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),

                    // Admin info
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Admin Account',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _DevLabel('Admin Name'),
                    _DevField(
                      controller: _adminNameCtrl,
                      hint: 'Full name',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    _DevLabel('Admin Email'),
                    _DevField(
                      controller: _adminEmailCtrl,
                      hint: 'admin@company.com',
                      keyboard: TextInputType.emailAddress,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    _DevLabel('Admin Password'),
                    _DevField(
                      controller: _adminPassCtrl,
                      hint: 'Min 6 characters',
                      obscure: _obscurePass,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.white38,
                          size: 18,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                      validator: (v) {
                        if (v!.isEmpty) return 'Required';
                        if (v.length < 6) return 'Min 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Create Office + Admin',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════════════════
// EDIT USER BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _EditUserSheet extends ConsumerStatefulWidget {
  final UserModel user;
  final VoidCallback onSaved;
  const _EditUserSheet({required this.user, required this.onSaved});

  @override
  ConsumerState<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends ConsumerState<_EditUserSheet> {
  late final TextEditingController _emailCtrl;
  bool _saving = false;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.user.email);
    _isActive = widget.user.isActive;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveEmail() async {
    final newEmail = _emailCtrl.text.trim();
    if (newEmail == widget.user.email || newEmail.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(developerRepositoryProvider)
          .updateUserEmail(uid: widget.user.uid, newEmail: newEmail);
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email updated ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleActive() async {
    final newVal = !_isActive;
    setState(() => _isActive = newVal);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({'isActive': newVal});
      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newVal ? 'User activated ✓' : 'User deactivated ✓'),
            backgroundColor: newVal ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _isActive = !newVal);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(
        email: widget.user.email,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to ${widget.user.email}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF111E35),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.only(bottom: 16),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              'Edit User — ${widget.user.name}',
              style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(widget.user.roleLabel,
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 16),

            // ── Active / Inactive toggle ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isActive
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: _isActive ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isActive ? 'Account Active' : 'Account Inactive (Blocked)',
                      style: TextStyle(
                        color: _isActive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                    onChanged: (_) => _toggleActive(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Email field ───────────────────────────────────────────────
            _DevLabel('Email'),
            _DevField(
              controller: _emailCtrl,
              hint: 'user@company.com',
              keyboard: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save Email',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _saving ? null : _saveEmail,
              ),
            ),

            const SizedBox(height: 12),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),

            // ── Password Reset ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
                  foregroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.lock_reset_rounded, size: 18),
                label: const Text('Send Password Reset Email',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: _saving ? null : _sendPasswordReset,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _DevLabel extends StatelessWidget {
  final String text;
  const _DevLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DevField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboard;
  final TextCapitalization caps;
  final bool obscure;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _DevField({
    required this.controller,
    required this.hint,
    this.keyboard = TextInputType.text,
    this.caps = TextCapitalization.none,
    this.obscure = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      textCapitalization: caps,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.25),
          fontSize: 13,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.amber, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}

class _DevDialog extends StatelessWidget {
  final String title, message, confirmLabel;
  final Color confirmColor;
  const _DevDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111E35),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(message, style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
