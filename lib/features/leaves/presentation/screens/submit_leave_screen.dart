import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/home/presentation/controllers/home_providers.dart';
import '../controllers/leave_providers.dart';
import '../../data/leave_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/office/data/models/hr_policy_model.dart';
import '../../../../features/office/presentation/controllers/hr_policy_providers.dart';

class SubmitLeaveScreen extends ConsumerStatefulWidget {
  const SubmitLeaveScreen({super.key});

  @override
  ConsumerState<SubmitLeaveScreen> createState() => _SubmitLeaveScreenState();
}

class _SubmitLeaveScreenState extends ConsumerState<SubmitLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();

  String _type = 'annual_leave';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  double _durationHours = 2;
  bool _loading = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  // يحسب أيام العمل بناءً على جدول الموظف المخصص أو سياسة المكتب
  double _computedDays(List<String> workDays) {
    if (_type == 'permission') return 0;
    // تحويل أسماء الأيام إلى أرقام weekday الخاصة بـ DateTime
    const dayToWeekday = {
      'sun': DateTime.sunday,
      'mon': DateTime.monday,
      'tue': DateTime.tuesday,
      'wed': DateTime.wednesday,
      'thu': DateTime.thursday,
      'fri': DateTime.friday,
      'sat': DateTime.saturday,
    };
    final workWeekdays = workDays
        .map((d) => dayToWeekday[d])
        .whereType<int>()
        .toSet();
    int days = 0;
    for (var d = _startDate;
        !d.isAfter(_endDate);
        d = d.add(const Duration(days: 1))) {
      if (workWeekdays.contains(d.weekday)) days++;
    }
    return days.toDouble();
  }

  /// يرجع الجدول الفعلي للموظف (مخصص أو جدول المكتب)
  List<String> _effectiveWorkDays(List<String> policyWorkDays) {
    final user = ref.read(currentUserProvider).value;
    if (user != null && user.hasCustomSchedule && user.customWorkDays.isNotEmpty) {
      return user.customWorkDays;
    }
    return policyWorkDays;
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final first = isStart ? DateTime.now() : _startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    // احسب أيام العمل باستخدام الجدول الفعلي
    final policy = ref.read(hrPolicyProvider).value ?? HRPolicyModel.defaults();
    final workDays = _effectiveWorkDays(policy.workDays);
    final computedDays = _computedDays(workDays);

    if (computedDays == 0 && _type != 'permission') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected dates include no working days')));
      return;
    }

    setState(() => _loading = true);
    try {
      final balance = await ref
          .read(leaveRepositoryProvider)
          .getLeaveBalance(user.uid, DateTime.now().year);

      await ref.read(leaveRepositoryProvider).submitLeaveRequest(
            officeId: user.officeId,
            employeeId: user.uid,
            employeeName: user.name,
            employeeJobTitle: user.jobTitle,
            type: _type,
            startDate: _startDate,
            endDate: _type == 'permission' ? _startDate : _endDate,
            durationDays: computedDays,
            durationHours: _type == 'permission' ? _durationHours : 0,
            reason: _reasonCtrl.text.trim(),
            annualBalance: balance['total']!,
            balanceUsed: balance['used']!,
            balanceRemaining: balance['remaining']!,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request submitted')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final balanceAsync = ref.watch(leaveBalanceProvider);
    final user = ref.watch(currentUserProvider).value;
    final chainTitles =
        LeaveRepository.approvalChainFor(user?.jobTitle ?? '');
    // جدول العمل: مخصص للموظف أو من سياسة المكتب
    final policy = ref.watch(hrPolicyProvider).value ?? HRPolicyModel.defaults();
    final effectiveWorkDays = _effectiveWorkDays(policy.workDays);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Leave Request'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: cs.outlineVariant),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Balance card ──────────────────────────────────────────────
            balanceAsync.when(
              data: (b) => _BalanceCard(balance: b),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // ── Leave type ────────────────────────────────────────────────
            Text('Leave Type',
                style: TextStyle(color: cs.subtleText, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _TypeChip(
                    label: 'Annual Leave',
                    value: 'annual_leave',
                    selected: _type,
                    onTap: (v) => setState(() => _type = v)),
                _TypeChip(
                    label: 'Sick Leave',
                    value: 'sick_leave',
                    selected: _type,
                    onTap: (v) => setState(() => _type = v)),
                _TypeChip(
                    label: 'Permission',
                    value: 'permission',
                    selected: _type,
                    onTap: (v) => setState(() => _type = v)),
                _TypeChip(
                    label: 'Emergency',
                    value: 'emergency',
                    selected: _type,
                    onTap: (v) => setState(() => _type = v)),
              ],
            ),
            const SizedBox(height: 16),

            // ── Dates ─────────────────────────────────────────────────────
            if (_type == 'permission') ...[
              _DateField(
                  label: 'Date',
                  date: _startDate,
                  onTap: () => _pickDate(true)),
              const SizedBox(height: 12),
              _HoursField(
                  hours: _durationHours,
                  onChanged: (v) => setState(() => _durationHours = v)),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                        label: 'From',
                        date: _startDate,
                        onTap: () => _pickDate(true)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                        label: 'To',
                        date: _endDate,
                        onTap: () => _pickDate(false)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Working days: ${_computedDays(effectiveWorkDays).toInt()}',
                  style: TextStyle(
                      color: cs.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // ── Reason ────────────────────────────────────────────────────
            TextFormField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please provide a reason' : null,
            ),
            const SizedBox(height: 16),

            // ── Approval chain preview ────────────────────────────────────
            if (chainTitles.isNotEmpty) _ApprovalChainPreview(chain: chainTitles),
            const SizedBox(height: 24),

            // ── Submit ────────────────────────────────────────────────────
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Approval chain preview ────────────────────────────────────────────────────
class _ApprovalChainPreview extends StatelessWidget {
  final List<String> chain;
  const _ApprovalChainPreview({required this.chain});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_outlined, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'Approval Chain',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...chain.asMap().entries.map((entry) {
            final idx = entry.key;
            final title = entry.value;
            final isLast = idx == chain.length - 1;
            return _ChainStep(
              stepNumber: idx + 1,
              label: LeaveRepository.jobTitleLabel(title),
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }
}

class _ChainStep extends StatelessWidget {
  final int stepNumber;
  final String label;
  final bool isLast;
  const _ChainStep(
      {required this.stepNumber,
      required this.label,
      required this.isLast});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: cs.primary, width: 1.5),
              ),
              child: Center(
                child: Text(
                  '$stepNumber',
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.primary,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (!isLast)
              Container(
                  width: 1.5, height: 20, color: cs.outlineVariant),
          ],
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final Map<String, int> balance;
  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final remaining = balance['remaining'] ?? 0;
    final total = balance['total'] ?? 21;
    final used = balance['used'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _BalanceStat(
                label: 'Total', value: '$total days', color: cs.primary),
          ),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(
            child: _BalanceStat(
                label: 'Used', value: '$used days', color: AppColors.warning),
          ),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(
            child: _BalanceStat(
              label: 'Remaining',
              value: '$remaining days',
              color: remaining > 5 ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _BalanceStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: cs.subtleText, fontSize: 11)),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label, value, selected;
  final void Function(String) onTap;
  const _TypeChip(
      {required this.label,
      required this.value,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = value == selected;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(value),
      selectedColor: cs.primary,
      labelStyle: TextStyle(
        color: isSelected ? cs.onPrimary : cs.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
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

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateField(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16, color: cs.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        TextStyle(fontSize: 11, color: cs.subtleText)),
                Text(
                  _fmtDate(date),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HoursField extends StatelessWidget {
  final double hours;
  final void Function(double) onChanged;
  const _HoursField(
      {required this.hours, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Duration',
            style: TextStyle(color: cs.subtleText, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [1.0, 2.0, 3.0, 4.0].map((h) {
            final selected = hours == h;
            return ChoiceChip(
              label: Text('${h.toInt()}h'),
              selected: selected,
              onSelected: (_) => onChanged(h),
              selectedColor: cs.primary,
              labelStyle: TextStyle(
                color: selected ? cs.onPrimary : cs.onSurface,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
