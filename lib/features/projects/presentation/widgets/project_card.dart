import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/project_model.dart';
import '../controllers/task_providers.dart';
import '../../../../core/theme/app_theme.dart';

class ProjectCard extends ConsumerWidget {
  final ProjectModel project;
  final VoidCallback onTap;

  const ProjectCard({super.key, required this.project, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(projectTasksProvider(project.id));
    final openCount = tasksAsync.maybeWhen(
      data: (tasks) => tasks.where((t) => t.status != 'completed').length,
      orElse: () => 0,
    );

    final typeColor = _typeColor(project.type);
    final statusColor = AppStatusColors.forProjectStatus(project.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.slate800,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.slate700),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top accent bar ──────────────────────────────────────────────
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [typeColor.withOpacity(0.8), typeColor.withOpacity(0.2)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header Row ────────────────────────────────────────────
                  Row(
                    children: [
                      // Type icon
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: typeColor.withOpacity(0.2)),
                        ),
                        child: Icon(_typeIcon(project.type), color: typeColor, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              style: const TextStyle(
                                color: AppColors.slate100,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              project.projectCode,
                              style: const TextStyle(color: AppColors.slate500, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      // Open tasks badge
                      if (openCount > 0) ...[
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.pending_actions_rounded,
                                  size: 10, color: AppColors.warning),
                              const SizedBox(width: 3),
                              Text(
                                '$openCount open',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Status chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          AppStatusColors.labelForProjectStatus(project.status),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Meta Row ──────────────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 13, color: AppColors.slate500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          project.clientName,
                          style: const TextStyle(fontSize: 11, color: AppColors.slate400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.location_on_outlined, size: 13, color: AppColors.slate500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          project.location,
                          style: const TextStyle(fontSize: 11, color: AppColors.slate400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Progress Bar ──────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Completion',
                        style: TextStyle(fontSize: 11, color: AppColors.slate500),
                      ),
                      Text(
                        '${project.completionPercentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: project.completionPercentage / 100,
                      backgroundColor: AppColors.slate700,
                      valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                      minHeight: 5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Disciplines + Date ────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: project.disciplines.take(3).map((d) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.slate700,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.slate600),
                              ),
                              child: Text(
                                d,
                                style: const TextStyle(fontSize: 10, color: AppColors.slate400),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 11, color: AppColors.slate500),
                          const SizedBox(width: 4),
                          Text(
                            '${project.endDate.day}/${project.endDate.month}/${project.endDate.year}',
                            style: const TextStyle(fontSize: 10, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'design':             return AppColors.cyan500;
      case 'executive_drawings': return AppColors.info;
      case 'supervision':        return AppColors.warning;
      default:                   return AppColors.cyan600;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'design':             return Icons.architecture_rounded;
      case 'executive_drawings': return Icons.draw_rounded;
      case 'supervision':        return Icons.engineering_rounded;
      default:                   return Icons.business_center_rounded;
    }
  }
}
