import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;

import '../../../../features/projects/data/models/task_model.dart'
    show TaskModel;
import '../../../reports/presentation/screens/report_export_stub.dart'
    if (dart.library.html) '../../../reports/presentation/screens/report_export_web.dart'
    if (dart.library.io) '../../../reports/presentation/screens/report_export_mobile.dart';

final _projectTasksProvider = StreamProvider.family<List<TaskModel>, String>(
  (ref, projectId) => FirebaseFirestore.instance
      .collection('tasks')
      .where('projectId', isEqualTo: projectId)
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => TaskModel.fromFirestore(d))
            .where(
              (t) => t.status == 'client_review' || t.status == 'completed',
            )
            .toList(),
      ),
);

final _projectDetailProvider =
    StreamProvider.family<Map<String, dynamic>?, String>(
      (ref, projectId) => FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .snapshots()
          .map((s) => s.exists ? {'id': s.id, ...s.data()!} : null),
    );

class ClientProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectId, projectName, clientId;
  const ClientProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.clientId,
  });

  @override
  ConsumerState<ClientProjectDetailScreen> createState() =>
      _ClientProjectDetailScreenState();
}

class _ClientProjectDetailScreenState
    extends ConsumerState<ClientProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final project = ref.watch(_projectDetailProvider(widget.projectId)).value;
    final progress =
        (project?['completionPercentage'] as num?)?.toDouble() ?? 0.0;
    final status = project?['status'] as String? ?? 'active';

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          widget.projectName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurface.withOpacity(0.45),
          indicatorColor: cs.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.task_outlined, size: 18), text: 'Tasks'),
            Tab(icon: Icon(Icons.comment_outlined, size: 18), text: 'My Notes'),
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'Report'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (project != null)
            _ProjectHeader(
              project: project,
              progress: progress,
              status: status,
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _TasksTab(
                  projectId: widget.projectId,
                  clientId: widget.clientId,
                ),
                _NotesTab(
                  projectId: widget.projectId,
                  clientId: widget.clientId,
                ),
                _ReportTab(
                  projectId: widget.projectId,
                  clientId: widget.clientId,
                  project: project,
                  projectName: widget.projectName,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  final Map<String, dynamic> project;
  final double progress;
  final String status;
  const _ProjectHeader({
    required this.project,
    required this.progress,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(status, cs);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Progress',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.55),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${progress.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status),
                  const SizedBox(height: 6),
                  if (project['endDate'] != null)
                    Text(
                      'End: ${_fmtDate(project['endDate'])}',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withOpacity(0.5),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 10,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s, ColorScheme cs) => switch (s) {
    'active' => cs.primary,
    'completed' => Colors.blue,
    'on_hold' => Colors.orange,
    _ => cs.primary,
  };
}

class _TasksTab extends ConsumerWidget {
  final String projectId, clientId;
  const _TasksTab({required this.projectId, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(_projectTasksProvider(projectId));
    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return _emptyState(context, Icons.task_alt_outlined, 'No tasks yet');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) =>
              _TaskCard(task: tasks[i], clientId: clientId),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final String clientId;
  const _TaskCard({required this.task, required this.clientId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final comments = task.clientComments.length;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _taskStatusColor(task.status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                _TaskStatusBadge(task.status),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 13,
                  color: cs.onSurface.withOpacity(0.4),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task.assignedEngineerNames.isEmpty
                        ? '—'
                        : task.assignedEngineerNames.join(', '),
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withOpacity(0.55),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 14),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: cs.onSurface.withOpacity(0.4),
                ),
                const SizedBox(width: 4),
                Text(
                  _fmtDateTime(task.endDate),
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withOpacity(0.55),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _showCommentSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          size: 13,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          comments > 0 ? '$comments' : 'Note',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (task.clientComments.isNotEmpty)
            _CommentsPreview(comments: task.clientComments, clientId: clientId),
        ],
      ),
    );
  }

  void _showCommentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddCommentSheet(
        taskId: task.id,
        taskTitle: task.title,
        clientId: clientId,
        existingComments: task.clientComments,
      ),
    );
  }
}

