import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/employee_providers.dart';
import '../widgets/employee_card.dart';
import 'add_edit_employee_screen.dart';

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final employees = ref.watch(filteredEmployeesProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final statusFilter = ref.watch(employeeFilterProvider);
    final deptFilter = ref.watch(employeeDepartmentFilterProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: const Text(
          'Employees',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditEmployeeScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filters ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                // Status filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: statusFilter == 'all',
                        onTap: () =>
                            ref.read(employeeFilterProvider.notifier).state =
                                'all',
                      ),
                      _FilterChip(
                        label: 'Active',
                        selected: statusFilter == 'active',
                        onTap: () =>
                            ref.read(employeeFilterProvider.notifier).state =
                                'active',
                      ),
                      _FilterChip(
                        label: 'Suspended',
                        selected: statusFilter == 'suspended',
                        onTap: () =>
                            ref.read(employeeFilterProvider.notifier).state =
                                'suspended',
                      ),
                      _FilterChip(
                        label: 'Resigned',
                        selected: statusFilter == 'resigned',
                        onTap: () =>
                            ref.read(employeeFilterProvider.notifier).state =
                                'resigned',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Department filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All Depts',
                        selected: deptFilter == 'all',
                        color: cs.primary,
                        onTap: () =>
                            ref
                                    .read(
                                      employeeDepartmentFilterProvider.notifier,
                                    )
                                    .state =
                                'all',
                      ),
                      _FilterChip(
                        label: 'Electrical',
                        selected: deptFilter == 'electrical',
                        color: Colors.amber.shade700,
                        onTap: () =>
                            ref
                                    .read(
                                      employeeDepartmentFilterProvider.notifier,
                                    )
                                    .state =
                                'electrical',
                      ),
                      _FilterChip(
                        label: 'Mechanical',
                        selected: deptFilter == 'mechanical',
                        color: Colors.blue.shade700,
                        onTap: () =>
                            ref
                                    .read(
                                      employeeDepartmentFilterProvider.notifier,
                                    )
                                    .state =
                                'mechanical',
                      ),
                      _FilterChip(
                        label: 'Civil',
                        selected: deptFilter == 'civil',
                        color: Colors.brown.shade600,
                        onTap: () =>
                            ref
                                    .read(
                                      employeeDepartmentFilterProvider.notifier,
                                    )
                                    .state =
                                'civil',
                      ),
                      _FilterChip(
                        label: 'Architecture',
                        selected: deptFilter == 'architecture',
                        color: Colors.purple.shade600,
                        onTap: () =>
                            ref
                                    .read(
                                      employeeDepartmentFilterProvider.notifier,
                                    )
                                    .state =
                                'architecture',
                      ),
                      _FilterChip(
                        label: 'Management',
                        selected: deptFilter == 'management',
                        color: cs.primary,
                        onTap: () =>
                            ref
                                    .read(
                                      employeeDepartmentFilterProvider.notifier,
                                    )
                                    .state =
                                'management',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── List ───────────────────────────────────────────────────────
          Expanded(
            child: employeesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (_) {
                if (employees.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 64,
                          color: cs.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No employees found',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final emp = employees[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EmployeeCard(
                        employee: emp,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AddEditEmployeeScreen(employee: emp),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEditEmployeeScreen()),
        ),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Employee'),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? c : c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : c,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
