import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/employee_model.dart';
import '../../../../features/home/data/models/user_model.dart';
import '../controllers/employee_providers.dart';
import '../../../../features/home/presentation/controllers/home_providers.dart';
import '../../../office/presentation/controllers/office_settings_providers.dart';
import '../../../client/data/models/client_model.dart';
import '../../../client/data/client_repository.dart';

class AddEditEmployeeScreen extends ConsumerStatefulWidget {
  final EmployeeModel? employee;
  final String? initialRole;
  final bool lockRole;
  final String? initialLinkedClientId;
  final String? screenTitle;

  const AddEditEmployeeScreen({
    super.key,
    this.employee,
    this.initialRole,
    this.lockRole = false,
    this.initialLinkedClientId,
    this.screenTitle,
  });

  @override
  ConsumerState<AddEditEmployeeScreen> createState() =>
      _AddEditEmployeeScreenState();
}

class _AddEditEmployeeScreenState extends ConsumerState<AddEditEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;
  String? _linkedClientId;

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _specializationController;
  late final TextEditingController _graduationYearController;
  late final TextEditingController _notesController;
  late final TextEditingController _employeeCodeController;

  String _role = 'engineer';
  String _department = '';
  String _status = 'active';
  String _jobTitleKey = '';
  bool _adminFlag = false;
  DateTime _joinDate = DateTime.now();

  bool get _isEditing => widget.employee != null;
  bool get _isClientMode =>
      (widget.initialRole == 'client') || (_role == 'client');

  String get _resolvedTitle {
    if (widget.screenTitle != null && widget.screenTitle!.trim().isNotEmpty) {
      return widget.screenTitle!.trim();
    }

    if (_isClientMode) {
      return _isEditing ? 'Edit Client Account' : 'Add Client Account';
    }

    return _isEditing ? 'Edit Employee' : 'Add Employee';
  }

  String get _resolvedSubmitLabel {
    if (_isClientMode) {
      return _isEditing ? 'Update Client Account' : 'Add Client Account';
    }

    return _isEditing ? 'Update Employee' : 'Add Employee';
  }

  @override
  void initState() {
    super.initState();
    final e = widget.employee;

    _nameController = TextEditingController(text: e?.name ?? '');
    _emailController = TextEditingController(text: e?.email ?? '');
    _passwordController = TextEditingController();
    _phoneController = TextEditingController(text: e?.phone ?? '');
    _addressController = TextEditingController(text: e?.address ?? '');
    _specializationController = TextEditingController(
      text: e?.specialization ?? '',
    );
    _graduationYearController = TextEditingController(
      text: e != null && e.graduationYear != 0
          ? e.graduationYear.toString()
          : '',
    );
    _notesController = TextEditingController(text: e?.notes ?? '');
    _employeeCodeController = TextEditingController(
      text: e?.employeeCode ?? '',
    );

    if (e != null) {
      _role = e.role;
      _department = e.department;
      _status = e.status;
      _joinDate = e.joinDate;
      _jobTitleKey = e.jobTitle;
      _adminFlag = e.adminFlag;
      _linkedClientId = e.linkedClientId;
    } else {
      _role = widget.initialRole ?? 'engineer';
      _linkedClientId = widget.initialLinkedClientId;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final user = ref.read(currentUserProvider).value;
        if (user == null) return;

        final repo = ref.read(employeeRepositoryProvider);
        final code = await repo.generateEmployeeCode(user.officeId);

        if (mounted && _employeeCodeController.text.isEmpty) {
          setState(() => _employeeCodeController.text = code);
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _specializationController.dispose();
    _graduationYearController.dispose();
    _notesController.dispose();
    _employeeCodeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_isEditing && _passwordController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Password is required');
      return;
    }

    if (!_isEditing && _passwordController.text.trim().length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_role == 'client' &&
        (_linkedClientId == null || _linkedClientId!.isEmpty)) {
      setState(() => _errorMessage = 'Please select the linked client record');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not found');

      final repo = ref.read(employeeRepositoryProvider);

      if (_isEditing) {
        await repo.updateEmployee(widget.employee!.uid, {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'role': _role,
          'adminFlag': _adminFlag,
          'department': _department,
          'jobTitle': _jobTitleKey,
          'specialization': _specializationController.text.trim(),
          'graduationYear':
              int.tryParse(_graduationYearController.text.trim()) ?? 0,
          'joinDate': _joinDate,
          'status': _status,
          'isActive': _status == 'active',
          'notes': _notesController.text.trim(),
          'linkedClientId': _role == 'client' ? _linkedClientId : null,
        });
      } else {
        await repo.addEmployee(
          officeId: user.officeId,
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          employeeCode: _employeeCodeController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          role: _role,
          adminFlag: _adminFlag,
          department: _department,
          jobTitle: _jobTitleKey,
          specialization: _specializationController.text.trim(),
          graduationYear:
              int.tryParse(_graduationYearController.text.trim()) ?? 0,
          joinDate: _joinDate,
          notes: _notesController.text.trim(),
          linkedClientId: _role == 'client' ? _linkedClientId : null,
        );
      }

      if (mounted) {
        ref.invalidate(employeeCodeProvider);
        Navigator.pop(context);
      }
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          _resolvedTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: cs.onErrorContainer),
                ),
              ),
              const SizedBox(height: 16),
            ],

            _SectionTitle(title: 'Basic Information'),
            const SizedBox(height: 12),

            _buildField(
              controller: _employeeCodeController,
              label: _isClientMode ? 'Account Code' : 'Employee Code',
              icon: Icons.badge_outlined,
              readOnly: _isEditing,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            _buildField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_outline_rounded,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            _buildField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              readOnly: _isEditing,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (!v.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            const SizedBox(height: 12),

            if (!_isEditing) ...[
              _buildField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'Min 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ],

            _buildField(
              controller: _phoneController,
              label: 'Phone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            _buildField(
              controller: _addressController,
              label: 'Address',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 24),

            _SectionTitle(
              title: _isClientMode ? 'Account Information' : 'Job Information',
            ),
            const SizedBox(height: 12),

            _GroupedJobTitleDropdown(
              value: _jobTitleKey.isEmpty ? null : _jobTitleKey,
              onChanged: (v) => setState(() => _jobTitleKey = v ?? ''),
            ),
            const SizedBox(height: 12),

            if (widget.lockRole)
              _LockedRoleField(value: _role)
            else
              _RoleDropdown(
                value: _role,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _role = v;
                    if (_role != 'client') {
                      _linkedClientId = null;
                    }
                  });
                },
              ),
            const SizedBox(height: 8),

            _RoleInfoCard(role: _role),
            const SizedBox(height: 12),

            if (_role == 'client') ...[
              _LinkedClientDropdown(
                selectedClientId: _linkedClientId,
                onChanged: (v) => setState(() => _linkedClientId = v),
                enabled: !widget.lockRole || _isEditing,
              ),
              const SizedBox(height: 12),
            ],

            _AdminToggle(
              value: _adminFlag,
              onChanged: (v) => setState(() => _adminFlag = v),
            ),
            const SizedBox(height: 12),

            Consumer(
              builder: (context, ref, _) {
                final departments = ref.watch(departmentsProvider);
                final items = {for (var d in departments) d: d};

                if (_department.isEmpty && departments.isNotEmpty) {
                  _department = departments.first;
                }
                if (!items.containsKey(_department) && departments.isNotEmpty) {
                  _department = departments.first;
                }

                return _buildDropdown(
                  label: 'Department',
                  value: _department.isNotEmpty ? _department : null,
                  icon: Icons.category_outlined,
                  items: items,
                  onChanged: (v) => setState(() => _department = v ?? ''),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildDropdown(
              label: 'Status',
              value: _status,
              icon: Icons.toggle_on_outlined,
              items: const {
                'active': 'Active',
                'suspended': 'Suspended',
                'resigned': 'Resigned',
              },
              onChanged: (v) => setState(() => _status = v ?? 'active'),
            ),
            const SizedBox(height: 12),

            _DateField(
              label: 'Join Date',
              date: _joinDate,
              onChanged: (d) => setState(() => _joinDate = d),
            ),
            const SizedBox(height: 24),

            _SectionTitle(title: 'Academic Information'),
            const SizedBox(height: 12),

            _buildField(
              controller: _specializationController,
              label: 'Specialization',
              icon: Icons.school_outlined,
            ),
            const SizedBox(height: 12),

            _buildField(
              controller: _graduationYearController,
              label: 'Graduation Year',
              icon: Icons.calendar_today_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            _SectionTitle(title: 'Notes'),
            const SizedBox(height: 12),

            _buildField(
              controller: _notesController,
              label: 'Notes',
              icon: Icons.notes_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isLoading ? null : _save,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _resolvedSubmitLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool readOnly = false,
    bool obscureText = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final cs = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      obscureText: obscureText,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: cs.primary),
        filled: true,
        fillColor: readOnly
            ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
            : cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.error, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required IconData icon,
    required Map<String, String> items,
    required void Function(String?) onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;

    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: cs.primary),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
      borderRadius: BorderRadius.circular(14),
      items: items.entries
          .map(
            (e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)),
          )
          .toList(),
    );
  }
}

