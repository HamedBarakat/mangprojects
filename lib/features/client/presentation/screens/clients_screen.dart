import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/client/data/models/client_model.dart';
import '../../../../features/client/data/providers/client_providers.dart';
import '../../../../features/employees/data/models/employee_model.dart';
import '../../../../features/employees/presentation/controllers/employee_providers.dart';
import '../../../../features/employees/presentation/screens/add_edit_employee_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// CLIENTS SCREEN  (Admin — manage clients + client accounts)
// ══════════════════════════════════════════════════════════════════════════════

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
    final cs = Theme.of(context).colorScheme;
    final clientsAsync = ref.watch(clientsStreamProvider);
    final employeesAsync = ref.watch(clientAccountsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Clients',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Client Records'),
            Tab(text: 'Client Accounts'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              if (_tabController.index == 0) {
                _openAddEditClient(context, null);
              } else {
                _openClientPickerThenAddAccount(context);
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildClientRecordsTab(context, cs, clientsAsync),
          _buildClientAccountsTab(context, cs, employeesAsync, clientsAsync),
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
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _tabController.index == 0 ? 'Add Client' : 'Add Client Account',
        ),
      ),
    );
  }

  Widget _buildClientRecordsTab(
    BuildContext context,
    ColorScheme cs,
    AsyncValue<List<ClientModel>> clientsAsync,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: TextField(
            onChanged: (v) => setState(() => _recordsSearch = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search clients...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        Expanded(
          child: clientsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (clients) {
              final filtered =
                  clients
                      .where(
                        (c) =>
                            _recordsSearch.isEmpty ||
                            c.name.toLowerCase().contains(_recordsSearch) ||
                            (c.phone?.toLowerCase().contains(_recordsSearch) ??
                                false) ||
                            (c.email?.toLowerCase().contains(_recordsSearch) ??
                                false),
                      )
                      .toList()
                    ..sort((a, b) => a.name.compareTo(b.name));

              if (filtered.isEmpty) {
                return _EmptyState(
                  icon: Icons.business_outlined,
                  title: _recordsSearch.isNotEmpty
                      ? 'No Results Found'
                      : 'No Clients Yet',
                  subtitle: _recordsSearch.isNotEmpty
                      ? 'Try a different search term'
                      : 'Add your first client to get started',
                  actionLabel: _recordsSearch.isNotEmpty ? null : 'Add Client',
                  onAction: _recordsSearch.isNotEmpty
                      ? null
                      : () => _openAddEditClient(context, null),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
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
    ColorScheme cs,
    AsyncValue<List<EmployeeModel>> employeesAsync,
    AsyncValue<List<ClientModel>> clientsAsync,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: TextField(
            onChanged: (v) => setState(() => _accountsSearch = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search client accounts...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        Expanded(
          child: employeesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (employees) {
              final clientAccounts =
                  employees
                      .where((e) => e.role == 'client')
                      .where(
                        (e) =>
                            _accountsSearch.isEmpty ||
                            e.name.toLowerCase().contains(_accountsSearch) ||
                            e.email.toLowerCase().contains(_accountsSearch) ||
                            e.phone.toLowerCase().contains(_accountsSearch) ||
                            e.employeeCode.toLowerCase().contains(
                              _accountsSearch,
                            ),
                      )
                      .toList()
                    ..sort((a, b) => a.name.compareTo(b.name));

              final clients = clientsAsync.value ?? [];

              if (clientAccounts.isEmpty) {
                return _EmptyState(
                  icon: Icons.person_outline_rounded,
                  title: _accountsSearch.isNotEmpty
                      ? 'No Results Found'
                      : 'No Client Accounts Yet',
                  subtitle: _accountsSearch.isNotEmpty
                      ? 'Try a different search term'
                      : 'Add a client login account and link it to a client record',
                  actionLabel: _accountsSearch.isNotEmpty
                      ? null
                      : 'Add Client Account',
                  onAction: _accountsSearch.isNotEmpty
                      ? null
                      : () => _openAddClientAccount(context, null),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditClientScreen(client: client)),
    );
  }

  void _openAddClientAccount(
    BuildContext context,
    EmployeeModel? employee, {
    String? linkedClientId,
    String? linkedClientName,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditEmployeeScreen(
          employee: employee,
          initialRole: 'client',
          lockRole: employee == null,
          initialLinkedClientId: employee?.linkedClientId ?? linkedClientId,
          screenTitle: employee == null
              ? 'Add Client Account'
              : 'Edit Client Account',
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
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                const Text(
                  'Select Client',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: clients.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final client = clients[i];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tileColor: cs.surfaceContainerHighest,
                        leading: CircleAvatar(
                          backgroundColor: cs.primary.withOpacity(0.12),
                          child: Text(
                            client.name.isNotEmpty
                                ? client.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(client.name),
                        subtitle:
                            (client.email != null && client.email!.isNotEmpty)
                            ? Text(client.email!)
                            : ((client.phone != null &&
                                      client.phone!.isNotEmpty)
                                  ? Text(client.phone!)
                                  : null),
                        onTap: () => Navigator.pop(ctx, client),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedClient == null || !mounted) return;

    _openAddClientAccount(
      context,
      null,
      linkedClientId: selectedClient.id,
      linkedClientName: selectedClient.name,
    );
  }

  Future<void> _toggleClientActive(ClientModel client) async {
    final repo = ref.read(clientRepositoryProvider);
    await repo.updateClient(client.id, {'isActive': !client.isActive});
  }

  Future<void> _toggleClientAccountStatus(EmployeeModel employee) async {
    final repo = ref.read(employeeRepositoryProvider);
    final newStatus = employee.status == 'active' ? 'suspended' : 'active';
    await repo.toggleStatus(employee.uid, newStatus);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CLIENT CARD
// ══════════════════════════════════════════════════════════════════════════════

class _ClientCard extends StatelessWidget {
  final ClientModel client;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const _ClientCard({
    required this.client,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: client.isActive
              ? cs.outlineVariant.withOpacity(0.4)
              : cs.outlineVariant.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Opacity(
        opacity: client.isActive ? 1.0 : 0.55,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
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
                          child: Text(
                            client.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: client.isActive
                                ? Colors.green.withOpacity(0.12)
                                : Colors.grey.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            client.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: client.isActive
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (client.phone != null && client.phone!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 12,
                            color: cs.onSurface.withOpacity(0.45),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            client.phone!,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (client.contacts.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 12,
                            color: cs.onSurface.withOpacity(0.45),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${client.contacts.length} contact${client.contacts.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: cs.onSurface.withOpacity(0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (val) {
                  if (val == 'edit') onEdit();
                  if (val == 'toggle') onToggleActive();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          client.isActive
                              ? Icons.block_outlined
                              : Icons.check_circle_outline,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(client.isActive ? 'Deactivate' : 'Activate'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CLIENT ACCOUNT CARD
// ══════════════════════════════════════════════════════════════════════════════

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
    final cs = Theme.of(context).colorScheme;
    final isActive = account.status == 'active';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? cs.outlineVariant.withOpacity(0.4)
              : cs.outlineVariant.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.65,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    account.name.isNotEmpty
                        ? account.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: cs.onSecondaryContainer,
                    ),
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
                          child: Text(
                            account.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.green.withOpacity(0.12)
                                : Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isActive ? 'Active' : account.statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isActive ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.65),
                      ),
                    ),
                    if (account.phone.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        account.phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.55),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniChip(
                          icon: Icons.badge_outlined,
                          label: account.employeeCode.isEmpty
                              ? 'No Code'
                              : account.employeeCode,
                        ),
                        _MiniChip(
                          icon: Icons.business_outlined,
                          label:
                              linkedClientName == null ||
                                  linkedClientName!.isEmpty
                              ? 'Unlinked Client'
                              : linkedClientName!,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: cs.onSurface.withOpacity(0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (val) {
                  if (val == 'edit') onEdit();
                  if (val == 'toggle') onToggleActive();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          isActive
                              ? Icons.block_outlined
                              : Icons.check_circle_outline,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(isActive ? 'Suspend' : 'Activate'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
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
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withOpacity(0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADD / EDIT CLIENT SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class AddEditClientScreen extends ConsumerStatefulWidget {
  final ClientModel? client;
  const AddEditClientScreen({super.key, this.client});

  @override
  ConsumerState<AddEditClientScreen> createState() =>
      _AddEditClientScreenState();
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
      _contacts.addAll(
        c.contacts.map(
          (ct) => {
            'id': ct.id,
            'name': ct.name,
            'role': ct.role,
            'phone': ct.phone ?? '',
            'email': ct.email ?? '',
          },
        ),
      );
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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
          _isEditing ? 'Edit Client' : 'New Client',
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
              controller: _nameController,
              label: 'Client Name',
              icon: Icons.business_outlined,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _phoneController,
              label: 'Phone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _addressController,
              label: 'Address',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _notesController,
              label: 'Notes',
              icon: Icons.notes_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.toggle_on_outlined, color: cs.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Active',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: 'Contacts'),
            const SizedBox(height: 12),
            ..._contacts.asMap().entries.map(
              (e) => _ContactTile(
                contact: e.value,
                onEdit: () => _openContactDialog(index: e.key),
                onDelete: () => setState(() => _contacts.removeAt(e.key)),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openContactDialog(),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add Contact'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
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
                        _isEditing ? 'Update Client' : 'Add Client',
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEdit ? 'Edit Contact' : 'Add Contact',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: nameCtrl,
              label: 'Name',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 10),
            _buildField(
              controller: roleCtrl,
              label: 'Role / Title',
              icon: Icons.work_outline,
            ),
            const SizedBox(height: 10),
            _buildField(
              controller: phoneCtrl,
              label: 'Phone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            _buildField(
              controller: emailCtrl,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final contact = {
                    'id':
                        existing?['id'] ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': nameCtrl.text.trim(),
                    'role': roleCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                  };
                  setState(() {
                    if (isEdit) {
                      _contacts[index] = contact;
                    } else {
                      _contacts.add(contact);
                    }
                  });
                  Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(isEdit ? 'Update' : 'Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CONTACT TILE
// ══════════════════════════════════════════════════════════════════════════════

class _ContactTile extends StatelessWidget {
  final Map<String, String> contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactTile({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline_rounded, color: cs.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact['name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if ((contact['role'] ?? '').isNotEmpty)
                  Text(
                    contact['role']!,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withOpacity(0.55),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: cs.onSurface.withOpacity(0.5),
            ),
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: cs.error.withOpacity(0.7),
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: cs.primary.withOpacity(0.6)),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel!),
            ),
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