class _TaskStatusBadge extends StatelessWidget {
  final String status;
  const _TaskStatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'not_started' => ('Not Started', Colors.grey),
      'in_progress' => ('In Progress', Colors.orange),
      'team_leader_review' => ('Team Leader Review', Colors.indigo),
      'qc_review' => ('QC Review', Colors.deepPurple),
      'client_review' => ('Client Review', Colors.teal),
      'completed' => ('Completed', Colors.green),
      _ => (status, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CommentsPreview extends StatelessWidget {
  final List<Map<String, dynamic>> comments;
  final String clientId;
  const _CommentsPreview({required this.comments, required this.clientId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final last = comments.last;
    final isResolved = last['isResolved'] == true;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isResolved
            ? Colors.green.withOpacity(0.08)
            : cs.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isResolved
              ? Colors.green.withOpacity(0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isResolved
                ? Icons.check_circle_outline
                : Icons.format_quote_rounded,
            size: 16,
            color: isResolved ? Colors.green : cs.primary.withOpacity(0.6),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              last['text'] as String? ?? '',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withOpacity(0.7),
                decoration: isResolved ? TextDecoration.lineThrough : null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (comments.length > 1)
            Text(
              '+${comments.length - 1}',
              style: TextStyle(
                fontSize: 11,
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _AddCommentSheet extends StatefulWidget {
  final String taskId, taskTitle, clientId;
  final List<Map<String, dynamic>> existingComments;
  const _AddCommentSheet({
    required this.taskId,
    required this.taskTitle,
    required this.clientId,
    required this.existingComments,
  });

  @override
  State<_AddCommentSheet> createState() => _AddCommentSheetState();
}

class _AddCommentSheetState extends State<_AddCommentSheet> {
  final _ctrl = TextEditingController();
  bool _saving = false, _resolving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final newComment = {
        'clientId': widget.clientId,
        'text': text,
        'createdAt': Timestamp.now(),
        'isRead': false,
        'isResolved': false,
      };
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .update({
            'clientComments': [...widget.existingComments, newComment],
          });
      if (mounted) {
        _ctrl.clear();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note added ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleResolved(int index) async {
    setState(() => _resolving = true);
    try {
      final updated = widget.existingComments
          .map((c) => Map<String, dynamic>.from(c))
          .toList();
      final current = updated[index]['isResolved'] == true;
      updated[index]['isResolved'] = !current;
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .update({'clientComments': updated});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!current ? 'Marked as resolved ✓' : 'Reopened'),
            backgroundColor: !current ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Task: ${widget.taskTitle}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.existingComments.isNotEmpty) ...[
                  Text(
                    'Previous Notes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: widget.existingComments.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final c = widget.existingComments[i];
                        final isResolved = c['isResolved'] == true;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: _resolving
                                    ? null
                                    : () => _toggleResolved(i),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isResolved
                                        ? Colors.green.withOpacity(0.15)
                                        : cs.surfaceContainerHighest,
                                    border: Border.all(
                                      color: isResolved
                                          ? Colors.green
                                          : cs.outlineVariant,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isResolved
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.green,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c['text'] as String? ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isResolved
                                            ? cs.onSurface.withOpacity(0.4)
                                            : cs.onSurface,
                                        decoration: isResolved
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          _fmtDate(c['createdAt']),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: cs.onSurface.withOpacity(
                                              0.4,
                                            ),
                                          ),
                                        ),
                                        if (isResolved) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Text(
                                              'Resolved',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.green,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _ctrl,
                  maxLines: 3,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Write your note or feedback here...',
                    hintStyle: TextStyle(
                      color: cs.onSurface.withOpacity(0.35),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_saving ? 'Saving...' : 'Send Note'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _saving ? null : _submit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesTab extends ConsumerWidget {
  final String projectId, clientId;
  const _NotesTab({required this.projectId, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tasksAsync = ref.watch(_projectTasksProvider(projectId));
    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (tasks) {
        final tasksWithNotes = tasks
            .where((t) => t.clientComments.isNotEmpty)
            .toList();
        if (tasksWithNotes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.comment_outlined,
                  size: 48,
                  color: cs.onSurface.withOpacity(0.25),
                ),
                const SizedBox(height: 12),
                Text(
                  'No notes yet',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.4)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Go to Tasks tab to add notes',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          );
        }
        final allComments = tasksWithNotes
            .expand((t) => t.clientComments)
            .toList();
        final resolvedCount = allComments
            .where((c) => c['isResolved'] == true)
            .length;
        final openCount = allComments.length - resolvedCount;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _NoteStatChip(
                  label: 'Open',
                  count: openCount,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                _NoteStatChip(
                  label: 'Resolved',
                  count: resolvedCount,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...tasksWithNotes.map(
              (task) => _NoteGroup(
                taskTitle: task.title,
                taskId: task.id,
                comments: task.clientComments,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NoteStatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _NoteStatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteGroup extends StatelessWidget {
  final String taskTitle, taskId;
  final List<Map<String, dynamic>> comments;
  const _NoteGroup({
    required this.taskTitle,
    required this.taskId,
    required this.comments,
  });

  Future<void> _toggleResolved(int index) async {
    final updated = comments.map((c) => Map<String, dynamic>.from(c)).toList();
    updated[index]['isResolved'] = !(updated[index]['isResolved'] == true);
    await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({
      'clientComments': updated,
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolvedCount = comments.where((c) => c['isResolved'] == true).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.task_alt_outlined, size: 14, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    taskTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
                if (resolvedCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$resolvedCount resolved',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  '${comments.length} note${comments.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.primary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          ...comments.asMap().entries.map((entry) {
            final i = entry.key;
            final c = entry.value;
            final isResolved = c['isResolved'] == true;
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _toggleResolved(i),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isResolved
                            ? Colors.green.withOpacity(0.15)
                            : cs.surfaceContainerHighest,
                        border: Border.all(
                          color: isResolved ? Colors.green : cs.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                      child: isResolved
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.green,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isResolved
                                ? Colors.green.withOpacity(0.06)
                                : cs.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isResolved
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            c['text'] as String? ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: isResolved
                                  ? cs.onSurface.withOpacity(0.45)
                                  : cs.onSurface,
                              decoration: isResolved
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _fmtDate(c['createdAt']),
                              style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurface.withOpacity(0.4),
                              ),
                            ),
                            if (isResolved) ...[
                              const SizedBox(width: 6),
                              const Text(
                                '✓ Resolved',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ReportTab extends StatefulWidget {
  final String projectId, clientId, projectName;
  final Map<String, dynamic>? project;
  const _ReportTab({
    required this.projectId,
    required this.clientId,
    required this.project,
    required this.projectName,
  });

  @override
  State<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<_ReportTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _exporting = false;

  Future<void> _exportPdf(List<TaskModel> tasks) async {
    setState(() => _exporting = true);
    try {
      final progress =
          (widget.project?['completionPercentage'] as num?)?.toDouble() ?? 0.0;
      final status = widget.project?['status'] as String? ?? '—';
      final endDate = _fmtDate(widget.project?['endDate']);
      final allComments = tasks.expand((t) => t.clientComments).toList();
      final totalNotes = allComments.length;
      final resolvedNotes = allComments
          .where((c) => c['isResolved'] == true)
          .length;
      final openNotes = totalNotes - resolvedNotes;
      final total = tasks.length;
      final completed = tasks.where((t) => t.status == 'completed').length;
      final inProg = tasks.where((t) => t.status == 'in_progress').length;
      final teamLeadReview = tasks
          .where((t) => t.status == 'team_leader_review')
          .length;
      final qcReview = tasks.where((t) => t.status == 'qc_review').length;
      final clientReview = tasks
          .where((t) => t.status == 'client_review')
          .length;
      final notStart = tasks.where((t) => t.status == 'not_started').length;

      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final cairoFont = pw.Font.ttf(fontData);
      final baseStyle = pw.TextStyle(font: cairoFont, fontSize: 10);
      final titleStyle = pw.TextStyle(
        font: cairoFont,
        fontSize: 18,
        fontWeight: pw.FontWeight.bold,
        color: const PdfColor.fromInt(0xFF2E7D32),
      );
      final sectionStyle = pw.TextStyle(
        font: cairoFont,
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
      );
      final headerCellStyle = pw.TextStyle(
        font: cairoFont,
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        color: PdfColors.white,
      );
      final cellStyle = pw.TextStyle(font: cairoFont, fontSize: 8);

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          textDirection: pw.TextDirection.rtl,
          build: (ctx) => [
            pw.Text(
              widget.projectName,
              style: titleStyle,
              textDirection: pw.TextDirection.rtl,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Client Project Report  •  Generated: ${_fmtNow()}',
              style: pw.TextStyle(
                font: cairoFont,
                fontSize: 9,
                color: PdfColors.grey600,
              ),
            ),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F8E9),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Status: ${_statusLabel(status)}', style: baseStyle),
                  pw.Text('End Date: $endDate', style: baseStyle),
                  pw.Text(
                    'Progress: ${progress.toStringAsFixed(0)}%',
                    style: pw.TextStyle(
                      font: cairoFont,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Tasks Breakdown', style: sectionStyle),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Category', 'Count', '%'],
              data: [
                [
                  'Completed',
                  '$completed',
                  total > 0
                      ? '${(completed / total * 100).toStringAsFixed(0)}%'
                      : '0%',
                ],
                [
                  'In Progress',
                  '$inProg',
                  total > 0
                      ? '${(inProg / total * 100).toStringAsFixed(0)}%'
                      : '0%',
                ],
                [
                  'Team Leader Review',
                  '$teamLeadReview',
                  total > 0
                      ? '${(teamLeadReview / total * 100).toStringAsFixed(0)}%'
                      : '0%',
                ],
                [
                  'QC Review',
                  '$qcReview',
                  total > 0
                      ? '${(qcReview / total * 100).toStringAsFixed(0)}%'
                      : '0%',
                ],
                [
                  'Client Review',
                  '$clientReview',
                  total > 0
                      ? '${(clientReview / total * 100).toStringAsFixed(0)}%'
                      : '0%',
                ],
                [
                  'Not Started',
                  '$notStart',
                  total > 0
                      ? '${(notStart / total * 100).toStringAsFixed(0)}%'
                      : '0%',
                ],
                ['Total', '$total', '100%'],
              ],
              headerStyle: headerCellStyle,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF2E7D32),
              ),
              cellStyle: pw.TextStyle(font: cairoFont, fontSize: 9),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F8E9),
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
              },
            ),
            pw.SizedBox(height: 16),
            pw.Text('My Notes Status', style: sectionStyle),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Category', 'Count'],
              data: [
                ['Total Notes', '$totalNotes'],
                ['Resolved', '$resolvedNotes'],
                ['Open', '$openNotes'],
              ],
              headerStyle: headerCellStyle,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF2E7D32),
              ),
              cellStyle: pw.TextStyle(font: cairoFont, fontSize: 9),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F8E9),
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
            pw.SizedBox(height: 16),
            pw.Text('All Tasks', style: sectionStyle),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: [
                'Task',
                'Assigned To',
                'Status',
                'End Date',
                'Notes',
                'Resolved',
              ],
              data: tasks.map((t) {
                final tNotes = t.clientComments.length;
                final tResolved = t.clientComments
                    .where((c) => c['isResolved'] == true)
                    .length;
                return [
                  t.title,
                  t.assignedEngineerNames.isEmpty
                      ? '—'
                      : t.assignedEngineerNames.join(', '),
                  _taskStatusLabel(t.status),
                  _fmtDateTime(t.endDate),
                  '$tNotes',
                  '$tResolved',
                ];
              }).toList(),
              headerStyle: headerCellStyle,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF2E7D32),
              ),
              cellStyle: cellStyle,
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F8E9),
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: '${widget.projectName.replaceAll(' ', '_')}_report.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportExcel(List<TaskModel> tasks) async {
    setState(() => _exporting = true);
    try {
      final progress =
          (widget.project?['completionPercentage'] as num?)?.toDouble() ?? 0.0;
      final allComments = tasks.expand((t) => t.clientComments).toList();
      final resolvedNotes = allComments
          .where((c) => c['isResolved'] == true)
          .length;
      final openNotes = allComments.length - resolvedNotes;

      final excel = Excel.createExcel();

      excel.rename('Sheet1', 'Summary');
      final summary = excel['Summary'];
      _excelHeader(summary, ['Metric', 'Value']);
      final summaryData = [
        ['Project', widget.projectName],
        ['Status', _statusLabel(widget.project?['status'])],
        ['Progress', '${progress.toStringAsFixed(0)}%'],
        ['End Date', _fmtDate(widget.project?['endDate'])],
        ['Total Tasks', '${tasks.length}'],
        ['Completed', '${tasks.where((t) => t.status == 'completed').length}'],
        [
          'In Progress',
          '${tasks.where((t) => t.status == 'in_progress').length}',
        ],
        [
          'Team Leader Review',
          '${tasks.where((t) => t.status == 'team_leader_review').length}',
        ],
        ['QC Review', '${tasks.where((t) => t.status == 'qc_review').length}'],
        [
          'Client Review',
          '${tasks.where((t) => t.status == 'client_review').length}',
        ],
        [
          'Not Started',
          '${tasks.where((t) => t.status == 'not_started').length}',
        ],
        ['Total Notes', '${allComments.length}'],
        ['Resolved Notes', '$resolvedNotes'],
        ['Open Notes', '$openNotes'],
      ];
      for (var i = 0; i < summaryData.length; i++) {
        _excelRow(
          summary,
          summaryData[i].map((v) => TextCellValue(v)).toList(),
          i + 1,
        );
      }
      summary.setColumnWidth(0, 22);
      summary.setColumnWidth(1, 28);

      excel['Tasks'];
      final tasksSheet = excel['Tasks'];
      _excelHeader(tasksSheet, [
        'Task',
        'Assigned To',
        'Status',
        'End Date',
        'Total Notes',
        'Resolved Notes',
      ]);
      for (var i = 0; i < tasks.length; i++) {
        final t = tasks[i];
        final tNotes = t.clientComments.length;
        final tResolved = t.clientComments
            .where((c) => c['isResolved'] == true)
            .length;
        _excelRow(tasksSheet, [
          TextCellValue(t.title),
          TextCellValue(
            t.assignedEngineerNames.isEmpty
                ? '—'
                : t.assignedEngineerNames.join(', '),
          ),
          TextCellValue(_taskStatusLabel(t.status)),
          TextCellValue(_fmtDateTime(t.endDate)),
          IntCellValue(tNotes),
          IntCellValue(tResolved),
        ], i + 1);
      }
      tasksSheet.setColumnWidth(0, 30);
      tasksSheet.setColumnWidth(1, 22);
      tasksSheet.setColumnWidth(2, 20);
      tasksSheet.setColumnWidth(3, 14);
      tasksSheet.setColumnWidth(4, 14);
      tasksSheet.setColumnWidth(5, 16);

      excel['Notes'];
      final notesSheet = excel['Notes'];
      _excelHeader(notesSheet, ['Task', 'Note Text', 'Date', 'Status']);
      var noteRow = 1;
      for (final t in tasks) {
        for (final c in t.clientComments) {
          final isResolved = c['isResolved'] == true;
          _excelRow(notesSheet, [
            TextCellValue(t.title),
            TextCellValue(c['text'] as String? ?? ''),
            TextCellValue(_fmtDate(c['createdAt'])),
            TextCellValue(isResolved ? 'Resolved' : 'Open'),
          ], noteRow);
          noteRow++;
        }
      }
      notesSheet.setColumnWidth(0, 28);
      notesSheet.setColumnWidth(1, 40);
      notesSheet.setColumnWidth(2, 14);
      notesSheet.setColumnWidth(3, 12);

      final bytes = excel.encode();
      if (bytes == null) return;
      await downloadExcel(
        Uint8List.fromList(bytes),
        '${widget.projectName.replaceAll(' ', '_')}_report.xlsx',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer(
      builder: (context, ref, _) {
        final cs = Theme.of(context).colorScheme;
        final tasksAsync = ref.watch(_projectTasksProvider(widget.projectId));
        return tasksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (tasks) {
            final total = tasks.length;
            final completed = tasks
                .where((t) => t.status == 'completed')
                .length;
            final inProg = tasks.where((t) => t.status == 'in_progress').length;
            final teamLeadReview = tasks
                .where((t) => t.status == 'team_leader_review')
                .length;
            final qcReview = tasks.where((t) => t.status == 'qc_review').length;
            final clientReview = tasks
                .where((t) => t.status == 'client_review')
                .length;
            final notStart = tasks
                .where((t) => t.status == 'not_started')
                .length;
            final allComments = tasks.expand((t) => t.clientComments).toList();
            final totalNotes = allComments.length;
            final resolvedNotes = allComments
                .where((c) => c['isResolved'] == true)
                .length;
            final openNotes = totalNotes - resolvedNotes;
            final progress =
                (widget.project?['completionPercentage'] as num?)?.toDouble() ??
                0.0;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: _exporting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.red,
                                ),
                              )
                            : const Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 16,
                                color: Colors.red,
                              ),
                        label: const Text(
                          'Export PDF',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _exporting ? null : () => _exportPdf(tasks),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: _exporting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.green,
                                ),
                              )
                            : const Icon(
                                Icons.table_chart_outlined,
                                size: 16,
                                color: Colors.green,
                              ),
                        label: const Text(
                          'Export Excel',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.green),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _exporting
                            ? null
                            : () => _exportExcel(tasks),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ReportSection(
                  title: 'Project Progress',
                  icon: Icons.show_chart_rounded,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${progress.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: cs.primary,
                                  ),
                                ),
                                Text(
                                  'Overall Completion',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _CircularProgress(
                            value: progress / 100,
                            color: cs.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          minHeight: 8,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(cs.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _ReportSection(
                  title: 'Tasks Breakdown',
                  icon: Icons.task_alt_outlined,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Total',
                              value: '$total',
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatCard(
                              label: 'Done',
                              value: '$completed',
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'In Progress',
                              value: '$inProg',
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatCard(
                              label: 'TL Review',
                              value: '$teamLeadReview',
                              color: Colors.indigo,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatCard(
                              label: 'QC Review',
                              value: '$qcReview',
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Client Review',
                              value: '$clientReview',
                              color: Colors.teal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatCard(
                              label: 'Not Started',
                              value: '$notStart',
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                      if (total > 0) ...[
                        const SizedBox(height: 14),
                        _StatusBar(
                          segments: [
                            if (completed > 0)
                              _Segment('Done', completed / total, Colors.green),
                            if (inProg > 0)
                              _Segment(
                                'In Progress',
                                inProg / total,
                                Colors.orange,
                              ),
                            if (teamLeadReview > 0)
                              _Segment(
                                'TL Review',
                                teamLeadReview / total,
                                Colors.indigo,
                              ),
                            if (qcReview > 0)
                              _Segment(
                                'QC Review',
                                qcReview / total,
                                Colors.deepPurple,
                              ),
                            if (clientReview > 0)
                              _Segment(
                                'Client Review',
                                clientReview / total,
                                Colors.teal,
                              ),
                            if (notStart > 0)
                              _Segment(
                                'Not Started',
                                notStart / total,
                                Colors.grey.shade400,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _ReportSection(
                  title: 'My Notes Status',
                  icon: Icons.comment_outlined,
                  child: totalNotes == 0
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No notes added yet.',
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.4),
                              fontSize: 13,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    label: 'Total',
                                    value: '$totalNotes',
                                    color: cs.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatCard(
                                    label: 'Open',
                                    value: '$openNotes',
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatCard(
                                    label: 'Resolved',
                                    value: '$resolvedNotes',
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            if (totalNotes > 0) ...[
                              const SizedBox(height: 14),
                              _StatusBar(
                                segments: [
                                  if (resolvedNotes > 0)
                                    _Segment(
                                      'Resolved',
                                      resolvedNotes / totalNotes,
                                      Colors.green,
                                    ),
                                  if (openNotes > 0)
                                    _Segment(
                                      'Open',
                                      openNotes / totalNotes,
                                      Colors.orange,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                if (tasks.isNotEmpty)
                  _ReportSection(
                    title: 'All Tasks',
                    icon: Icons.list_alt_rounded,
                    child: Column(
                      children: tasks.map((t) {
                        final tNotes = t.clientComments.length;
                        final tResolved = t.clientComments
                            .where((c) => c['isResolved'] == true)
                            .length;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _taskStatusColor(t.status),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  t.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (tNotes > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tResolved == tNotes
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    tResolved == tNotes
                                        ? '$tNotes ✓'
                                        : '$tResolved/$tNotes',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: tResolved == tNotes
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              _TaskStatusBadge(t.status),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _ReportSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.75)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Segment {
  final String label;
  final double fraction;
  final Color color;
  const _Segment(this.label, this.fraction, this.color);
}

class _StatusBar extends StatelessWidget {
  final List<_Segment> segments;
  const _StatusBar({required this.segments});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 12,
            child: Row(
              children: segments
                  .map(
                    (s) => Expanded(
                      flex: ((s.fraction * 100).round()).clamp(1, 100),
                      child: Container(color: s.color),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: segments
              .map(
                (s) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: s.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${s.label} ${(s.fraction * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _CircularProgress extends StatelessWidget {
  final double value;
  final Color color;
  const _CircularProgress({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 6,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Text(
            '${(value * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      'active' => ('Active', Colors.green),
      'completed' => ('Done', Colors.blue),
      'on_hold' => ('On Hold', Colors.orange),
      _ => ('—', cs.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Widget _emptyState(BuildContext context, IconData icon, String label) {
  final cs = Theme.of(context).colorScheme;
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: cs.onSurface.withOpacity(0.25)),
        const SizedBox(height: 12),
        Text(label, style: TextStyle(color: cs.onSurface.withOpacity(0.4))),
      ],
    ),
  );
}

Color _taskStatusColor(String s) => switch (s) {
  'not_started' => Colors.grey,
  'in_progress' => Colors.orange,
  'team_leader_review' => Colors.indigo,
  'qc_review' => Colors.deepPurple,
  'client_review' => Colors.teal,
  'completed' => Colors.green,
  _ => Colors.grey,
};

String _statusLabel(dynamic s) =>
    const {'active': 'Active', 'completed': 'Completed', 'on_hold': 'On Hold'}[s
        as String?] ??
    (s?.toString() ?? '—');

String _taskStatusLabel(String? s) =>
    const {
      'not_started': 'Not Started',
      'in_progress': 'In Progress',
      'team_leader_review': 'Team Leader Review',
      'qc_review': 'QC Review',
      'client_review': 'Client Review',
      'completed': 'Completed',
    }[s] ??
    (s ?? '—');

String _fmtDate(dynamic v) {
  if (v == null) return '—';
  try {
    if (v is Timestamp) {
      final d = v.toDate();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    if (v is String && v.isNotEmpty) return v;
  } catch (_) {}
  return '—';
}

String _fmtDateTime(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _fmtNow() {
  final d = DateTime.now();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

void _excelHeader(Sheet sheet, List<String> headers) {
  sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
  for (var i = 0; i < headers.length; i++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        .cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#2E7D32'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      fontSize: 11,
    );
  }
}

void _excelRow(Sheet sheet, List<CellValue> values, int rowIndex) {
  sheet.appendRow(values);
  final isEven = rowIndex % 2 == 0;
  for (var i = 0; i < values.length; i++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex))
        .cellStyle = CellStyle(
      backgroundColorHex: isEven
          ? ExcelColor.fromHexString('#FFFFFF')
          : ExcelColor.fromHexString('#F1F8E9'),
      fontSize: 10,
      verticalAlign: VerticalAlign.Center,
    );
  }
}
