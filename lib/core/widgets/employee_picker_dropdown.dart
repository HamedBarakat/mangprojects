import 'package:flutter/material.dart';
import '../../features/employees/data/models/employee_model.dart';

// ══════════════════════════════════════════════════════════════════════════════
// EmployeePickerDropdown
//
// Reusable widget that opens a searchable, department-filtered, checkbox-based
// employee picker dialog.
//
// Usage:
//   EmployeePickerDropdown(
//     label: 'Team Leader',
//     employees: employees,          // pre-fetched list
//     selectedIds: [tlId],
//     multiSelect: false,
//     onChanged: (ids, names) { ... },
//   )
// ══════════════════════════════════════════════════════════════════════════════

class EmployeePickerDropdown extends StatefulWidget {
  /// Display label above the trigger button.
  final String label;

  /// All employees to choose from (already fetched by the caller).
  final List<EmployeeModel> employees;

  /// Currently selected employee IDs.
  final List<String> selectedIds;

  /// true = multi-select checkboxes; false = single-select (radio-like).
  final bool multiSelect;

  /// Called when selection changes. Provides both ids and display names.
  final void Function(List<String> ids, List<String> names) onChanged;

  /// Optional hint shown inside the trigger when nothing is selected.
  final String? hint;

  /// Optional leading icon for the trigger button.
  final IconData? prefixIcon;

  const EmployeePickerDropdown({
    super.key,
    required this.label,
    required this.employees,
    required this.selectedIds,
    required this.onChanged,
    this.multiSelect = false,
    this.hint,
    this.prefixIcon,
  });

  @override
  State<EmployeePickerDropdown> createState() => _EmployeePickerDropdownState();
}

class _EmployeePickerDropdownState extends State<EmployeePickerDropdown> {
  List<String> get _selectedNames {
    return widget.selectedIds
        .map((id) {
          final emp = widget.employees.where((e) => e.uid == id).firstOrNull;
          return emp?.name ?? id;
        })
        .toList();
  }

