import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/project_model.dart';
import '../controllers/task_providers.dart';

class ProjectCard extends ConsumerWidget {
  final ProjectModel project;
  final VoidCallback onTap;

  const ProjectCard({super.key, required this.project, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    final tasksAsync = ref.watch(projectTasksProvider(project.id));
    final openCount = tasksAsync.maybeWhen(
      data: (tasks) => tasks.where((t) => t.status != 'completed').length,
      orElse: () => 0,
    );

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _typeColor(project.type, cs).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_typeIcon(project.type),
                        color: _typeColor(project.type, cs), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(project.projectCode,
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.5),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  if (openCount > 0) ...[
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pending_actions_rounded,
                              size: 12, color: Colors.orange.shade700),
                          const SizedBox(width: 3),
                          Text('$openCount open',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade700)),
                        ],
                      ),
                    ),
                  ],
                  _StatusChip(status: project.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded,
                      size: 14,
                      color: cs.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(project.clientName,
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(width: 12),
                  Icon(Icons.location_on_outlined,
                      size: 14,
                      color: cs.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(project.location,
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.6)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Completion',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6))),
                  Text(
                      '${project.completionPercentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _typeColor(project.type, cs))),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: project.completionPercentage / 100,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      _typeColor(project.type, cs)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: project.disciplines.take(3).map((d) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(d,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: cs.onSurface.withValues(alpha: 0.7))),
                        );
                      }).toList(),
                    ),
                  ),
                  Text(
                      '${project.endDate.day}/${project.endDate.month}/${project.endDate.year}',
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(String type, ColorScheme cs) {
    switch (type) {
      case 'design': return cs.primary;
      case 'executive_drawings': return Colors.blue.shade700;
      case 'supervision': return Colors.orange.shade700;
      default: return cs.primary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'design': return Icons.architecture_rounded;
      case 'executive_drawings': return Icons.draw_rounded;
      case 'supervision': return Icons.engineering_rounded;
      default: return Icons.business_center_rounded;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color; String label;
    switch (status) {
      case 'active': color = Colors.green; label = 'Active'; break;
      case 'completed': color = Colors.blue; label = 'Completed'; break;
      case 'suspended': color = Colors.orange; label = 'Suspended'; break;
      case 'cancelled': color = Colors.red; label = 'Cancelled'; break;
      default: color = Colors.grey; label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
