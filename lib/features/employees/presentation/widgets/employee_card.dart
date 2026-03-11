import 'package:flutter/material.dart';

import '../../data/models/employee_model.dart';

class EmployeeCard extends StatelessWidget {
  final EmployeeModel employee;
  final VoidCallback onTap;

  const EmployeeCard({super.key, required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: _getDeptColor(
                  employee.department,
                  cs,
                ).withValues(alpha: 0.15),
                child: Text(
                  employee.name.isNotEmpty
                      ? employee.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: _getDeptColor(employee.department, cs),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      employee.jobTitleLabel,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _DeptChip(
                          label: employee.departmentLabel,
                          color: _getDeptColor(employee.department, cs),
                        ),
                        const SizedBox(width: 6),
                        _StatusChip(status: employee.status),
                      ],
                    ),
                  ],
                ),
              ),

              // Employee code
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    employee.employeeCode,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Rating stars
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < employee.rating.round()
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 14,
                        color: Colors.amber,
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getDeptColor(String dept, ColorScheme cs) {
    switch (dept) {
      case 'electrical':
        return Colors.amber.shade700;
      case 'mechanical':
        return Colors.blue.shade700;
      case 'civil':
        return Colors.brown.shade600;
      case 'architecture':
        return Colors.purple.shade600;
      case 'management':
        return cs.primary;
      default:
        return cs.primary;
    }
  }
}

class _DeptChip extends StatelessWidget {
  final String label;
  final Color color;

  const _DeptChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = Colors.green;
        label = 'Active';
        break;
      case 'suspended':
        color = Colors.orange;
        label = 'Suspended';
        break;
      case 'resigned':
        color = Colors.red;
        label = 'Resigned';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