  Future<void> _openPicker() async {
    final result = await showDialog<_PickerResult>(
      context: context,
      builder: (_) => _EmployeePickerDialog(
        employees: widget.employees,
        initialSelectedIds: List.from(widget.selectedIds),
        multiSelect: widget.multiSelect,
        label: widget.label,
      ),
    );

    if (result != null) {
      final ids = result.selectedIds;
      final names = ids
          .map((id) =>
              widget.employees.where((e) => e.uid == id).firstOrNull?.name ??
              id)
          .toList();
      widget.onChanged(ids, names);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedNames = _selectedNames;
    final hasSelection = selectedNames.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label ────────────────────────────────────────────────────────────
        if (widget.label.isNotEmpty) ...[
          Row(
            children: [
              if (widget.prefixIcon != null) ...[
                Icon(widget.prefixIcon, size: 16, color: cs.primary),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
              if (hasSelection && widget.multiSelect) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedNames.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
        ],

        // ── Trigger button ────────────────────────────────────────────────
        GestureDetector(
          onTap: _openPicker,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outline.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: hasSelection
                      ? widget.multiSelect
                          ? Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: selectedNames
                                  .map(
                                    (name) => Chip(
                                      label: Text(name,
                                          style: const TextStyle(fontSize: 12)),
                                      visualDensity: VisualDensity.compact,
                                      deleteIcon: const Icon(Icons.close,
                                          size: 14),
                                      onDeleted: () {
                                        final emp = widget.employees
                                            .where((e) => e.name == name)
                                            .firstOrNull;
                                        if (emp == null) return;
                                        final newIds = List<String>.from(
                                            widget.selectedIds)
                                          ..remove(emp.uid);
                                        final newNames = newIds
                                            .map((id) => widget.employees
                                                    .where((e) => e.uid == id)
                                                    .firstOrNull
                                                    ?.name ??
                                                id)
                                            .toList();
                                        widget.onChanged(newIds, newNames);
                                      },
                                    ),
                                  )
                                  .toList(),
                            )
                          : Text(
                              selectedNames.first,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 14,
                              ),
                            )
                      : Text(
                          widget.hint ?? 'Select ${widget.label}...',
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.45),
                            fontSize: 14,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: cs.onSurface.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Internal result model ────────────────────────────────────────────────────

class _PickerResult {
  final List<String> selectedIds;
  const _PickerResult(this.selectedIds);
}

// ── Picker dialog ────────────────────────────────────────────────────────────

class _EmployeePickerDialog extends StatefulWidget {
  final List<EmployeeModel> employees;
  final List<String> initialSelectedIds;
  final bool multiSelect;
  final String label;

  const _EmployeePickerDialog({
    required this.employees,
    required this.initialSelectedIds,
    required this.multiSelect,
    required this.label,
  });

  @override
  State<_EmployeePickerDialog> createState() => _EmployeePickerDialogState();
}

class _EmployeePickerDialogState extends State<_EmployeePickerDialog> {
  late List<String> _selectedIds;
  String _search = '';
  String _deptFilter = 'all';

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.initialSelectedIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _departments {
    final depts = widget.employees
        .map((e) => e.department)
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return depts;
  }

  List<EmployeeModel> get _filtered {
    var list = widget.employees;
    if (_deptFilter != 'all') {
      list = list.where((e) => e.department == _deptFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((e) =>
              e.name.toLowerCase().contains(q) ||
              e.email.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  String _deptLabel(String dept) {
    if (dept == 'all') return 'All';
    return dept
        .split('_')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  void _toggle(String uid) {
    setState(() {
      if (widget.multiSelect) {
        if (_selectedIds.contains(uid)) {
          _selectedIds.remove(uid);
        } else {
          _selectedIds.add(uid);
        }
      } else {
        // Single-select
        if (_selectedIds.contains(uid)) {
          _selectedIds.clear();
        } else {
          _selectedIds
            ..clear()
            ..add(uid);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered;
    final depts = _departments;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: cs.surfaceContainerHighest,
              child: Row(
                children: [
                  Icon(Icons.people_outline, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Select ${widget.label}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  if (_selectedIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedIds.length} selected',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),

            // ── Search bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
            ),

            // ── Department filter chips ───────────────────────────────────
            if (depts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _DeptChip(
                        label: 'All',
                        selected: _deptFilter == 'all',
                        onTap: () => setState(() => _deptFilter = 'all'),
                        cs: cs,
                      ),
                      ...depts.map(
                        (d) => _DeptChip(
                          label: _deptLabel(d),
                          selected: _deptFilter == d,
                          onTap: () => setState(() => _deptFilter = d),
                          cs: cs,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const Divider(height: 16, indent: 12, endIndent: 12),

            // ── Employee list ────────────────────────────────────────────
            Flexible(
              child: filtered.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No employees found',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final emp = filtered[i];
                        final isSelected = _selectedIds.contains(emp.uid);
                        return ListTile(
                          dense: true,
                          leading: widget.multiSelect
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggle(emp.uid),
                                  activeColor: cs.primary,
                                )
                              : Radio<String>(
                                  value: emp.uid,
                                  groupValue: _selectedIds.isEmpty
                                      ? null
                                      : _selectedIds.first,
                                  onChanged: (_) => _toggle(emp.uid),
                                  activeColor: cs.primary,
                                ),
                          title: Text(emp.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(
                            _deptLabel(emp.department),
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withOpacity(0.55)),
                          ),
                          onTap: () => _toggle(emp.uid),
                          selected: isSelected,
                          selectedTileColor: cs.primary.withOpacity(0.06),
                        );
                      },
                    ),
            ),

            const Divider(height: 1),

            // ── Action buttons ───────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedIds.clear());
                    },
                    child: const Text('Clear All'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, _PickerResult(_selectedIds)),
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Department filter chip ────────────────────────────────────────────────────

class _DeptChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _DeptChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withOpacity(0.12)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? cs.primary.withOpacity(0.6)
                  : cs.outline.withOpacity(0.25),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? cs.primary : cs.onSurface.withOpacity(0.6),
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