class _LockedRoleField extends StatelessWidget {
  final String value;

  const _LockedRoleField({required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String label;
    switch (value) {
      case 'engineer':
        label = 'Engineer';
        break;
      case 'team_leader':
        label = 'Team Leader';
        break;
      case 'reviewer':
        label = 'Reviewer';
        break;
      case 'management':
        label = 'Management';
        break;
      case 'administration':
        label = 'Administration';
        break;
      case 'client':
        label = 'Client';
        break;
      default:
        label = value;
    }

    return TextFormField(
      initialValue: label,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'System Role (Permissions)',
        prefixIcon: Icon(
          Icons.admin_panel_settings_outlined,
          color: cs.primary,
        ),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.65),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _LinkedClientDropdown extends ConsumerWidget {
  final String? selectedClientId;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const _LinkedClientDropdown({
    required this.selectedClientId,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final currentUser = ref.watch(currentUserProvider).value;

    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    final clientsStream = ClientRepository(
      officeId: currentUser.officeId,
    ).watchClients();

    return StreamBuilder<List<ClientModel>>(
      stream: clientsStream,
      builder: (context, snapshot) {
        final clients = snapshot.data ?? [];
        final selectedIsValid = clients.any(
          (client) => client.id == selectedClientId,
        );

        return DropdownButtonFormField<String>(
          initialValue: selectedIsValid ? selectedClientId : null,
          onChanged: enabled ? onChanged : null,
          decoration: InputDecoration(
            labelText: 'Linked Client',
            prefixIcon: Icon(Icons.business_outlined, color: cs.primary),
            filled: true,
            fillColor: enabled
                ? cs.surfaceContainerHighest
                : cs.surfaceContainerHighest.withValues(alpha: 0.65),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
          ),
          items: clients
              .map(
                (client) => DropdownMenuItem<String>(
                  value: client.id,
                  child: Text(client.name),
                ),
              )
              .toList(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a client';
            }
            return null;
          },
        );
      },
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  const _RoleDropdown({required this.value, required this.onChanged});

  static const _roleLabels = {
    'engineer': 'Engineer',
    'team_leader': 'Team Leader',
    'reviewer': 'Reviewer',
    'dc': 'Document Controller',
    'management': 'Management',
    'administration': 'Administration',
    'client': 'Client',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = <DropdownMenuItem<String>>[];

    void addHeader(String label) {
      items.add(
        DropdownMenuItem<String>(
          enabled: false,
          value: '__header__$label',
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
        ),
      );
    }

    void addRole(String key) {
      items.add(
        DropdownMenuItem<String>(
          value: key,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              _roleLabels[key]!,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      );
    }

    addHeader('Engineering Roles');
    addRole('engineer');
    addRole('team_leader');
    addRole('reviewer');
    addRole('dc');
    addHeader('Office Roles');
    addRole('management');
    addRole('administration');
    addHeader('Other');
    addRole('client');

    final allItemValues = items.map((i) => i.value!).toList();

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      onChanged: (v) {
        if (v != null && !v.startsWith('__header__')) onChanged(v);
      },
      decoration: InputDecoration(
        labelText: 'System Role (Permissions)',
        prefixIcon: Icon(
          Icons.admin_panel_settings_outlined,
          color: cs.primary,
        ),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
      borderRadius: BorderRadius.circular(14),
      items: items,
      selectedItemBuilder: (context) {
        return allItemValues.map((v) {
          final label = _roleLabels[v] ?? '';
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          );
        }).toList();
      },
    );
  }
}

class _RoleInfoCard extends StatelessWidget {
  final String role;
  const _RoleInfoCard({required this.role});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final info = _roleInfo(role);

    if (info == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(info.$1, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              info.$2,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String)? _roleInfo(String role) {
    switch (role) {
      case 'engineer':
        return (
          Icons.engineering_outlined,
          'Can view & work on assigned tasks.',
        );
      case 'team_leader':
        return (Icons.group_outlined, 'Can assign & manage team tasks.');
      case 'reviewer':
        return (Icons.rate_review_outlined, 'Can review & approve tasks.');
      case 'dc':
        return (
          Icons.folder_copy_outlined,
          'Document Controller — sees all client_review tasks, sends docs to client.',
        );
      case 'management':
        return (
          Icons.business_center_outlined,
          'Senior management — same permissions as Reviewer. Can be upgraded to Admin.',
        );
      case 'administration':
        return (
          Icons.badge_outlined,
          'Non-engineering staff — attendance & check-in/out only.',
        );
      case 'client':
        return (
          Icons.person_outline_rounded,
          'Client login account linked to one client record.',
        );
      default:
        return null;
    }
  }
}

class _AdminToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _AdminToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: value
            ? Colors.deepPurple.withOpacity(0.1)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? Colors.deepPurple.withOpacity(0.4)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.shield_rounded,
            color: value ? Colors.deepPurple : cs.onSurface.withOpacity(0.5),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Privileges',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: value ? Colors.deepPurple : cs.onSurface,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Full access to all features',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.deepPurple,
          ),
        ],
      ),
    );
  }
}

