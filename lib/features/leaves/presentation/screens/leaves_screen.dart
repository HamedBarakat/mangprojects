import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/home/presentation/controllers/home_providers.dart';
import '../../data/models/leave_request_model.dart';
import '../../data/leave_repository.dart';
import '../controllers/leave_providers.dart';
import '../../../../core/theme/app_theme.dart';
import 'submit_leave_screen.dart';

class LeavesScreen extends ConsumerWidget {
  const LeavesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final canApprove = (user?.isAdmin ?? false) ||
        (user?.isManagement ?? false) ||
        (user?.isSeniorManagement ?? false) ||
        LeaveRepository.isApproverJobTitle(user?.jobTitle ?? '');

    if (canApprove) {
      return DefaultTabController(
        length: 2,
        child: _LeavesScaffold(canApprove: true),
      );
    }
    return _LeavesScaffold(canApprove: false);
  }
}

class _LeavesScaffold extends ConsumerWidget {
  final bool canApprove;
  const _LeavesScaffold({required this.canApprove});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Leaves'),
        bottom: canApprove
            ? PreferredSize(
                preferredSize: const Size.fromHeight(49),
                child: Column(children: [
                  Container(height: 1, color: cs.outlineVariant),
                  const TabBar(tabs: [
                    Tab(text: 'My Requests'),
                    Tab(text: 'Pending Approvals'),
                  ]),
                ]),
              )
            : PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: cs.outlineVariant),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubmitLeaveScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
      body: canApprove
          ? const TabBarView(
              children: [_MyLeavesTab(), _ApprovalsTab()])
          : const _MyLeavesTab(),
    );
  }
}

// ── My Leaves Tab ─────────────────────────────────────────────────────────────
class _MyLeavesTab extends ConsumerWidget {
  const _MyLeavesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leavesAsync = ref.watch(myLeavesProvider);
    final balanceAsync = ref.watch(leaveBalanceProvider);

    return leavesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (leaves) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          balanceAsync.when(
            data: (b) => _BalanceSummaryCard(balance: b),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          if (leaves.isEmpty)
            _EmptyState(
              icon: Icons.beach_access_rounded,
              message: 'No leave requests yet',
            )
          else
            ...leaves.map((l) => _LeaveCard(leave: l, showActions: false)),
        ],
      ),
    );
  }
}

// ── Approvals Tab ─────────────────────────────────────────────────────────────
class _ApprovalsTab extends ConsumerWidget {
  const _ApprovalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvalsAsync = ref.watch(pendingLeaveApprovalsProvider);

    return approvalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (leaves) {
        if (leaves.isEmpty) {
          return _EmptyState(
            icon: Icons.check_circle_outline_rounded,
            message: 'No pending approvals',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children:
              leaves.map((l) => _LeaveCard(leave: l, showActions: true)).toList(),
        );
      },
    );
  }
}

String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
}

String _fmtDateTime(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} · $h:$m';
}

// ── Leave Card ────────────────────────────────────────────────────────────────
class _LeaveCard extends ConsumerWidget {
  final LeaveRequestModel leave;
  final bool showActions;
  const _LeaveCard({required this.leave, required this.showActions});

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'approved_l1':
      case 'approved_l2':
        return Colors.blue;
      case 'approved_final':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(leave.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(_typeIcon(leave.type), size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leave.typeLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (showActions)
                        Text(
                          '${leave.employeeName}  ·  ${LeaveRepository.jobTitleLabel(leave.employeeJobTitle)}',
                          style: TextStyle(
                              color: cs.subtleText, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                _StatusBadge(
                    label: leave.statusLabel, color: statusColor),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),

          // ── Date + duration ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _Detail(
                    icon: Icons.calendar_today_outlined,
                    label: 'From',
                    value: _fmtDate(leave.startDate),
                  ),
                ),
                Expanded(
                  child: _Detail(
                    icon: Icons.event_outlined,
                    label: 'To',
                    value: leave.type == 'permission'
                        ? _fmtDate(leave.startDate)
                        : _fmtDate(leave.endDate),
                  ),
                ),
                Expanded(
                  child: _Detail(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: leave.durationLabel,
                  ),
                ),
              ],
            ),
          ),

          // ── Annual balance snapshot (approver view) ──────────────────────
          if (showActions && leave.type == 'annual_leave') ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 14, color: cs.subtleText),
                    const SizedBox(width: 6),
                    Text(
                      'Balance: ${leave.employeeBalanceRemaining} remaining of ${leave.employeeAnnualBalance} days  (${leave.employeeBalanceUsed} used)',
                      style: TextStyle(
                          fontSize: 11, color: cs.subtleText),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Reason ──────────────────────────────────────────────────────
          if (leave.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  leave.reason,
                  style: TextStyle(
                      fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ],

          // ── "Waiting for" line (my requests tab) ────────────────────────
          if (!showActions && leave.isActive) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.hourglass_top_rounded,
                      size: 14, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    'Waiting for: ${LeaveRepository.jobTitleLabel(leave.currentApproverJobTitle)}',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.warning),
                  ),
                ],
              ),
            ),
          ],

          // ── Approval history timeline ────────────────────────────────────
          if (leave.approvalChain.any((s) => s.action != 'pending')) ...[
            const SizedBox(height: 10),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              child: _ApprovalTimeline(chain: leave.approvalChain),
            ),
          ],

          const SizedBox(height: 12),

          // ── Actions (for approvers) ──────────────────────────────────────
          if (showActions && leave.isActive) ...[
            Divider(height: 1, color: cs.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: _ApprovalActions(leave: leave),
            ),
          ],

          // ── Cancel button for own pending requests ───────────────────────
          if (!showActions && leave.status == 'pending') ...[
            Divider(height: 1, color: cs.outlineVariant),
            TextButton.icon(
              onPressed: () => _confirmCancel(context, ref, leave.id),
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Cancel Request'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'annual_leave':
        return Icons.beach_access_rounded;
      case 'sick_leave':
        return Icons.local_hospital_outlined;
      case 'permission':
        return Icons.access_time_rounded;
      case 'emergency':
        return Icons.warning_amber_rounded;
      default:
        return Icons.event_note_outlined;
    }
  }

  Future<void> _confirmCancel(
      BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Leave Request'),
        content: const Text(
            'Are you sure you want to cancel this leave request?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(leaveRepositoryProvider).cancelLeave(id);
    }
  }
}

