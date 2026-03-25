import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/project_model.dart';
import '../controllers/project_providers.dart';
import '../../../../features/home/presentation/controllers/home_providers.dart';
import '../../../../features/office/presentation/controllers/office_settings_providers.dart';
import '../../../../features/client/data/providers/client_providers.dart';
import '../../../../features/employees/presentation/controllers/employee_providers.dart';

class AddEditProjectScreen extends ConsumerStatefulWidget {
  final ProjectModel? project;
  const AddEditProjectScreen({super.key, this.project});

  @override
  ConsumerState<AddEditProjectScreen> createState() =>
      _AddEditProjectScreenState();
}

class _AddEditProjectScreenState extends ConsumerState<AddEditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  late final TextEditingController _nameController;
  late final TextEditingController _projectCodeController;
  late final TextEditingController _clientNameController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;

  String _type = 'design';
  String _status = 'active';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 180));

  final List<String> _selectedDisciplines = [];

  // ── Client selection ──────────────────────────────────────────────────────
  String _selectedClientId = '';
  String _selectedClientName = '';

  // ── Client Contact selection ──────────────────────────────────────────────
  String? _selectedClientContactId;
  String? _selectedClientContactName;

  // ── Project Team ──────────────────────────────────────────────────────────
  String? _selectedTeamLeaderId;
  String? _selectedTeamLeaderName;
  String? _selectedQcId;
  String? _selectedQcName;
  String? _selectedPmId;
  String? _selectedPmName;

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _nameController = TextEditingController(text: p?.name ?? '');
    _projectCodeController = TextEditingController(text: p?.projectCode ?? '');
    _clientNameController = TextEditingController(text: p?.clientName ?? '');
    _locationController = TextEditingController(text: p?.location ?? '');
    _notesController = TextEditingController(text: p?.notes ?? '');

    if (p != null) {
      _type = p.type;
      _status = p.status;
      _startDate = p.startDate;
      _endDate = p.endDate;
      _selectedDisciplines.addAll(p.disciplines);
      _selectedClientId = p.clientId;
      _selectedClientName = p.clientName;
      _selectedClientContactId = p.clientContactId;
      _selectedClientContactName = p.clientContactName;
      _selectedTeamLeaderId = p.teamLeaderId;
      _selectedTeamLeaderName = p.teamLeaderName;
      _selectedQcId = p.qcId;
      _selectedQcName = p.qcName;
      _selectedPmId = p.pmId;
      _selectedPmName = p.pmName;
    } else {
      // تحميل الكود مباشرة من Firestore بدون cache
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final user = ref.read(currentUserProvider).value;
        if (user == null) return;
        final repo = ref.read(projectRepositoryProvider);
        final code = await repo.generateProjectCode(user.officeId);
        if (mounted && _projectCodeController.text.isEmpty) {
          setState(() => _projectCodeController.text = code);
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _projectCodeController.dispose();
    _clientNameController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDisciplines.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one discipline');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not found');
      final repo = ref.read(projectRepositoryProvider);

      if (_isEditing) {
        await repo.updateProject(widget.project!.id, {
          'name': _nameController.text.trim(),
          'clientId': _selectedClientId,
          'clientName': _selectedClientName.isNotEmpty
              ? _selectedClientName
              : _clientNameController.text.trim(),
          'clientContactId': _selectedClientContactId,
          'clientContactName': _selectedClientContactName,
          'teamLeaderId': _selectedTeamLeaderId,
          'teamLeaderName': _selectedTeamLeaderName,
          'qcId': _selectedQcId,
          'qcName': _selectedQcName,
          'pmId': _selectedPmId,
          'pmName': _selectedPmName,
          'location': _locationController.text.trim(),
          'type': _type,
          'status': _status,
          'disciplines': _selectedDisciplines,
          'startDate': Timestamp.fromDate(_startDate),
          'endDate': Timestamp.fromDate(_endDate),
          'notes': _notesController.text.trim(),
        });
      } else {
        await repo.addProject({
          'officeId': user.officeId,
          'projectCode': _projectCodeController.text.trim(),
          'name': _nameController.text.trim(),
          'type': _type,
          'status': _status,
          'clientId': _selectedClientId,
          'clientName': _selectedClientName.isNotEmpty
              ? _selectedClientName
              : _clientNameController.text.trim(),
          'clientContactId': _selectedClientContactId,
          'clientContactName': _selectedClientContactName,
          'teamLeaderId': _selectedTeamLeaderId,
          'teamLeaderName': _selectedTeamLeaderName,
          'qcId': _selectedQcId,
          'qcName': _selectedQcName,
          'pmId': _selectedPmId,
          'pmName': _selectedPmName,
          'location': _locationController.text.trim(),
          'disciplines': _selectedDisciplines,
          'startDate': Timestamp.fromDate(_startDate),
          'endDate': Timestamp.fromDate(_endDate),
          'completionPercentage': 0.0,
          'createdBy': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'notes': _notesController.text.trim(),
        });
      }

      if (mounted) Navigator.pop(context);
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
    final disciplines = ref.watch(disciplinesProvider);
    final projectTypes = ref.watch(projectTypesProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Project' : 'New Project',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Error ─────────────────────────────────────────────────
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

            // ── Basic Info ────────────────────────────────────────────
            _SectionTitle(title: 'Basic Information'),
            const SizedBox(height: 12),

            _buildField(
              controller: _projectCodeController,
              label: 'Project Code',
              icon: Icons.tag_rounded,
              readOnly: _isEditing,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            _buildField(
              controller: _nameController,
              label: 'Project Name',
              icon: Icons.business_center_outlined,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // ── Client Dropdown ───────────────────────────────────────
            _ClientDropdown(
              selectedClientId: _selectedClientId,
              selectedClientName: _selectedClientName,
              selectedContactId: _selectedClientContactId,
              selectedContactName: _selectedClientContactName,
              fallbackController: _clientNameController,
              onChanged: (id, name) => setState(() {
                _selectedClientId = id;
                _selectedClientName = name;
                _clientNameController.text = name;
                // reset contact عند تغيير الـ client
                _selectedClientContactId = null;
                _selectedClientContactName = null;
              }),
              onContactChanged: (contactId, contactName) => setState(() {
                _selectedClientContactId = contactId;
                _selectedClientContactName = contactName;
              }),
            ),
            const SizedBox(height: 12),

            _buildField(
              controller: _locationController,
              label: 'Location',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 24),

            // ── Project Details ───────────────────────────────────────
            _SectionTitle(title: 'Project Details'),
            const SizedBox(height: 12),

            // Project Type — dynamic من office settings
            DropdownButtonFormField<String>(
              initialValue: projectTypes.contains(_type) ? _type : null,
              decoration: InputDecoration(
                labelText: 'Project Type',
                prefixIcon: Icon(Icons.category_outlined, color: cs.primary),
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
              items: projectTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),

            _buildDropdown(
              label: 'Status',
              value: _status,
              icon: Icons.toggle_on_outlined,
              items: const {
                'active': 'Active',
                'completed': 'Completed',
                'suspended': 'Suspended',
                'cancelled': 'Cancelled',
              },
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 12),

            // Dates
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Start Date',
                    date: _startDate,
                    onChanged: (d) => setState(() => _startDate = d),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'End Date',
                    date: _endDate,
                    onChanged: (d) => setState(() => _endDate = d),
                    firstDate: _startDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Disciplines — dynamic من office settings ──────────────
            _SectionTitle(title: 'Disciplines'),
            const SizedBox(height: 12),

            disciplines.isEmpty
                ? Text(
                    'No disciplines configured. Go to Settings → Manage Lists.',
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: disciplines.map((d) {
                      final selected = _selectedDisciplines.contains(d);
                      final colors = [
                        Colors.amber.shade700,
                        Colors.blue.shade700,
                        Colors.brown.shade600,
                        Colors.purple.shade600,
                        Colors.green.shade700,
                        Colors.red.shade600,
                        Colors.teal.shade600,
                        Colors.indigo.shade600,
                      ];
                      final color =
                          colors[disciplines.indexOf(d) % colors.length];

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedDisciplines.remove(d);
                            } else {
                              _selectedDisciplines.add(d);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? color : color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? color : color.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selected)
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              Text(
                                d,
                                style: TextStyle(
                                  color: selected ? Colors.white : color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 24),

            // ── Project Team ──────────────────────────────────────────
            _SectionTitle(title: 'Project Team'),
            const SizedBox(height: 4),
            Text(
              'These will be the default team for all tasks in this project',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 12),
            _ProjectTeamDropdowns(
              selectedTeamLeaderId: _selectedTeamLeaderId,
              selectedQcId: _selectedQcId,
              selectedPmId: _selectedPmId,
              onTeamLeaderChanged: (id, name) => setState(() {
                _selectedTeamLeaderId = id?.isEmpty == true ? null : id;
                _selectedTeamLeaderName = name?.isEmpty == true ? null : name;
              }),
              onQcChanged: (id, name) => setState(() {
                _selectedQcId = id?.isEmpty == true ? null : id;
                _selectedQcName = name?.isEmpty == true ? null : name;
              }),
              onPmChanged: (id, name) => setState(() {
                _selectedPmId = id?.isEmpty == true ? null : id;
                _selectedPmName = name?.isEmpty == true ? null : name;
              }),
            ),
            const SizedBox(height: 24),

            // ── Notes ─────────────────────────────────────────────────
            _SectionTitle(title: 'Notes'),
            const SizedBox(height: 12),

            _buildField(
              controller: _notesController,
              label: 'Notes',
              icon: Icons.notes_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // Save button
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
                        _isEditing ? 'Update Project' : 'Add Project',
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
    bool readOnly = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: cs.primary),
        filled: true,
        fillColor: readOnly
            ? cs.surfaceContainerHighest.withOpacity(0.5)
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
    required String value,
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
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────────

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

// ── Date Field ────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final void Function(DateTime) onChanged;
  final DateTime? firstDate;

  const _DateField({
    required this.label,
    required this.date,
    required this.onChanged,
    this.firstDate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: firstDate ?? DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, color: cs.primary, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CLIENT DROPDOWN WIDGET  (من clients collection)
// ══════════════════════════════════════════════════════════════════════════════

class _ClientDropdown extends ConsumerWidget {
  final String selectedClientId;
  final String selectedClientName;
  final String? selectedContactId;
  final String? selectedContactName;
  final TextEditingController fallbackController;
  final void Function(String id, String name) onChanged;
  final void Function(String? contactId, String? contactName) onContactChanged;

  const _ClientDropdown({
    required this.selectedClientId,
    required this.selectedClientName,
    this.selectedContactId,
    this.selectedContactName,
    required this.fallbackController,
    required this.onChanged,
    required this.onContactChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final clientsAsync = ref.watch(clientsStreamProvider);

    return clientsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => _buildFallback(context, cs),
      data: (clients) {
        final activeClients = clients.where((c) => c.isActive).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        if (activeClients.isEmpty) return _buildFallback(context, cs);

        final validClientId = activeClients.any((c) => c.id == selectedClientId)
            ? selectedClientId
            : null;

        // الـ client المختار — لجلب الـ contacts
        final selectedClient = validClientId != null
            ? activeClients.firstWhere((c) => c.id == validClientId)
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Client Dropdown ──────────────────────────────────────
            DropdownButtonFormField<String>(
              initialValue: validClientId,
              decoration: InputDecoration(
                labelText: 'Client',
                prefixIcon: Icon(Icons.business_outlined, color: cs.primary),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              hint: const Text('Select Client'),
              borderRadius: BorderRadius.circular(14),
              items: [
                const DropdownMenuItem(value: '', child: Text('— No Client —')),
                ...activeClients.map(
                  (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                ),
              ],
              onChanged: (id) {
                if (id == null || id.isEmpty) {
                  onChanged('', '');
                  onContactChanged(null, null);
                } else {
                  final client = activeClients.firstWhere((c) => c.id == id);
                  onChanged(id, client.name);
                  onContactChanged(null, null);
                }
              },
            ),

            // ── Contact Dropdown — يظهر لو في contacts ──────────────
            if (selectedClient != null &&
                selectedClient.contacts.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue:
                    selectedClient.contacts.any(
                      (c) => c.id == selectedContactId,
                    )
                    ? selectedContactId
                    : null,
                decoration: InputDecoration(
                  labelText: 'Client Contact',
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                hint: const Text('Select Contact (Optional)'),
                borderRadius: BorderRadius.circular(14),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('— No Contact —'),
                  ),
                  ...selectedClient.contacts.map(
                    (contact) => DropdownMenuItem(
                      value: contact.id,
                      child: Text('${contact.name} · ${contact.role}'),
                    ),
                  ),
                ],
                onChanged: (contactId) {
                  if (contactId == null || contactId.isEmpty) {
                    onContactChanged(null, null);
                  } else {
                    final contact = selectedClient.contacts.firstWhere(
                      (c) => c.id == contactId,
                    );
                    onContactChanged(contact.id, contact.name);
                  }
                },
              ),
            ],

            // ── Linked badge ─────────────────────────────────────────
            if (selectedClientId.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const SizedBox(width: 4),
                  Icon(Icons.check_circle_outline, size: 14, color: cs.primary),
                  const SizedBox(width: 4),
                  Text(
                    selectedContactName != null
                        ? 'Contact: $selectedContactName'
                        : 'Linked to client account',
                    style: TextStyle(fontSize: 11, color: cs.primary),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  // Fallback: text field عادي لو مفيش clients في النظام
  Widget _buildFallback(BuildContext context, ColorScheme cs) {
    return TextFormField(
      controller: fallbackController,
      decoration: InputDecoration(
        labelText: 'Client Name',
        prefixIcon: const Icon(Icons.person_outline_rounded),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PROJECT TEAM DROPDOWNS  (Team Leader / QC / PM)
// ══════════════════════════════════════════════════════════════════════════════

class _ProjectTeamDropdowns extends ConsumerWidget {
  final String? selectedTeamLeaderId;
  final String? selectedQcId;
  final String? selectedPmId;
  final void Function(String? id, String? name) onTeamLeaderChanged;
  final void Function(String? id, String? name) onQcChanged;
  final void Function(String? id, String? name) onPmChanged;

  const _ProjectTeamDropdowns({
    required this.selectedTeamLeaderId,
    required this.selectedQcId,
    required this.selectedPmId,
    required this.onTeamLeaderChanged,
    required this.onQcChanged,
    required this.onPmChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final employeesAsync = ref.watch(employeesProvider);

    return employeesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const SizedBox.shrink(),
      data: (employees) {
        final active = employees.where((e) => e.isActive).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        // Team Leaders = admin + team_leader
        final teamLeaders =
            active.where((e) => e.isTeamLeader || e.isAdmin).toList();

        // QC = reviewer
        final reviewers = active.where((e) => e.isReviewer).toList();

        // PM = everyone active (المدير ممكن يكون أي موظف)
        final allStaff = active
            .where((e) => !e.isClient)
            .toList();

        InputDecoration _dec(String label, IconData icon) => InputDecoration(
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        );

        final noneItem = <DropdownMenuItem<String>>[
          const DropdownMenuItem(value: '', child: Text('— Not Assigned —')),
        ];

        return Column(
          children: [
            // ── Team Leader ───────────────────────────────────────────
            DropdownButtonFormField<String>(
              initialValue: teamLeaders.any((e) => e.uid == selectedTeamLeaderId)
                  ? selectedTeamLeaderId
                  : '',
              decoration: _dec('Team Leader', Icons.manage_accounts_outlined),
              borderRadius: BorderRadius.circular(14),
              hint: const Text('Select Team Leader'),
              items: [
                ...noneItem,
                ...teamLeaders.map(
                  (e) => DropdownMenuItem(
                    value: e.uid,
                    child: Text(e.name),
                  ),
                ),
              ],
              onChanged: (id) {
                if (id == null || id.isEmpty) {
                  onTeamLeaderChanged(null, null);
                } else {
                  final emp = teamLeaders.firstWhere((e) => e.uid == id);
                  onTeamLeaderChanged(id, emp.name);
                }
              },
            ),
            const SizedBox(height: 12),

            // ── QC Reviewer ───────────────────────────────────────────
            DropdownButtonFormField<String>(
              initialValue: reviewers.any((e) => e.uid == selectedQcId)
                  ? selectedQcId
                  : '',
              decoration: _dec('QC Reviewer', Icons.verified_outlined),
              borderRadius: BorderRadius.circular(14),
              hint: const Text('Select QC Reviewer'),
              items: [
                ...noneItem,
                ...reviewers.map(
                  (e) => DropdownMenuItem(
                    value: e.uid,
                    child: Text(e.name),
                  ),
                ),
              ],
              onChanged: (id) {
                if (id == null || id.isEmpty) {
                  onQcChanged(null, null);
                } else {
                  final emp = reviewers.firstWhere((e) => e.uid == id);
                  onQcChanged(id, emp.name);
                }
              },
            ),
            const SizedBox(height: 12),

            // ── PM ────────────────────────────────────────────────────
            DropdownButtonFormField<String>(
              initialValue:
                  allStaff.any((e) => e.uid == selectedPmId) ? selectedPmId : '',
              decoration: _dec('Project Manager (PM)', Icons.badge_outlined),
              borderRadius: BorderRadius.circular(14),
              hint: const Text('Select Project Manager'),
              items: [
                ...noneItem,
                ...allStaff.map(
                  (e) => DropdownMenuItem(
                    value: e.uid,
                    child: Text(e.name),
                  ),
                ),
              ],
              onChanged: (id) {
                if (id == null || id.isEmpty) {
                  onPmChanged(null, null);
                } else {
                  final emp = allStaff.firstWhere((e) => e.uid == id);
                  onPmChanged(id, emp.name);
                }
              },
            ),

            // ── Summary badge ─────────────────────────────────────────
            if (selectedTeamLeaderId != null ||
                selectedQcId != null ||
                selectedPmId != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.group_outlined, size: 14, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Project team assigned — QC will be auto-filled on new tasks',
                      style: TextStyle(fontSize: 11, color: cs.primary),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

