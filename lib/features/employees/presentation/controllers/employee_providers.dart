import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/employee_model.dart';
import '../../data/employee_repository.dart';
import '../../../../features/office/presentation/controllers/office_providers.dart';
import '../../../../features/home/presentation/controllers/home_providers.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository();
});

// ── Watch all employees for current office ────────────────────────────────────
final employeesProvider = StreamProvider<List<EmployeeModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref
          .watch(employeeRepositoryProvider)
          .watchEmployees(user.officeId);
    },
    loading: () => const Stream.empty(),
    error: (_, _) => const Stream.empty(),
  );
});

final clientAccountsProvider = StreamProvider<List<EmployeeModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref
          .watch(employeeRepositoryProvider)
          .watchClientAccounts(user.officeId);
    },
    loading: () => const Stream.empty(),
    error: (_, _) => const Stream.empty(),
  );
});

// ── Filter state ──────────────────────────────────────────────────────────────
final employeeFilterProvider = StateProvider<String>((ref) => 'all');
final employeeDepartmentFilterProvider = StateProvider<String>((ref) => 'all');

// ── Filtered employees ────────────────────────────────────────────────────────
final filteredEmployeesProvider = Provider<List<EmployeeModel>>((ref) {
  final employeesAsync = ref.watch(employeesProvider);
  final statusFilter = ref.watch(employeeFilterProvider);
  final deptFilter = ref.watch(employeeDepartmentFilterProvider);

  return employeesAsync.when(
    data: (employees) {
      var filtered = employees;
      if (statusFilter != 'all') {
        filtered = filtered.where((e) => e.status == statusFilter).toList();
      }
      if (deptFilter != 'all') {
        filtered = filtered
            .where(
              (e) => e.department.toLowerCase() == deptFilter.toLowerCase(),
            )
            .toList();
      }
      return filtered;
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

// ── Generate employee code ────────────────────────────────────────────────────
final employeeCodeProvider = FutureProvider<String>((ref) async {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) async {
      if (user == null) return 'EMP001';
      return await ref
          .watch(employeeRepositoryProvider)
          .generateEmployeeCode(user.officeId);
    },
    loading: () async => 'EMP001',
    error: (_, _) async => 'EMP001',
  );
});
