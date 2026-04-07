import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/employee_model.dart';
import '../../../../features/home/data/models/user_model.dart';
import '../controllers/employee_providers.dart';
import '../../../../features/home/presentation/controllers/home_providers.dart';
import '../../../office/presentation/controllers/office_settings_providers.dart';
import '../../../office/presentation/controllers/hr_policy_providers.dart';
import '../../../office/data/models/hr_policy_model.dart';
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

  // ── Reporting Chain ────────────────────────────────────────────────────────
  String? _reportToUserId;
  String? _reportToName;
  String? _reportToJobTitle;

  // ── HR Fields ──────────────────────────────────────────────────────────────
  String _contractType = 'permanent';
  DateTime? _contractEndDate;
  late TextEditingController _emergencyContactController;
  late TextEditingController _nationalIdController;

  // ── Schedule & Leave Settings ──────────────────────────────────────────────
  int _annualLeaveDays = 21;
  bool _hasCustomSchedule = false;
  List<String> _customWorkDays = HRPolicyModel.kDefaultWorkDays.toList();
  TimeOfDay _customStartTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _customEndTime = const TimeOfDay(hour: 16, minute: 30);
  List<_DayOverrideEntry> _dayOverrides = [];
  bool _exemptFromRules = false;

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
    _emergencyContactController = TextEditingController(text: e?.emergencyContact ?? '');
    _nationalIdController = TextEditingController(text: e?.nationalId ?? '');
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
      // Reporting chain
      _reportToUserId = e.reportToUserId;
      _reportToName = e.reportToName;
      _reportToJobTitle = e.reportToJobTitle;
      // HR fields
      _contractType = e.contractType;
      _contractEndDate = e.contractEndDate;
      // Schedule
      _annualLeaveDays = e.annualLeaveDays;
      _hasCustomSchedule = e.hasCustomSchedule;
      _customWorkDays = List<String>.from(e.customWorkDays.isNotEmpty
          ? e.customWorkDays
          : HRPolicyModel.kDefaultWorkDays);
      _exemptFromRules = e.exemptFromRules;
      if (e.customStartTime.isNotEmpty) {
        final p = e.customStartTime.split(':');
        _customStartTime = TimeOfDay(
            hour: int.tryParse(p[0]) ?? 8,
            minute: p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0);
      }
      if (e.customEndTime.isNotEmpty) {
        final p = e.customEndTime.split(':');
        _customEndTime = TimeOfDay(
            hour: int.tryParse(p[0]) ?? 16,
            minute: p.length > 1 ? (int.tryParse(p[1]) ?? 30) : 30);
      }
      _dayOverrides = e.dayOverrides.entries.map((entry) {
        final v = entry.value;
        return _DayOverrideEntry(
          day: entry.key,
          start: v['start'] ?? '08:00',
          end: v['end'] ?? '16:30',
        );
      }).toList();
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

        // Load default annual leave from HR policy
        final policy = await ref.read(hrPolicyRepositoryProvider)
            .getPolicy(user.officeId);
        if (mounted) {
          setState(() => _annualLeaveDays = policy.annualLeaveDays);
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
    _emergencyContactController.dispose();
    _nationalIdController.dispose();
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

      final scheduleData = _buildScheduleData();
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
          'reportToUserId': _reportToUserId ?? '',
          'reportToName': _reportToName ?? '',
          'reportToJobTitle': _reportToJobTitle ?? '',
          'contractType': _contractType,
          'contractEndDate': _contractEndDate != null
              ? Timestamp.fromDate(_contractEndDate!)
              : null,
          'emergencyContact': _emergencyContactController.text.trim(),
          'nationalId': _nationalIdController.text.trim(),
          ...scheduleData,
        });
      } else {
        final uid = await repo.addEmployee(
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
        // Write schedule and HR fields after user created
        if (uid != null) {
          await repo.updateEmployee(uid, {
            ...scheduleData,
            'contractType': _contractType,
            if (_contractEndDate != null)
              'contractEndDate': Timestamp.fromDate(_contractEndDate!),
            'emergencyContact': _emergencyContactController.text.trim(),
            'nationalId': _nationalIdController.text.trim(),
          });
        }
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

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> _buildScheduleData() {
    final overridesMap = <String, Map<String, String>>{};
    for (final e in _dayOverrides) {
      overridesMap[e.day] = {'start': e.start, 'end': e.end};
    }
    return {
      'annualLeaveDays': _annualLeaveDays,
      'hasCustomSchedule': _hasCustomSchedule,
      'customWorkDays': _hasCustomSchedule ? _customWorkDays : [],
      'customStartTime': _hasCustomSchedule ? _fmtTime(_customStartTime) : '',
      'customEndTime': _hasCustomSchedule ? _fmtTime(_customEndTime) : '',
      'dayOverrides': overridesMap,
      'exemptFromRules': _exemptFromRules,
    };
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

            // ── Reports To dropdown ──────────────────────────────────────
            if (!_isClientMode)
              _ReportsToDropdown(
                officeId: ref.read(currentUserProvider).value?.officeId ?? '',
                excludeUid: widget.employee?.uid,
                selectedUserId: _reportToUserId,
                onChanged: (uid, name, jobTitle) => setState(() {
                  _reportToUserId = uid;
                  _reportToName = name;
                  _reportToJobTitle = jobTitle;
                }),
              ),
            if (!_isClientMode) const SizedBox(height: 12),

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
            const SizedBox(height: 24),

            // ── Schedule & Leave Settings ──────────────────────────────
            _SectionTitle(title: 'Schedule & Leave Settings'),
            const SizedBox(height: 12),
            _ScheduleSection(
              annualLeaveDays: _annualLeaveDays,
              hasCustomSchedule: _hasCustomSchedule,
              customWorkDays: _customWorkDays,
              customStartTime: _customStartTime,
              customEndTime: _customEndTime,
              dayOverrides: _dayOverrides,
              exemptFromRules: _exemptFromRules,
              onAnnualLeaveDaysChanged: (v) => setState(() => _annualLeaveDays = v),
              onHasCustomScheduleChanged: (v) => setState(() => _hasCustomSchedule = v),
              onCustomWorkDaysChanged: (v) => setState(() => _customWorkDays = v),
              onCustomStartTimeChanged: (v) => setState(() => _customStartTime = v),
              onCustomEndTimeChanged: (v) => setState(() => _customEndTime = v),
              onDayOverridesChanged: (v) => setState(() => _dayOverrides = v),
              onExemptFromRulesChanged: (v) => setState(() => _exemptFromRules = v),
            ),
            const SizedBox(height: 24),

            // ── HR Fields ────────────────────────────────────────────────
            if (!_isClientMode) ...[
              _HrFieldsSection(
                contractType: _contractType,
                contractEndDate: _contractEndDate,
                emergencyContactController: _emergencyContactController,
                nationalIdController: _nationalIdController,
                onContractTypeChanged: (v) => setState(() => _contractType = v),
                onContractEndDateChanged: (v) =>
                    setState(() => _contractEndDate = v),
              ),
              const SizedBox(height: 32),
            ],

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

// ── Reports To Dropdown ───────────────────────────────────────────────────────
class _ReportsToDropdown extends ConsumerStatefulWidget {
  final String officeId;
  final String? excludeUid;
  final String? selectedUserId;
  final void Function(String? uid, String? name, String? jobTitle) onChanged;

  const _ReportsToDropdown({
    required this.officeId,
    required this.onChanged,
    this.excludeUid,
    this.selectedUserId,
  });

  @override
  ConsumerState<_ReportsToDropdown> createState() => _ReportsToDropdownState();
}

class _ReportsToDropdownState extends ConsumerState<_ReportsToDropdown> {
  List<Map<String, String>> _employees = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('officeId', isEqualTo: widget.officeId)
        .where('isActive', isEqualTo: true)
        .get();
    if (!mounted) return;
    final list = snap.docs
        .where((d) => d.id != widget.excludeUid)
        .map((d) => {
              'uid': d.id,
              'name': (d.data()['name'] as String? ?? ''),
              'jobTitle': (d.data()['jobTitle'] as String? ?? ''),
            })
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
    setState(() {
      _employees = list;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!_loaded) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.supervisor_account_outlined, color: cs.primary),
            const SizedBox(width: 12),
            Text('Loading...', style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
          ],
        ),
      );
    }

    // Safe value check
    final validUid = _employees.any((e) => e['uid'] == widget.selectedUserId)
        ? widget.selectedUserId
        : null;

    return DropdownButtonFormField<String>(
      initialValue: validUid,
      isExpanded: true,
      onChanged: (uid) {
        if (uid == null || uid == '__none__') {
          widget.onChanged(null, null, null);
        } else {
          final emp = _employees.firstWhere((e) => e['uid'] == uid,
              orElse: () => {});
          widget.onChanged(emp['uid'], emp['name'], emp['jobTitle']);
        }
      },
      decoration: InputDecoration(
        labelText: 'Reports To (Direct Manager)',
        prefixIcon: Icon(Icons.supervisor_account_outlined, color: cs.primary),
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
      items: [
        const DropdownMenuItem<String>(
          value: '__none__',
          child: Text('— None (Top Level)'),
        ),
        ..._employees.map(
          (e) => DropdownMenuItem<String>(
            value: e['uid'],
            child: Text(
              '${e['name']} — ${JobTitles.labelOf(e['jobTitle'] ?? '')}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      selectedItemBuilder: (context) {
        final all = ['__none__', ..._employees.map((e) => e['uid']!)];
        return all.map((uid) {
          if (uid == '__none__') {
            return const Align(
              alignment: Alignment.centerLeft,
              child: Text('— None (Top Level)', style: TextStyle(fontSize: 13)),
            );
          }
          final emp = _employees.firstWhere((e) => e['uid'] == uid,
              orElse: () => {'name': '', 'jobTitle': ''});
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${emp['name']} — ${JobTitles.labelOf(emp['jobTitle'] ?? '')}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
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

// ══════════════════════════════════════════════════════════════════════════════
// Schedule Section
// ══════════════════════════════════════════════════════════════════════════════

class _DayOverrideEntry {
  final String day;
  final String start;
  final String end;
  const _DayOverrideEntry({required this.day, required this.start, required this.end});
  _DayOverrideEntry copyWith({String? start, String? end}) =>
      _DayOverrideEntry(day: day, start: start ?? this.start, end: end ?? this.end);
}

class _ScheduleSection extends StatelessWidget {
  final int annualLeaveDays;
  final bool hasCustomSchedule;
  final List<String> customWorkDays;
  final TimeOfDay customStartTime;
  final TimeOfDay customEndTime;
  final List<_DayOverrideEntry> dayOverrides;
  final bool exemptFromRules;

  final ValueChanged<int> onAnnualLeaveDaysChanged;
  final ValueChanged<bool> onHasCustomScheduleChanged;
  final ValueChanged<List<String>> onCustomWorkDaysChanged;
  final ValueChanged<TimeOfDay> onCustomStartTimeChanged;
  final ValueChanged<TimeOfDay> onCustomEndTimeChanged;
  final ValueChanged<List<_DayOverrideEntry>> onDayOverridesChanged;
  final ValueChanged<bool> onExemptFromRulesChanged;

  const _ScheduleSection({
    required this.annualLeaveDays,
    required this.hasCustomSchedule,
    required this.customWorkDays,
    required this.customStartTime,
    required this.customEndTime,
    required this.dayOverrides,
    required this.exemptFromRules,
    required this.onAnnualLeaveDaysChanged,
    required this.onHasCustomScheduleChanged,
    required this.onCustomWorkDaysChanged,
    required this.onCustomStartTimeChanged,
    required this.onCustomEndTimeChanged,
    required this.onDayOverridesChanged,
    required this.onExemptFromRulesChanged,
  });

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay _parseStr(String s) {
    final p = s.split(':');
    return TimeOfDay(
      hour: int.tryParse(p[0]) ?? 8,
      minute: p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0,
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    TimeOfDay initial,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  void _toggleDay(String day) {
    final updated = List<String>.from(customWorkDays);
    if (updated.contains(day)) {
      updated.remove(day);
    } else {
      updated.add(day);
    }
    onCustomWorkDaysChanged(updated);
  }

  Future<void> _editDayOverride(BuildContext context, String day) async {
    final existing = dayOverrides.firstWhere(
      (e) => e.day == day,
      orElse: () => _DayOverrideEntry(day: day, start: _fmt(customStartTime), end: _fmt(customEndTime)),
    );

    TimeOfDay start = _parseStr(existing.start);
    TimeOfDay end = _parseStr(existing.end);

    final cs = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            title: Text('Override: ${HRPolicyModel.kDayLabels[day] ?? day}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Set custom start/end time for this day only.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _TimePickerTile(
                        label: 'Start',
                        time: start,
                        color: Colors.green,
                        onTap: () async {
                          final p = await showTimePicker(
                            context: ctx,
                            initialTime: start,
                            builder: (context, child) => MediaQuery(
                              data: MediaQuery.of(context)
                                  .copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            ),
                          );
                          if (p != null) setDlgState(() => start = p);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimePickerTile(
                        label: 'End',
                        time: end,
                        color: cs.primary,
                        onTap: () async {
                          final p = await showTimePicker(
                            context: ctx,
                            initialTime: end,
                            builder: (context, child) => MediaQuery(
                              data: MediaQuery.of(context)
                                  .copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            ),
                          );
                          if (p != null) setDlgState(() => end = p);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final updated = List<_DayOverrideEntry>.from(dayOverrides)
                    ..removeWhere((e) => e.day == day);
                  onDayOverridesChanged(updated);
                  Navigator.pop(ctx);
                },
                child: Text('Remove Override',
                    style: TextStyle(color: cs.error)),
              ),
              FilledButton(
                onPressed: () {
                  final updated = List<_DayOverrideEntry>.from(dayOverrides)
                    ..removeWhere((e) => e.day == day);
                  updated.add(_DayOverrideEntry(
                    day: day,
                    start: _fmt(start),
                    end: _fmt(end),
                  ));
                  onDayOverridesChanged(updated);
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Annual Leave Days ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.beach_access_rounded, color: cs.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Annual Leave Days',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Override the office HR policy default',
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
              // Stepper
              Row(
                children: [
                  _StepBtn(
                    icon: Icons.remove,
                    color: cs.primary,
                    onTap: annualLeaveDays > 0
                        ? () => onAnnualLeaveDaysChanged(annualLeaveDays - 1)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    alignment: Alignment.center,
                    child: Text(
                      '$annualLeaveDays',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StepBtn(
                    icon: Icons.add,
                    color: cs.primary,
                    onTap: () => onAnnualLeaveDaysChanged(annualLeaveDays + 1),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Exempt from Rules ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: exemptFromRules
                ? Colors.orange.withOpacity(0.08)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: exemptFromRules
                  ? Colors.orange.withOpacity(0.4)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.rule_folder_outlined,
                color: exemptFromRules ? Colors.orange : cs.onSurface.withOpacity(0.5),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exempt from Attendance Rules',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: exemptFromRules ? Colors.orange : cs.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Late, permission & absence rules not applied',
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
              Switch(
                value: exemptFromRules,
                onChanged: onExemptFromRulesChanged,
                activeColor: Colors.orange,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Custom Schedule Toggle ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: hasCustomSchedule
                ? cs.primary.withOpacity(0.08)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasCustomSchedule
                  ? cs.primary.withOpacity(0.4)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                color: hasCustomSchedule ? cs.primary : cs.onSurface.withOpacity(0.5),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom Work Schedule',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: hasCustomSchedule ? cs.primary : cs.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Override the office default schedule',
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
              Switch(
                value: hasCustomSchedule,
                onChanged: onHasCustomScheduleChanged,
              ),
            ],
          ),
        ),

        // ── Custom Schedule Details ────────────────────────────────────────
        if (hasCustomSchedule) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Work Days
                Text(
                  'Work Days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: HRPolicyModel.kAllDays.map((day) {
                    final selected = customWorkDays.contains(day);
                    return GestureDetector(
                      onTap: () => _toggleDay(day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? cs.primary.withOpacity(0.15)
                              : cs.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? cs.primary : cs.onSurface.withOpacity(0.2),
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          HRPolicyModel.kDayLabels[day] ?? day,
                          style: TextStyle(
                            color: selected ? cs.primary : cs.onSurface.withOpacity(0.6),
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Work Hours
                Text(
                  'Work Hours',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TimePickerTile(
                        label: 'Start Time',
                        time: customStartTime,
                        color: Colors.green,
                        onTap: () => _pickTime(context, customStartTime, onCustomStartTimeChanged),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimePickerTile(
                        label: 'End Time',
                        time: customEndTime,
                        color: cs.primary,
                        onTap: () => _pickTime(context, customEndTime, onCustomEndTimeChanged),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Day Overrides
                Row(
                  children: [
                    Text(
                      'Day-Specific Overrides',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'optional',
                        style: TextStyle(fontSize: 10, color: cs.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Set different hours for specific days (e.g. Fri shorter hours)',
                  style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.45)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: customWorkDays.map((day) {
                    final override = dayOverrides.firstWhere(
                      (e) => e.day == day,
                      orElse: () => _DayOverrideEntry(day: day, start: '', end: ''),
                    );
                    final hasOverride = override.start.isNotEmpty;
                    return GestureDetector(
                      onTap: () => _editDayOverride(context, day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: hasOverride
                              ? Colors.amber.withOpacity(0.12)
                              : cs.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasOverride
                                ? Colors.amber.withOpacity(0.5)
                                : cs.onSurface.withOpacity(0.2),
                            width: hasOverride ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              HRPolicyModel.kDayLabels[day] ?? day,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: hasOverride ? Colors.amber.shade700 : cs.onSurface.withOpacity(0.6),
                              ),
                            ),
                            if (hasOverride) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${override.start}–${override.end}',
                                style: TextStyle(fontSize: 10, color: Colors.amber.shade600),
                              ),
                            ] else ...[
                              const SizedBox(height: 2),
                              Icon(Icons.add, size: 12, color: cs.onSurface.withOpacity(0.4)),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap != null ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(onTap != null ? 0.4 : 0.15)),
        ),
        child: Icon(icon, size: 16, color: onTap != null ? color : color.withOpacity(0.3)),
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final Color color;
  final VoidCallback onTap;
  const _TimePickerTile({
    required this.label,
    required this.time,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
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
                Icon(Icons.access_time_rounded, color: color, size: 12),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('Tap to change', style: TextStyle(color: color.withOpacity(0.5), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════

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

// ── HR Fields Section ─────────────────────────────────────────────────────────
class _HrFieldsSection extends StatelessWidget {
  final String contractType;
  final DateTime? contractEndDate;
  final TextEditingController emergencyContactController;
  final TextEditingController nationalIdController;
  final ValueChanged<String> onContractTypeChanged;
  final ValueChanged<DateTime?> onContractEndDateChanged;

  const _HrFieldsSection({
    required this.contractType,
    required this.contractEndDate,
    required this.emergencyContactController,
    required this.nationalIdController,
    required this.onContractTypeChanged,
    required this.onContractEndDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── عنوان القسم ──────────────────────────────────────────────────
        Row(
          children: [
            Icon(Icons.badge_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'HR Information',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── نوع العقد ────────────────────────────────────────────────────
        Text('Contract Type',
            style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _ContractChip(label: 'Permanent', value: 'permanent',
                selected: contractType, onTap: onContractTypeChanged),
            _ContractChip(label: 'Contract', value: 'contract',
                selected: contractType, onTap: onContractTypeChanged),
            _ContractChip(label: 'Part Time', value: 'part_time',
                selected: contractType, onTap: onContractTypeChanged),
          ],
        ),
        const SizedBox(height: 12),

        // ── تاريخ انتهاء العقد (للعقود المؤقتة فقط) ─────────────────────
        if (contractType != 'permanent') ...[
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: contractEndDate ?? DateTime.now().add(const Duration(days: 365)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
              );
              if (picked != null) onContractEndDateChanged(picked);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outline),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Contract End Date',
                            style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.6))),
                        Text(
                          contractEndDate != null
                              ? '${contractEndDate!.day}/${contractEndDate!.month}/${contractEndDate!.year}'
                              : 'Tap to select',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: contractEndDate == null
                                ? cs.onSurface.withOpacity(0.4)
                                : cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (contractEndDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => onContractEndDateChanged(null),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── رقم الهوية الوطنية ──────────────────────────────────────────
        TextFormField(
          controller: nationalIdController,
          decoration: InputDecoration(
            labelText: 'National ID',
            prefixIcon: Icon(Icons.credit_card_outlined, color: cs.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),

        // ── جهة الاتصال للطوارئ ─────────────────────────────────────────
        TextFormField(
          controller: emergencyContactController,
          decoration: InputDecoration(
            labelText: 'Emergency Contact',
            prefixIcon: Icon(Icons.emergency_outlined, color: cs.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}

class _ContractChip extends StatelessWidget {
  final String label, value, selected;
  final ValueChanged<String> onTap;
  const _ContractChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = value == selected;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(value),
      selectedColor: cs.primary,
      labelStyle: TextStyle(
        color: isSelected ? cs.onPrimary : cs.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
