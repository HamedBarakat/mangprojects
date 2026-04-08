import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mang_projects/features/projects/presentation/screens/client_review_screen.dart';

import '../../../../features/home/presentation/controllers/home_providers.dart';
import 'client_project_detail_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// CLIENT PROJECTS PROVIDER
// ══════════════════════════════════════════════════════════════════════════════

final clientProjectsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, clientId) {
      return FirebaseFirestore.instance
          .collection('projects')
          .where('clientId', isEqualTo: clientId)
          .snapshots()
          .map(
            (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
          );
    });

// ── Provider: count of client_review tasks per project ───────────────────────
// Uses (clientId, projectId) tuple to satisfy Firestore rules for client role
final clientPendingReviewCountProvider =
    StreamProvider.family<int, (String, String)>((ref, args) {
  final (clientId, projectId) = args;
  return FirebaseFirestore.instance
      .collection('tasks')
      .where('clientId', isEqualTo: clientId)
      .where('projectId', isEqualTo: projectId)
      .where('status', isEqualTo: 'client_review')
      .snapshots()
      .map((snap) => snap.docs.length);
});

// ══════════════════════════════════════════════════════════════════════════════
// CLIENT SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class ClientScreen extends ConsumerWidget {
  const ClientScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider).value;
    if (user == null) return const Center(child: CircularProgressIndicator());

    final linkedClientId = user.linkedClientId;
    if (linkedClientId == null || linkedClientId.isEmpty) {
      return Scaffold(
        body: Center(child: Text('No client record linked to this account')),
      );
    }

    final projectsAsync = ref.watch(clientProjectsProvider(linkedClientId));

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Projects',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: cs.onSurface,
              ),
            ),
            Text(
              'Welcome, ${user.name}',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (projects) {
          if (projects.isEmpty) {
            return _EmptyState();
          }

          // Stats
          final active = projects.where((p) => p['status'] == 'active').length;
          final completed = projects
              .where((p) => p['status'] == 'completed')
              .length;

          return CustomScrollView(
            slivers: [
              // Summary banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _StatsBanner(
                    total: projects.length,
                    active: active,
                    completed: completed,
                  ),
                ),
              ),

              // Projects list
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _ProjectCard(
                      project: projects[i],
                      clientId: linkedClientId,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClientReviewScreen(
                            projectId: projects[i]['id'],
                            projectName: projects[i]['name'] ?? 'Project',
                          ),
                        ),
                      ),
                    ),
                    childCount: projects.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STATS BANNER
// ══════════════════════════════════════════════════════════════════════════════

class _StatsBanner extends StatelessWidget {
  final int total, active, completed;
  const _StatsBanner({
    required this.total,
    required this.active,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _StatItem(
            'Total',
            total.toString(),
            Icons.folder_outlined,
            Colors.white,
          ),
          _Divider(),
          _StatItem(
            'Active',
            active.toString(),
            Icons.play_circle_outline,
            Colors.greenAccent,
          ),
          _Divider(),
          _StatItem(
            'Done',
            completed.toString(),
            Icons.check_circle_outline,
            Colors.lightBlueAccent,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8)),
        ),
      ],
    ),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 50, color: Colors.white.withOpacity(0.3));
}

// ══════════════════════════════════════════════════════════════════════════════
// PROJECT CARD
// ══════════════════════════════════════════════════════════════════════════════

class _ProjectCard extends ConsumerWidget {
  final Map<String, dynamic> project;
  final String clientId;
  final VoidCallback onTap;
  const _ProjectCard({
    required this.project,
    required this.clientId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = project['id'] as String? ?? '';
    final pendingCount = ref
        .watch(clientPendingReviewCountProvider((clientId, projectId)))
        .value ?? 0;
    final hasPending = pendingCount > 0;
    final cs = Theme.of(context).colorScheme;
    final status = project['status'] as String? ?? 'active';
    final progress =
        (project['completionPercentage'] as num?)?.toDouble() ?? 0.0;
    final name = project['name'] as String? ?? '—';
    final code = project['projectCode'] as String? ?? '';
    final endDate = _fmtDate(project['endDate']);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _statusColor(status, cs).withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _statusColor(status, cs).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.business_center_outlined,
                      color: _statusColor(status, cs),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (code.isNotEmpty)
                          Text(
                            code,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withOpacity(0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _StatusBadge(status),
                  if (hasPending) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.pending_actions_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$pendingCount',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Progress
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withOpacity(0.55),
                    ),
                  ),
                  Text(
                    '${progress.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(status, cs),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 8,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(_statusColor(status, cs)),
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: cs.onSurface.withOpacity(0.45),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'End: $endDate',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withOpacity(0.55),
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClientProjectDetailScreen(
                              projectId: projectId,
                              projectName: name,
                              clientId: clientId,
                              initialTabIndex: 2,
                            ),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bar_chart_outlined, size: 14, color: cs.primary),
                              const SizedBox(width: 3),
                              Text(
                                'Report',
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
                      const SizedBox(width: 8),
                      Text(
                        'View Details →',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withOpacity(0.4),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (hasPending) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.rate_review_rounded, size: 16),
                        label: Text(
                          'Review Tasks ($pendingCount)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status, ColorScheme cs) {
    switch (status) {
      case 'active':
        return cs.primary;
      case 'completed':
        return Colors.blue;
      case 'on_hold':
        return Colors.orange;
      default:
        return cs.primary;
    }
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

// ══════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_outlined,
              size: 44,
              color: cs.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Projects Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your projects will appear here',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

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
