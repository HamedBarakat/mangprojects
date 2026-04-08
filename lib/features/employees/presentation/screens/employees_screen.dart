import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/employee_providers.dart';
import '../widgets/employee_card.dart';
import 'add_edit_employee_screen.dart';
import '../../../../core/theme/app_theme.dart';

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employees = ref.watch(filteredEmployeesProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final statusFilter = ref.watch(employeeFilterProvider);
    final deptFilter = ref.watch(employeeDepartmentFilterProvider);

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.scaffoldBg,
      appBar: AppBar(
        title: const Text('Employees'),
        backgroundColor: cs.appBarBg,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: cs.dividerC),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.person_add_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.cyan500.withOpacity(0.12),
                foregroundColor: AppColors.cyan400,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditEmployeeScreen()),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Bar ─────────────────────────────────────────────────
          Container(
            color: cs.appBarBg,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              children: [
                // Status filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(label: 'All', selected: statusFilter == 'all', color: Theme.of(context).colorScheme.subtleText,
                          onTap: () => ref.read(employeeFilterProvider.notifier).state = 'all'),
                      _FilterChip(label: 'Active', selected: statusFilter == 'active', color: AppColors.success,
                          onTap: () => ref.read(employeeFilterProvider.notifier).state = 'active'),
                      _FilterChip(label: 'Suspended', selected: statusFilter == 'suspended', color: AppColors.warning,
                          onTap: () => ref.read(employeeFilterProvider.notifier).state = 'suspended'),
                      _FilterChip(label: 'Resigned', selected: statusFilter == 'resigned', color: AppColors.error,
                          onTap: () => ref.read(employeeFilterProvider.notifier).state = 'resigned'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Department filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(label: 'All Depts', selected: deptFilter == 'all', color: Theme.of(context).colorScheme.subtleText,
                          onTap: () => ref.read(employeeDepartmentFilterProvider.notifier).state = 'all'),
                      _FilterChip(label: 'Electrical', selected: deptFilter == 'electrical', color: AppColors.warning,
                          onTap: () => ref.read(employeeDepartmentFilterProvider.notifier).state = 'electrical'),
                      _FilterChip(label: 'Mechanical', selected: deptFilter == 'mechanical', color: AppColors.info,
                          onTap: () => ref.read(employeeDepartmentFilterProvider.notifier).state = 'mechanical'),
                      _FilterChip(label: 'Civil', selected: deptFilter == 'civil', color: const Color(0xFFA0785A),
                          onTap: () => ref.read(employeeDepartmentFilterProvider.notifier).state = 'civil'),
                      _FilterChip(label: 'Architecture', selected: deptFilter == 'architecture', color: Colors.purple,
                          onTap: () => ref.read(employeeDepartmentFilterProvider.notifier).state = 'architecture'),
                      _FilterChip(label: 'Management', selected: deptFilter == 'management', color: AppColors.cyan600,
                          onTap: () => ref.read(employeeDepartmentFilterProvider.notifier).state = 'management'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 1, color: cs.dividerC),

          // ── List ───────────────────────────────────────────────────────
          Expanded(
            child: employeesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: AppColors.error))),
              data: (_) {
                if (employees.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainer,
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.border),
                          ),
                          child: Icon(Icons.people_outline_rounded, size: 44, color: cs.subtleText),
                        ),
                        const SizedBox(height: 16),
                        Text('No employees found',
                            style: TextStyle(color: Theme.of(context).colorScheme.subtleText, fontSize: 15, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        Text('Try adjusting your filters',
                            style: TextStyle(color: Theme.of(context).colorScheme.subtleText, fontSize: 12)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final emp = employees[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EmployeeCard(
                        employee: emp,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AddEditEmployeeScreen(employee: emp)),
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
        backgroundColor: AppColors.cyan500,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Employee', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color.withOpacity(0.6) : Theme.of(context).colorScheme.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : Theme.of(context).colorScheme.subtleText,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
