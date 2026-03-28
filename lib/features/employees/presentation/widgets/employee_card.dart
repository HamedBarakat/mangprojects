import 'package:flutter/material.dart';

import '../../data/models/employee_model.dart';
import '../../../../core/theme/app_theme.dart';

class EmployeeCard extends StatelessWidget {
  final EmployeeModel employee;
  final VoidCallback onTap;

  const EmployeeCard({super.key, required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final deptColor = _getDeptColor(employee.department);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.slate800,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.slate700),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: deptColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: deptColor.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: deptColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.name,
                    style: const TextStyle(
                      color: AppColors.slate100,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    employee.jobTitleLabel,
                    style: const TextStyle(color: AppColors.slate400, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Badge(label: employee.departmentLabel, color: deptColor),
                      const SizedBox(width: 6),
                      _StatusBadge(status: employee.status),
                    ],
                  ),
                ],
              ),
            ),

            // Right side: code + rating
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.slate700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    employee.employeeCode,
                    style: const TextStyle(color: AppColors.slate400, fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < employee.rating.round()
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 13,
                      color: i < employee.rating.round()
                          ? AppColors.warning
                          : AppColors.slate600,
                    );
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getDeptColor(String dept) {
    switch (dept) {
      case 'electrical':  return AppColors.warning;
      case 'mechanical':  return AppColors.info;
      case 'civil':       return const Color(0xFFA0785A);
      case 'architecture':return Colors.purple;
      case 'management':  return AppColors.cyan500;
      default:            return AppColors.cyan600;
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'active':    color = AppColors.success; label = 'Active'; break;
      case 'suspended': color = AppColors.warning; label = 'Suspended'; break;
      case 'resigned':  color = AppColors.error;   label = 'Resigned'; break;
      default:          color = AppColors.slate400; label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
