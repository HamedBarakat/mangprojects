import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/project_model.dart';
import '../controllers/project_providers.dart';
import '../../../../features/home/presentation/controllers/home_providers.dart';
import '../../../../features/office/presentation/controllers/office_settings_providers.dart';

// ── Clients provider ──────────────────────────────────────────────────────────
final _clientUsersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, officeId) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('officeId', isEqualTo: officeId)
        .where('role', isEqualTo: 'client')
        .get();
    return snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
  },
);

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
      _selectedClientId   = p.clientId;
      _selectedClientName = p.clientName;
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
          'clientId':   _selectedClientId,
          'clientName': _selectedClientName.isNotEmpty
              ? _selectedClientName
              : _clientNameController.text.trim(),
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
          'clientId':   _selectedClientId,
          'clientName': _selectedClientName.isNotEmpty
              ? _selectedClientName
              : _clientNameController.text.trim(),
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

    if (!_isEditing && _projectCodeController.text.isEmpty) {
      ref.watch(projectCodeProvider).whenData((code) {
        if (_projectCodeController.text.isEmpty) {
          _projectCodeController.text = code;
        }
      });
    }

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
              officeId: ref.read(currentUserProvider).value?.officeId ?? '',
              selectedClientId:   _selectedClientId,
              selectedClientName: _selectedClientName,
              fallbackController: _clientNameController,
              onChanged: (id, name) => setState(() {
                _selectedClientId   = id;
                _selectedClientName = name;
                _clientNameController.text = name;
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
              value: projectTypes.contains(_type) ? _type : null,
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
      value: value,
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
// CLIENT DROPDOWN WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class _ClientDropdown extends ConsumerWidget {
  final String officeId;
  final String selectedClientId;
  final String selectedClientName;
  final TextEditingController fallbackController;
  final void Function(String id, String name) onChanged;

  const _ClientDropdown({
    required this.officeId,
    required this.selectedClientId,
    required this.selectedClientName,
    required this.fallbackController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final clientsAsync = ref.watch(_clientUsersProvider(officeId));

    return clientsAsync.when(
      loading: () => _buildFallback(context, cs),
      error: (_, __) => _buildFallback(context, cs),
      data: (clients) {
        // لو مفيش clients → text field عادي
        if (clients.isEmpty) return _buildFallback(context, cs);

        // قيمة محددة — نتأكد إنها موجودة في الـ list
        final validId = clients.any((c) => c['uid'] == selectedClientId)
            ? selectedClientId
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dropdown من الـ clients المسجلين
            DropdownButtonFormField<String>(
              value: validId,
              decoration: InputDecoration(
                labelText: 'Client',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              hint: const Text('Select Client'),
              items: [
                // خيار فاضي
                const DropdownMenuItem(value: '', child: Text('— No Client —')),
                ...clients.map((c) => DropdownMenuItem(
                  value: c['uid'] as String,
                  child: Text(c['name'] as String? ?? c['uid']),
                )),
              ],
              onChanged: (uid) {
                if (uid == null || uid.isEmpty) {
                  onChanged('', '');
                } else {
                  final client = clients.firstWhere((c) => c['uid'] == uid);
                  onChanged(uid, client['name'] as String? ?? '');
                }
              },
            ),
            // لو اختار client بيظهر اسمه
            if (selectedClientId.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const SizedBox(width: 4),
                Icon(Icons.check_circle_outline, size: 14, color: cs.primary),
                const SizedBox(width: 4),
                Text('Linked to client account',
                    style: TextStyle(fontSize: 11, color: cs.primary)),
              ]),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
