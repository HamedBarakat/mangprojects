import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/home/presentation/controllers/home_providers.dart';
import '../../../../features/office/data/models/office_settings_model.dart';
import '../../../../features/office/presentation/controllers/office_settings_providers.dart';

class OfficeListsScreen extends ConsumerWidget {
  const OfficeListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final settingsAsync = ref.watch(officeSettingsProvider);
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: const Text(
          'Manage Lists',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Error loading settings')),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ListSection(
              title: 'Project Types',
              icon: Icons.business_center_rounded,
              color: Colors.blue,
              items: settings.projectTypes,
              field: 'projectTypes',
              officeId: user?.officeId ?? '',
              settings: settings,
            ),
            const SizedBox(height: 16),
            _ListSection(
              title: 'Disciplines',
              icon: Icons.engineering_rounded,
              color: Colors.orange,
              items: settings.disciplines,
              field: 'disciplines',
              officeId: user?.officeId ?? '',
              settings: settings,
            ),
            const SizedBox(height: 16),
            _ListSection(
              title: 'Task Categories',
              icon: Icons.task_alt_rounded,
              color: Colors.green,
              items: settings.taskCategories,
              field: 'taskCategories',
              officeId: user?.officeId ?? '',
              settings: settings,
            ),
            const SizedBox(height: 16),
            _ListSection(
              title: 'Departments',
              icon: Icons.apartment_rounded,
              color: Colors.deepPurple,
              items: settings.departments,
              field: 'departments',
              officeId: user?.officeId ?? '',
              settings: settings,
            ),
          ],
        ),
      ),
    );
  }
}

// ── List Section ──────────────────────────────────────────────────────────────

class _ListSection extends ConsumerWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  final String field;
  final String officeId;
  final OfficeSettingsModel settings;

  const _ListSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.field,
    required this.officeId,
    required this.settings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${items.length} items',
                        style: TextStyle(
                          color: cs.onSurface.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Add button
                IconButton(
                  onPressed: () => _showAddDialog(context, ref),
                  icon: Icon(Icons.add_circle_rounded, color: color),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Items list
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No items yet — tap + to add',
                style: TextStyle(
                  color: cs.onSurface.withOpacity(0.4),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              onReorder: (oldIndex, newIndex) =>
                  _reorder(ref, oldIndex, newIndex),
              itemBuilder: (_, i) => _ItemTile(
                key: ValueKey('${field}_$i'),
                item: items[i],
                color: color,
                onEdit: () => _showEditDialog(context, ref, items[i]),
                onDelete: () => _deleteItem(context, ref, items[i]),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add to $title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Enter item name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      // Check duplicate
      if (items.map((e) => e.toLowerCase()).contains(result.toLowerCase())) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('"$result" already exists')));
        }
        return;
      }
      await ref
          .read(officeSettingsRepositoryProvider)
          .addItem(officeId: officeId, field: field, item: result);
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    String oldItem,
  ) async {
    final controller = TextEditingController(text: oldItem);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit $title item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != oldItem) {
      await ref
          .read(officeSettingsRepositoryProvider)
          .renameItem(
            officeId: officeId,
            field: field,
            oldItem: oldItem,
            newItem: result,
            currentList: items,
          );
    }
  }

  Future<void> _deleteItem(
    BuildContext context,
    WidgetRef ref,
    String item,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Delete "$item" from $title?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(officeSettingsRepositoryProvider)
          .removeItem(officeId: officeId, field: field, item: item);
    }
  }

  Future<void> _reorder(WidgetRef ref, int oldIndex, int newIndex) async {
    final updated = List<String>.from(items);
    if (newIndex > oldIndex) newIndex--;
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    await ref
        .read(officeSettingsRepositoryProvider)
        .updateList(officeId: officeId, field: field, items: updated);
  }
}

// ── Item Tile ─────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final String item;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ItemTile({
    super.key,
    required this.item,
    required this.color,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(item, style: const TextStyle(fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: cs.onSurface.withOpacity(0.5),
            ),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: Colors.red,
            ),
            onPressed: onDelete,
          ),
          Icon(Icons.drag_handle_rounded, color: cs.onSurface.withOpacity(0.3)),
        ],
      ),
    );
  }
}
