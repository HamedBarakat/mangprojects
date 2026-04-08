import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/client/data/models/client_model.dart';
import '../../../../features/client/data/providers/client_providers.dart';
import '../../../../features/employees/data/models/employee_model.dart';
import '../../../../features/employees/presentation/controllers/employee_providers.dart';
import '../../../../features/employees/presentation/screens/add_edit_employee_screen.dart';
import '../../../../core/theme/app_theme.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _recordsSearch = '';
  String _accountsSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsStreamProvider);
    final employeesAsync = ref.watch(clientAccountsProvider);

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.scaffoldBg,
      appBar: AppBar(
        backgroundColor: cs.appBarBg,
        automaticallyImplyLeading: false,
        title: const Text('Clients'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.add_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.cyan500.withOpacity(0.12),
                foregroundColor: AppColors.cyan400,
              ),
              onPressed: () {
                if (_tabController.index == 0) {
                  _openAddEditClient(context, null);
                } else {
                  _openClientPickerThenAddAccount(context);
                }
              },
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Client Records'),
            Tab(text: 'Client Accounts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildClientRecordsTab(context, clientsAsync),
          _buildClientAccountsTab(context, employeesAsync, clientsAsync),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _openAddEditClient(context, null);
          } else {
            _openClientPickerThenAddAccount(context);
          }
        },
        backgroundColor: AppColors.cyan500,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _tabController.index == 0 ? 'Add Client' : 'Add Client Account',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildClientRecordsTab(BuildContext context, AsyncValue<List<ClientModel>> clientsAsync) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.appBarBg,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: TextField(
            onChanged: (v) => setState(() => _recordsSearch = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search clients...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: Theme.of(context).colorScheme.dividerC),
        Expanded(
          child: clientsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
            data: (clients) {
              final filtered = clients
                  .where((c) =>
                      _recordsSearch.isEmpty ||
                      c.name.toLowerCase().contains(_recordsSearch) ||
                      (c.phone?.toLowerCase().contains(_recordsSearch) ?? false) ||
                      (c.email?.toLowerCase().contains(_recordsSearch) ?? false))
                  .toList()
                ..sort((a, b) => a.name.compareTo(b.name));

              if (filtered.isEmpty) {
                return _EmptyState(
                  icon: Icons.business_outlined,
                  title: _recordsSearch.isNotEmpty ? 'No Results Found' : 'No Clients Yet',
                  subtitle: _recordsSearch.isNotEmpty ? 'Try a different search term' : 'Add your first client to get started',
                  actionLabel: _recordsSearch.isNotEmpty ? null : 'Add Client',
                  onAction: _recordsSearch.isNotEmpty ? null : () => _openAddEditClient(context, null),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ClientCard(
                  client: filtered[i],
                  onEdit: () => _openAddEditClient(context, filtered[i]),
                  onToggleActive: () => _toggleClientActive(filtered[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClientAccountsTab(
    BuildContext context,
    AsyncValue<List<EmployeeModel>> employeesAsync,
    AsyncValue<List<ClientModel>> clientsAsync,
  ) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.appBarBg,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: TextField(
            onChanged: (v) => setState(() => _accountsSearch = v.toLowerCase()),
            decoration: const InputDecoration(
              hintText: 'Search client accounts...',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              contentPadding: EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: Theme.of(context).colorScheme.dividerC),
        Expanded(
          child: employeesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
            data: (employees) {
              final clientAccounts = employees
                  .where((e) => e.role == 'client')
                  .where((e) =>
                      _accountsSearch.isEmpty ||
                      e.name.toLowerCase().contains(_accountsSearch) ||
                      e.email.toLowerCase().contains(_accountsSearch) ||
                      e.phone.toLowerCase().contains(_accountsSearch) ||
                      e.employeeCode.toLowerCase().contains(_accountsSearch))
                  .toList()
                ..sort((a, b) => a.name.compareTo(b.name));

              final clients = clientsAsync.value ?? [];

              if (clientAccounts.isEmpty) {
                return _EmptyState(
                  icon: Icons.person_outline_rounded,
                  title: _accountsSearch.isNotEmpty ? 'No Results Found' : 'No Client Accounts Yet',
                  subtitle: _accountsSearch.isNotEmpty
                      ? 'Try a different search term'
                      : 'Add a client login account and link it to a client record',
                  actionLabel: _accountsSearch.isNotEmpty ? null : 'Add Client Account',
                  onAction: _accountsSearch.isNotEmpty ? null : () => _openAddClientAccount(context, null),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                itemCount: clientAccounts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final account = clientAccounts[i];
                  final linkedClient = clients
                      .where((c) => c.id == account.linkedClientId)
                      .cast<ClientModel?>()
                      .firstOrNull;
                  return _ClientAccountCard(
                    account: account,
                    linkedClientName: linkedClient?.name,
                    onEdit: () => _openAddClientAccount(context, account),
                    onToggleActive: () => _toggleClientAccountStatus(account),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _openAddEditClient(BuildContext context, ClientModel? client) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditClientScreen(client: client)));
  }

  void _openAddClientAccount(BuildContext context, EmployeeModel? employee, {String? linkedClientId, String? linkedClientName}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditEmployeeScreen(
          employee: employee,
          initialRole: 'client',
          lockRole: employee == null,
          initialLinkedClientId: employee?.linkedClientId ?? linkedClientId,
          screenTitle: employee == null ? 'Add Client Account' : 'Edit Client Account',
        ),
      ),
    );
  }

  Future<void> _openClientPickerThenAddAccount(BuildContext context) async {
    final clients = ref.read(clientsStreamProvider).value ?? [];
    if (clients.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a client record first')),
      );
      return;
    }

    final selectedClient = await showModalBottomSheet<ClientModel>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Client', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: clients.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final client = clients[i];
                    return Container(
                      decoration: AppDecorations.card(),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.cyan500.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                        title: Text(client.name),
                        subtitle: (client.email != null && client.email!.isNotEmpty)
                            ? Text(client.email!, style: TextStyle(color: Theme.of(context).colorScheme.subtleText))
                            : ((client.phone != null && client.phone!.isNotEmpty)
                                ? Text(client.phone!, style: TextStyle(color: Theme.of(context).colorScheme.subtleText))
                                : null),
                        onTap: () => Navigator.pop(ctx, client),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedClient == null || !mounted) return;
    _openAddClientAccount(context, null, linkedClientId: selectedClient.id, linkedClientName: selectedClient.name);
  }

  Future<void> _toggleClientActive(ClientModel client) async {
    await ref.read(clientRepositoryProvider).updateClient(client.id, {'isActive': !client.isActive});
  }

  Future<void> _toggleClientAccountStatus(EmployeeModel employee) async {
    final newStatus = employee.status == 'active' ? 'suspended' : 'active';
    await ref.read(employeeRepositoryProvider).toggleStatus(employee.uid, newStatus);
  }
}

// ── Client Card ───────────────────────────────────────────────────────────────

class _ClientCard extends StatelessWidget {
  final ClientModel client;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const _ClientCard({required this.client, required this.onEdit, required this.onToggleActive});

  @override
  Widget build(BuildContext context) {
    final isActive = client.isActive;

    return Opacity(
      opacity: isActive ? 1.0 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? Theme.of(context).colorScheme.border : Theme.of(context).colorScheme.border.withOpacity(0.4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.cyan500.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cyan500.withOpacity(0.2)),
              ),
              child: Center(
                child: Text(
                  client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.cyan400),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(client.name,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.success.withOpacity(0.1) : Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isActive ? AppColors.success.withOpacity(0.3) : Theme.of(context).colorScheme.border),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isActive ? AppColors.success : Theme.of(context).colorScheme.subtleText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (client.phone != null && client.phone!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 12, color: Theme.of(context).colorScheme.subtleText),
                        const SizedBox(width: 4),
                        Text(client.phone!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.subtleText)),
                      ],
                    ),
                  ],
                  if (client.contacts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.people_outline, size: 12, color: Theme.of(context).colorScheme.subtleText),
                        const SizedBox(width: 4),
                        Text(
                          '${client.contacts.length} contact${client.contacts.length > 1 ? 's' : ''}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.subtleText),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: Theme.of(context).colorScheme.subtleText),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Theme.of(context).colorScheme.border,
              onSelected: (val) {
                if (val == 'edit') onEdit();
                if (val == 'toggle') onToggleActive();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(children: [
                    Icon(isActive ? Icons.block_outlined : Icons.check_circle_outline, size: 18),
                    const SizedBox(width: 8),
                    Text(isActive ? 'Deactivate' : 'Activate'),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Client Account Card ───────────────────────────────────────────────────────

class _ClientAccountCard extends StatelessWidget {
  final EmployeeModel account;
  final String? linkedClientName;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const _ClientAccountCard({
    required this.account,
    required this.linkedClientName,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = account.status == 'active';

    return Opacity(
      opacity: isActive ? 1.0 : 0.65,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.border,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  account.name.isNotEmpty ? account.name[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(account.name,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.success.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isActive ? AppColors.success.withOpacity(0.3) : AppColors.warning.withOpacity(0.3)),
                        ),
                        child: Text(
                          isActive ? 'Active' : account.statusLabel,
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: isActive ? AppColors.success : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(account.email, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.subtleText)),
                  if (account.phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(account.phone, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.subtleText)),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: [
                      _MiniChip(icon: Icons.badge_outlined, label: account.employeeCode.isEmpty ? 'No Code' : account.employeeCode),
                      _MiniChip(icon: Icons.business_outlined, label: linkedClientName?.isEmpty ?? true ? 'Unlinked Client' : linkedClientName!),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: Theme.of(context).colorScheme.subtleText),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Theme.of(context).colorScheme.border,
              onSelected: (val) {
                if (val == 'edit') onEdit();
                if (val == 'toggle') onToggleActive();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(children: [
                    Icon(isActive ? Icons.block_outlined : Icons.check_circle_outline, size: 18),
                    const SizedBox(width: 8),
                    Text(isActive ? 'Suspend' : 'Activate'),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.border,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.cyan500),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.subtleText, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Add/Edit Client Screen ────────────────────────────────────────────────────

class AddEditClientScreen extends ConsumerStatefulWidget {
  final ClientModel? client;
  const AddEditClientScreen({super.key, this.client});

  @override
  ConsumerState<AddEditClientScreen> createState() => _AddEditClientScreenState();
}

class _AddEditClientScreenState extends ConsumerState<AddEditClientScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;

  bool _isActive = true;
  final List<Map<String, String>> _contacts = [];
  bool get _isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
    _notesController = TextEditingController(text: c?.notes ?? '');
    _isActive = c?.isActive ?? true;
    if (c != null) {
      _contacts.addAll(c.contacts.map((ct) => {
        'id': ct.id, 'name': ct.name, 'role': ct.role,
        'phone': ct.phone ?? '', 'email': ct.email ?? '',
      }));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final repo = ref.read(clientRepositoryProvider);
      final data = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'notes': _notesController.text.trim(),
        'isActive': _isActive,
        'contacts': _contacts,
      };
      if (_isEditing) {
        await repo.updateClient(widget.client!.id, data);
      } else {
        await repo.addClient(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.scaffoldBg,
      appBar: AppBar(
        backgroundColor: cs.appBarBg,
        title: Text(_isEditing ? 'Edit Client' : 'New Client'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: cs.dividerC),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
              ),
            ],
            _SectionTitle(title: 'Basic Information'),
            const SizedBox(height: 12),
            _buildField(controller: _nameController, label: 'Client Name', icon: Icons.business_outlined,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            _buildField(controller: _phoneController, label: 'Phone', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _buildField(controller: _emailController, label: 'Email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _buildField(controller: _addressController, label: 'Address', icon: Icons.location_on_outlined),
            const SizedBox(height: 12),
            _buildField(controller: _notesController, label: 'Notes', icon: Icons.notes_outlined, maxLines: 3),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: AppDecorations.card(),
              child: Row(
                children: [
                  const Icon(Icons.toggle_on_outlined, color: AppColors.cyan500),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Active', style: TextStyle(fontWeight: FontWeight.w500))),
                  Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: 'Contacts'),
            const SizedBox(height: 12),
            ..._contacts.asMap().entries.map((e) => _ContactTile(
              contact: e.value,
              onEdit: () => _openContactDialog(index: e.key),
              onDelete: () => setState(() => _contacts.removeAt(e.key)),
            )),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openContactDialog(),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add Contact'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isLoading ? null : _save,
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Update Client' : 'Add Client',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _openContactDialog({int? index}) {
    final isEdit = index != null;
    final existing = isEdit ? _contacts[index] : null;
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final roleCtrl = TextEditingController(text: existing?['role'] ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: existing?['email'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEdit ? 'Edit Contact' : 'Add Contact',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildField(controller: nameCtrl, label: 'Name', icon: Icons.person_outline),
            const SizedBox(height: 10),
            _buildField(controller: roleCtrl, label: 'Role / Title', icon: Icons.work_outline),
            const SizedBox(height: 10),
            _buildField(controller: phoneCtrl, label: 'Phone', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 10),
            _buildField(controller: emailCtrl, label: 'Email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final contact = {
                    'id': existing?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': nameCtrl.text.trim(),
                    'role': roleCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                  };
                  setState(() { if (isEdit) _contacts[index] = contact; else _contacts.add(contact); });
                  Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(isEdit ? 'Update' : 'Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String label, required IconData icon,
      int maxLines = 1, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller, maxLines: maxLines, keyboardType: keyboardType, validator: validator,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20)),
    );
  }
}

// ── Contact Tile ──────────────────────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  final Map<String, String> contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ContactTile({required this.contact, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AppDecorations.card(),
      child: Row(
        children: [
          const Icon(Icons.person_outline_rounded, color: AppColors.cyan600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
                if ((contact['role'] ?? '').isNotEmpty)
                  Text(contact['role']!, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.subtleText)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.cyan600), onPressed: onEdit),
          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error), onPressed: onDelete),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({required this.icon, required this.title, required this.subtitle, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).colorScheme.border),
            ),
            child: Icon(icon, size: 40, color: Theme.of(context).colorScheme.subtleText),
          ),
          const SizedBox(height: 20),
          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.subtleText), textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.add_rounded), label: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).colorScheme.primary)),
      ],
    );
  }
}