// ── Approval timeline ─────────────────────────────────────────────────────────
class _ApprovalTimeline extends StatelessWidget {
  final List<LeaveApprovalStep> chain;
  const _ApprovalTimeline({required this.chain});

  Color _stepColor(String action) {
    switch (action) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  IconData _stepIcon(String action) {
    switch (action) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Only show steps that have been acted on
    final actedSteps = chain.where((s) => s.action != 'pending').toList();
    if (actedSteps.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Approval History',
              style: TextStyle(
                  fontSize: 11,
                  color: cs.subtleText,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...actedSteps.map((step) {
            final color = _stepColor(step.action);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_stepIcon(step.action), size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                step.approverName.isNotEmpty
                                    ? step.approverName
                                    : LeaveRepository.jobTitleLabel(
                                        step.jobTitle),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (step.timestamp != null)
                              Text(
                                _fmtDateTime(step.timestamp!),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: cs.subtleText),
                              ),
                          ],
                        ),
                        Text(
                          step.action == 'approved' ? 'Approved' : 'Rejected',
                          style:
                              TextStyle(fontSize: 11, color: color),
                        ),
                        if (step.notes.isNotEmpty)
                          Text(
                            step.notes,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.subtleText,
                                fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Approval actions ──────────────────────────────────────────────────────────
class _ApprovalActions extends ConsumerWidget {
  final LeaveRequestModel leave;
  const _ApprovalActions({required this.leave});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _reject(context, ref, user),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _approve(context, ref, user),
            icon: const Icon(Icons.check, size: 16),
            label: Text(user.isAdmin ? 'Approve Final' : 'Approve'),
          ),
        ),
      ],
    );
  }

  Future<void> _approve(
      BuildContext context, WidgetRef ref, dynamic user) async {
    // Optional note dialog
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Leave Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Approve ${leave.typeLabel} for ${leave.employeeName}?'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    noteCtrl.dispose();
    if (confirmed != true) return;

    try {
      await ref.read(leaveRepositoryProvider).approveRequest(
            requestId: leave.id,
            officeId: leave.officeId,
            approverId: user.uid as String,
            approverName: user.name as String,
            approverJobTitle: user.jobTitle as String,
            isAdmin: user.isAdmin as bool,
            notes: noteCtrl.text.trim(),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leave approved')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _reject(
      BuildContext context, WidgetRef ref, dynamic user) async {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Leave Request'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Reject ${leave.typeLabel} for ${leave.employeeName}?'),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonCtrl,
                maxLines: 3,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Reason (required)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'A reason is required to reject'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (confirmed != true) return;

    try {
      await ref.read(leaveRepositoryProvider).rejectRequest(
            requestId: leave.id,
            officeId: leave.officeId,
            approverId: user.uid as String,
            approverName: user.name as String,
            approverJobTitle: user.jobTitle as String,
            reason: reason,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leave rejected')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Detail(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 10, color: cs.subtleText)),
        Text(value,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _BalanceSummaryCard extends StatelessWidget {
  final Map<String, int> balance;
  const _BalanceSummaryCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final remaining = balance['remaining'] ?? 21;
    final total = balance['total'] ?? 21;
    final used = balance['used'] ?? 0;
    final pct = total > 0 ? used / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Annual Leave Balance ${DateTime.now().year}',
              style: TextStyle(color: cs.subtleText, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$remaining days remaining',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: remaining > 5
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                    Text('out of $total days',
                        style:
                            TextStyle(color: cs.subtleText, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                '$used used',
                style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: cs.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                pct > 0.8 ? AppColors.error : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: cs.subtleText)),
          ],
        ),
      ),
    );
  }
}