class _GroupedJobTitleDropdown extends ConsumerWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _GroupedJobTitleDropdown({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    final settingsAsync = ref.watch(officeSettingsProvider);
    final groups = settingsAsync.when(
      data: (settings) => settings.effectiveJobTitleGroups,
      loading: () => JobTitles.groups,
      error: (_, _) => JobTitles.groups,
    );

    final allKeys = {
      for (final g in groups)
        for (final key in g.titles.keys) key,
    };

    final safeValue = (value != null && allKeys.contains(value)) ? value : null;

    final items = <DropdownMenuItem<String>>[];
    for (final group in groups) {
      items.add(
        DropdownMenuItem<String>(
          enabled: false,
          value: '__header__${group.title}',
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              group.title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ),
        ),
      );

      for (final entry in group.titles.entries) {
        items.add(
          DropdownMenuItem<String>(
            value: entry.key,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(entry.value, style: const TextStyle(fontSize: 13)),
            ),
          ),
        );
      }
    }

    final allTitles = <String, String>{
      for (final g in groups)
        for (final e in g.titles.entries) e.key: e.value,
    };

    final allItemValues = items.map((i) => i.value!).toList();

    if (settingsAsync.isLoading) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.work_outline_rounded, color: cs.primary),
            const SizedBox(width: 12),
            Text(
              'Loading...',
              style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      onChanged: (v) {
        if (v != null && !v.startsWith('__header__')) onChanged(v);
      },
      decoration: InputDecoration(
        labelText: 'Job Title',
        prefixIcon: Icon(Icons.work_outline_rounded, color: cs.primary),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
      borderRadius: BorderRadius.circular(14),
      items: items,
      selectedItemBuilder: (context) {
        return allItemValues.map((v) {
          final label = allTitles[v] ?? '';
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList();
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: cs.primary,
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final void Function(DateTime) onChanged;

  const _DateField({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, color: cs.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
