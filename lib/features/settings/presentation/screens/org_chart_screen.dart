import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../employees/data/models/employee_model.dart';
import '../../../employees/presentation/controllers/employee_providers.dart';

// ── Org Chart Screen ──────────────────────────────────────────────────────────
class OrgChartScreen extends ConsumerWidget {
  const OrgChartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final employeesAsync = ref.watch(employeesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Org Chart'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: cs.outlineVariant),
        ),
      ),
      body: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (employees) {
          // بناء الشجرة من قائمة الموظفين
          final tree = _buildTree(employees);
          if (tree.isEmpty) {
            return const Center(
              child: Text('No employees found', style: TextStyle(fontSize: 16)),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
            children: tree
                .map((node) => _OrgNode(node: node, depth: 0))
                .toList(),
          );
        },
      ),
    );
  }

  /// يبني شجرة التسلسل الهرمي من قائمة الموظفين المسطحة
  List<_EmployeeNode> _buildTree(List<EmployeeModel> employees) {
    final Map<String, _EmployeeNode> nodeMap = {
      for (final e in employees) e.uid: _EmployeeNode(employee: e),
    };
    final employeeIds = nodeMap.keys.toSet();
    final List<_EmployeeNode> roots = [];

    for (final node in nodeMap.values) {
      final parentId = node.employee.reportToUserId;
      if (parentId != null &&
          parentId.isNotEmpty &&
          employeeIds.contains(parentId)) {
        nodeMap[parentId]!.children.add(node);
      } else {
        // لا يوجد رئيس مباشر → عقدة جذر
        roots.add(node);
      }
    }

    // رتب كل مستوى حسب الاسم
    void sortChildren(_EmployeeNode node) {
      node.children.sort((a, b) => a.employee.name.compareTo(b.employee.name));
      for (final child in node.children) {
        sortChildren(child);
      }
    }

    roots.sort((a, b) => a.employee.name.compareTo(b.employee.name));
    for (final root in roots) {
      sortChildren(root);
    }
    return roots;
  }
}

class _EmployeeNode {
  final EmployeeModel employee;
  final List<_EmployeeNode> children = [];
  _EmployeeNode({required this.employee});
}

// ── Org Node Widget ───────────────────────────────────────────────────────────
class _OrgNode extends StatefulWidget {
  final _EmployeeNode node;
  final int depth;
  const _OrgNode({required this.node, required this.depth});

  @override
  State<_OrgNode> createState() => _OrgNodeState();
}

class _OrgNodeState extends State<_OrgNode> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final emp = widget.node.employee;
    final hasChildren = widget.node.children.isNotEmpty;

    // لون الخلفية يتغير حسب العمق
    final depthColors = [
      cs.primary.withOpacity(0.08),
      cs.tertiary.withOpacity(0.07),
      cs.secondary.withOpacity(0.07),
      cs.surfaceContainerHighest,
    ];
    final bgColor = depthColors[widget.depth.clamp(0, depthColors.length - 1)];

    final isInactive = emp.status != 'active';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── بطاقة الموظف ────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.only(left: widget.depth * 20.0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // خط رأسي للربط (ليس في الجذر)
                if (widget.depth > 0) ...[
                  Container(
                    width: 2,
                    color: cs.outlineVariant,
                    margin: const EdgeInsets.only(right: 12),
                  ),
                ],
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isInactive
                            ? cs.outlineVariant.withOpacity(0.5)
                            : cs.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          // أفاتار الاسم
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: isInactive
                                ? AppColors.slate600
                                : cs.primary.withOpacity(0.15),
                            child: Text(
                              emp.name.isNotEmpty
                                  ? emp.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: isInactive
                                    ? AppColors.slate400
                                    : cs.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // الاسم والمنصب
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        emp.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: isInactive
                                              ? cs.onSurface.withOpacity(0.5)
                                              : cs.onSurface,
                                        ),
                                      ),
                                    ),
                                    if (isInactive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.slate700,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Inactive',
                                          style: TextStyle(
                                              color: AppColors.slate400,
                                              fontSize: 10),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  emp.jobTitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                if (emp.department.isNotEmpty)
                                  Text(
                                    emp.department,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurface.withOpacity(0.4),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // زر التوسيع/الطي
                          if (hasChildren)
                            IconButton(
                              onPressed: () =>
                                  setState(() => _expanded = !_expanded),
                              icon: AnimatedRotation(
                                turns: _expanded ? 0 : -0.25,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.expand_more_rounded,
                                  color: cs.onSurface.withOpacity(0.6),
                                ),
                              ),
                              tooltip: _expanded ? 'Collapse' : 'Expand',
                            )
                          else
                            const SizedBox(width: 8),
                          // عدد المرؤوسين
                          if (hasChildren)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${widget.node.children.length}',
                                style: TextStyle(
                                  color: cs.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── الأبناء ──────────────────────────────────────────────────────
        if (hasChildren && _expanded)
          ...widget.node.children.map(
            (child) => _OrgNode(node: child, depth: widget.depth + 1),
          ),
      ],
    );
  }
}
