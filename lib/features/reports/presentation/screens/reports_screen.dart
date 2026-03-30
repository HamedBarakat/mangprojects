import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;

import 'report_export_stub.dart'
    if (dart.library.html) 'report_export_web.dart'
    if (dart.library.io) 'report_export_mobile.dart';

import '../../../../features/home/presentation/controllers/home_providers.dart';
import '../../../../features/home/data/models/user_model.dart';
import '../../../../core/theme/app_theme.dart';

// ── Date formatting helpers (بدون intl package) ──────────────────────────────
String _fmtDate(dynamic v) {
  if (v == null) return '—';
  try {
    DateTime? d;
    if (v is Timestamp) d = v.toDate();
    if (d == null) return v.toString();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  } catch (_) {
    return '—';
  }
}

String _fmtMonthYear(DateTime d) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[d.month - 1]} ${d.year}';
}

String _fmtMonthCode(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[d.month - 1]}_${d.year}';
}

String _fmtNow() {
  final d = DateTime.now();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ══════════════════════════════════════════════════════════════════════════════
// REPORTS SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Reports',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurface.withOpacity(0.45),
          indicatorColor: cs.primary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.folder_outlined, size: 18), text: 'Projects'),
            Tab(icon: Icon(Icons.task_alt_outlined, size: 18), text: 'Tasks'),
            Tab(
              icon: Icon(Icons.access_time_outlined, size: 18),
              text: 'Attendance',
            ),
            Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Employees'),
            Tab(icon: Icon(Icons.business_outlined, size: 18), text: 'Clients'),
          ],
        ),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _ProjectsReportTab(user: user),
                _TasksReportTab(user: user),
                _AttendanceReportTab(user: user),
                // Employee reports: restricted to management/admin/dept heads
                user.canSeeEmployeeReports
                    ? _EmployeesReportTab(user: user)
                    : const _ReportAccessDenied(),
                // Client reports: restricted to management/admin
                user.canSeeEmployeeReports
                    ? _ClientsReportTab(user: user)
                    : const _ReportAccessDenied(),
              ],
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PROJECTS REPORT
// ══════════════════════════════════════════════════════════════════════════════

class _ProjectsReportTab extends StatefulWidget {
  final UserModel user;
  const _ProjectsReportTab({required this.user});
  @override
  State<_ProjectsReportTab> createState() => _ProjectsReportTabState();
}

class _ProjectsReportTabState extends State<_ProjectsReportTab> {
  String _statusFilter = 'all';
  bool _loading = false;
  List<Map<String, dynamic>>? _data;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final snap = await FirebaseFirestore.instance
        .collection('projects')
        .where('officeId', isEqualTo: widget.user.officeId)
        .get();
    if (mounted) {
      setState(() => _data = snap.docs.map((d) => d.data()).toList());
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final d = _data ?? [];
    return _statusFilter == 'all'
        ? d
        : d.where((p) => p['status'] == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) return const Center(child: CircularProgressIndicator());
    final filtered = _filtered;

    return _ReportLayout(
      filters: _FilterChips(
        options: const {
          'all': 'All',
          'active': 'Active',
          'completed': 'Completed',
          'on_hold': 'On Hold',
        },
        selected: _statusFilter,
        onSelected: (v) => setState(() => _statusFilter = v),
      ),
      summary: _SummaryRow(
        items: [
          _SI('Total', data.length.toString(), Icons.folder_outlined),
          _SI(
            'Active',
            data.where((p) => p['status'] == 'active').length.toString(),
            Icons.play_circle_outline,
            Colors.green,
          ),
          _SI(
            'Done',
            data.where((p) => p['status'] == 'completed').length.toString(),
            Icons.check_circle_outline,
            Colors.blue,
          ),
          _SI(
            'On Hold',
            data.where((p) => p['status'] == 'on_hold').length.toString(),
            Icons.pause_circle_outline,
            Colors.orange,
          ),
        ],
      ),
      exportButtons: _ExportButtons(
        loading: _loading,
        onPdf: () => _exportPdf(filtered),
        onExcel: () => _exportExcel(filtered),
      ),
      table: _Table(
        columns: const [
          'Project Name',
          'Client',
          'Status',
          'Progress',
          'End Date',
        ],
        rows: filtered
            .map(
              (p) => [
                p['name'] ?? '—',
                p['clientName'] ?? '—',
                _statusLabel(p['status']),
                '${(p['completionPercentage'] ?? 0).toStringAsFixed(0)}%',
                _fmtDate(p['endDate']),
              ],
            )
            .toList(),
      ),
    );
  }

  Future<void> _exportPdf(List<Map<String, dynamic>> data) async {
    setState(() => _loading = true);
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (ctx) => [
            _pdfHeader('Projects Report'),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: [
                'Project Name',
                'Client',
                'Status',
                'Progress %',
                'End Date',
              ],
              data: data
                  .map(
                    (p) => [
                      p['name'] ?? '—',
                      p['clientName'] ?? '—',
                      _statusLabel(p['status']),
                      '${(p['completionPercentage'] ?? 0).toStringAsFixed(0)}%',
                      _fmtDate(p['endDate']),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF2E7D32),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F8E9),
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          ],
        ),
      );
      await _sharePdf(await pdf.save(), 'projects_report.pdf');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportExcel(List<Map<String, dynamic>> data) async {
    setState(() => _loading = true);
    try {
      final excel = _createExcel('Projects');
      final sheet = excel['Projects'];
      _excelHeader(sheet, [
        'Project Name',
        'Client',
        'Status',
        'Progress %',
        'End Date',
        'Start Date',
      ]);
      for (var ri = 1; ri <= data.length; ri++) {
        final p = data[ri - 1];
        _excelRow(sheet, [
          TextCellValue(p['name'] ?? ''),
          TextCellValue(p['clientName'] ?? ''),
          TextCellValue(_statusLabel(p['status'])),
          TextCellValue(
            '${(p['completionPercentage'] ?? 0).toStringAsFixed(0)}%',
          ),
          TextCellValue(_fmtDate(p['endDate'])),
          TextCellValue(_fmtDate(p['startDate'])),
        ], ri);
      }
      await _shareExcel(excel, 'projects_report.xlsx');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TASKS REPORT
// ══════════════════════════════════════════════════════════════════════════════

class _TasksReportTab extends StatefulWidget {
  final UserModel user;
  const _TasksReportTab({required this.user});
  @override
  State<_TasksReportTab> createState() => _TasksReportTabState();
}

class _TasksReportTabState extends State<_TasksReportTab> {
  String _groupBy = 'project';
  String _statusFilter = 'all';
  bool _loading = false;
  List<Map<String, dynamic>>? _data;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final snap = await FirebaseFirestore.instance
        .collection('tasks')
        .where('officeId', isEqualTo: widget.user.officeId)
        .get();
    if (mounted) {
      setState(() => _data = snap.docs.map((d) => d.data()).toList());
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final d = _data ?? [];
    return _statusFilter == 'all'
        ? d
        : d.where((t) => t['status'] == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) return const Center(child: CircularProgressIndicator());
    final filtered = _filtered;

    return _ReportLayout(
      filters: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Group by:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(width: 10),
              _Pill(
                label: 'Project',
                selected: _groupBy == 'project',
                onTap: () => setState(() => _groupBy = 'project'),
              ),
              const SizedBox(width: 6),
              _Pill(
                label: 'Employee',
                selected: _groupBy == 'employee',
                onTap: () => setState(() => _groupBy = 'employee'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FilterChips(
            options: const {
              'all': 'All',
              'not_started': 'Not Started',
              'in_progress': 'In Progress',
              'under_review': 'Under Review',
              'completed': 'Completed',
            },
            selected: _statusFilter,
            onSelected: (v) => setState(() => _statusFilter = v),
          ),
        ],
      ),
      summary: _SummaryRow(
        items: [
          _SI('Total', data.length.toString(), Icons.task_outlined),
          _SI(
            'In Progress',
            data.where((t) => t['status'] == 'in_progress').length.toString(),
            Icons.pending_outlined,
            Colors.orange,
          ),
          _SI(
            'Review',
            data.where((t) => t['status'] == 'under_review').length.toString(),
            Icons.rate_review_outlined,
            Colors.indigo,
          ),
          _SI(
            'Done',
            data.where((t) => t['status'] == 'completed').length.toString(),
            Icons.check_circle_outline,
            Colors.green,
          ),
        ],
      ),
      exportButtons: _ExportButtons(
        loading: _loading,
        onPdf: () => _exportPdf(filtered),
        onExcel: () => _exportExcel(filtered),
      ),
      table: _Table(
        columns: [
          'Task',
          _groupBy == 'project' ? 'Project' : 'Assigned To',
          'Status',
          'Est. Hrs',
          'Due Date',
        ],
        rows: filtered
            .map(
              (t) => [
                t['title'] ?? '—',
                _groupBy == 'project'
                    ? (t['projectName'] ?? t['projectId'] ?? '—')
                    : (t['assignedToName'] ?? '—'),
                _taskStatusLabel(t['status']),
                '${t['estimatedHours'] ?? 0}h',
                _fmtDate(t['dueDate']),
              ],
            )
            .toList(),
      ),
    );
  }

  Future<void> _exportPdf(List<Map<String, dynamic>> data) async {
    setState(() => _loading = true);
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (ctx) => [
            _pdfHeader('Tasks Report'),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: [
                'Task',
                'Project',
                'Assigned To',
                'Status',
                'Est. Hours',
                'Due Date',
              ],
              data: data
                  .map(
                    (t) => [
                      t['title'] ?? '—',
                      t['projectName'] ?? t['projectId'] ?? '—',
                      t['assignedToName'] ?? '—',
                      _taskStatusLabel(t['status']),
                      '${t['estimatedHours'] ?? 0}h',
                      _fmtDate(t['dueDate']),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF2E7D32),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F8E9),
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          ],
        ),
      );
      await _sharePdf(await pdf.save(), 'tasks_report.pdf');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportExcel(List<Map<String, dynamic>> data) async {
    setState(() => _loading = true);
    try {
      final excel = _createExcel('Tasks');
      final sheet = excel['Tasks'];
      _excelHeader(sheet, [
        'Task',
        'Project',
        'Assigned To',
        'Status',
        'Est. Hours',
        'Actual Hours',
        'Due Date',
      ]);
      for (var ri = 1; ri <= data.length; ri++) {
        final t = data[ri - 1];
        _excelRow(sheet, [
          TextCellValue(t['title'] ?? ''),
          TextCellValue(t['projectName'] ?? t['projectId'] ?? ''),
          TextCellValue(t['assignedToName'] ?? ''),
          TextCellValue(_taskStatusLabel(t['status'])),
          TextCellValue('${t['estimatedHours'] ?? 0}'),
          TextCellValue('${t['actualHours'] ?? 0}'),
          TextCellValue(_fmtDate(t['dueDate'])),
        ], ri);
      }
      await _shareExcel(excel, 'tasks_report.xlsx');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ATTENDANCE REPORT
// ══════════════════════════════════════════════════════════════════════════════

class _AttendanceReportTab extends StatefulWidget {
  final UserModel user;
  const _AttendanceReportTab({required this.user});
  @override
  State<_AttendanceReportTab> createState() => _AttendanceReportTabState();
}

class _AttendanceReportTabState extends State<_AttendanceReportTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = false;
  List<Map<String, dynamic>>? _data;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final y = _month.year;
    final m = _month.month.toString().padLeft(2, '0');
    final lastDay = DateTime(_month.year, _month.month + 1, 0).day;
    final snap = await FirebaseFirestore.instance
        .collection('attendance')
        .where('officeId', isEqualTo: widget.user.officeId)
        .where('date', isGreaterThanOrEqualTo: '$y-$m-01')
        .where(
          'date',
          isLessThanOrEqualTo: '$y-$m-${lastDay.toString().padLeft(2, '0')}',
        )
        .orderBy('date')
        .get();
    if (mounted) {
      setState(() => _data = snap.docs.map((d) => d.data()).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final present = data?.where((r) => r['status'] == 'present').length ?? 0;
    final late = data?.where((r) => r['status'] == 'late').length ?? 0;
    final absent = data?.where((r) => r['status'] == 'absent').length ?? 0;

    return _ReportLayout(
      filters: _MonthPicker(
        selected: _month,
        onChanged: (d) {
          setState(() {
            _month = d;
            _data = null;
          });
          _fetch();
        },
      ),
      summary: _SummaryRow(
        items: [
          _SI(
            'Present',
            present.toString(),
            Icons.check_circle_outline,
            Colors.green,
          ),
          _SI(
            'Late',
            late.toString(),
            Icons.watch_later_outlined,
            Colors.orange,
          ),
          _SI('Absent', absent.toString(), Icons.cancel_outlined, Colors.red),
          _SI('Total', (data?.length ?? 0).toString(), Icons.list_alt_outlined),
        ],
      ),
      exportButtons: _ExportButtons(
        loading: _loading,
        onPdf: () => _exportPdf(data ?? []),
        onExcel: () => _exportExcel(data ?? []),
      ),
      table: data == null
          ? const Center(child: CircularProgressIndicator())
          : _Table(
              columns: const [
                'Employee',
                'Date',
                'Check In',
                'Check Out',
                'Hours',
                'Status',
              ],
              rows: data
                  .map(
                    (r) => [
                      r['employeeName'] ?? '—',
                      r['date'] ?? '—',
                      _fmtTime(r['checkIn']),
                      _fmtTime(r['checkOut']),
                      _calcHours(r['checkIn'], r['checkOut']),
                      _attendanceLabel(r['status']),
                    ],
                  )
                  .toList(),
            ),
    );
  }

  Future<void> _exportPdf(List<Map<String, dynamic>> data) async {
    setState(() => _loading = true);
    try {
      final label = _fmtMonthYear(_month);
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (ctx) => [
            _pdfHeader('Attendance Report — $label'),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: [
                'Employee',
                'Date',
                'Check In',
                'Check Out',
                'Hours',
                'Status',
              ],
              data: data
                  .map(
                    (r) => [
                      r['employeeName'] ?? '—',
                      r['date'] ?? '—',
                      _fmtTime(r['checkIn']),
                      _fmtTime(r['checkOut']),
                      _calcHours(r['checkIn'], r['checkOut']),
                      _attendanceLabel(r['status']),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF2E7D32),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F8E9),
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          ],
        ),
      );
      await _sharePdf(
        await pdf.save(),
        'attendance_${_fmtMonthCode(_month)}.pdf',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportExcel(List<Map<String, dynamic>> data) async {
    setState(() => _loading = true);
    try {
      final excel = _createExcel('Attendance');
      final sheet = excel['Attendance'];
      _excelHeader(sheet, [
        'Employee',
        'Date',
        'Check In',
        'Check Out',
        'Hours',
        'Status',
      ]);
      for (var ri = 1; ri <= data.length; ri++) {
        final r = data[ri - 1];
        _excelRow(sheet, [
          TextCellValue(r['employeeName'] ?? ''),
          TextCellValue(r['date'] ?? ''),
          TextCellValue(_fmtTime(r['checkIn'])),
          TextCellValue(_fmtTime(r['checkOut'])),
          TextCellValue(_calcHours(r['checkIn'], r['checkOut'])),
          TextCellValue(_attendanceLabel(r['status'])),
        ], ri);
      }
      await _shareExcel(excel, 'attendance_${_fmtMonthCode(_month)}.xlsx');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtTime(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate().toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _calcHours(dynamic i, dynamic o) {
    if (i is! Timestamp || o is! Timestamp) return '—';
    final diff = o.toDate().difference(i.toDate());
    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EMPLOYEES REPORT
// ══════════════════════════════════════════════════════════════════════════════

class _ReportAccessDenied extends StatelessWidget {
  const _ReportAccessDenied();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, size: 56, color: cs.subtleText),
          const SizedBox(height: 16),
          Text('Restricted', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cs.onSurface)),
          const SizedBox(height: 8),
          Text(
            'Employee reports are only available\nto management and department heads.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.subtleText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _EmployeesReportTab extends StatefulWidget {
  final UserModel user;
  const _EmployeesReportTab({required this.user});
  @override
  State<_EmployeesReportTab> createState() => _EmployeesReportTabState();
}

class _EmployeesReportTabState extends State<_EmployeesReportTab> {
  String _deptFilter = 'all';
  bool _loading = false;
  List<Map<String, dynamic>>? _data;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('officeId', isEqualTo: widget.user.officeId)
        .get();
    if (mounted) {
      setState(
        () => _data = snap.docs
            .map((d) => d.data())
            // استبعاد الـ clients من تقرير الموظفين
            .where((e) => e['role'] != 'client')
            .toList(),
      );
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final d = _data ?? [];
    return _deptFilter == 'all'
        ? d
        : d.where((e) => e['department'] == _deptFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) return const Center(child: CircularProgressIndicator());

    final depts =
        data
            .map((e) => e['department'] as String? ?? '')
            .where((d) => d.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final deptOptions = <String, String>{'all': 'All'};
    for (final d in depts) {
      deptOptions[d] = d;
    }
    final filtered = _filtered;

    return _ReportLayout(
      filters: _FilterChips(
        options: deptOptions,
        selected: _deptFilter,
        onSelected: (v) => setState(() => _deptFilter = v),
      ),
      summary: _SummaryRow(
        items: [
          _SI('Total', data.length.toString(), Icons.people_outline),
          _SI(
            'Active',
            data.where((e) => e['isActive'] == true).length.toString(),
            Icons.check_circle_outline,
            Colors.green,
          ),
          _SI(
            'Suspended',
            data.where((e) => e['status'] == 'suspended').length.toString(),
            Icons.pause_circle_outline,
            Colors.orange,
          ),
          _SI(
            'Admin',
            data.where((e) => e['adminFlag'] == true).length.toString(),
            Icons.admin_panel_settings_outlined,
            Colors.deepPurple,
          ),
        ],
      ),
      exportButtons: _ExportButtons(
        loading: _loading,
        onPdf: () => _exportPdf(filtered),
        onExcel: () => _exportExcel(filtered),
      ),
      table: _Table(
        columns: const [
          'Code',
          'Name',
          'Job Title',
          'Department',
          'Role',
          'Join Date',
          'Status',
        ],
        rows: filtered
            .map(
              (e) => [
                e['employeeCode'] ?? '—',
                e['name'] ?? '—',
                e['jobTitle'] ?? '—',
                e['department'] ?? '—',
                e['role'] ?? '—',
                _fmtDate(e['joinDate']),
                e['status'] ?? '—',
              ],
            )
            .toList(),
      ),
    );
  }

  Future<void> _exportPdf(List<Map<String, dynamic>> data) async {
    setState(() => _loading = true);
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => [
            _pdfHeader('Employees Report'),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: [
                'Code',
                'Name',
                'Job Title',
                'Department',
                'Role',
                'Join Date',
                'Status',
              ],
              data: data
                  .map(
                    (e) => [
                      e['employeeCode'] ?? '—',
                      e['name'] ?? '—',
                      e['jobTitle'] ?? '—',
                      e['department'] ?? '—',
                      e['role'] ?? '—',
                      _fmtDate(e['joinDate']),
                      e['status'] ?? '—',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF2E7D32),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F8E9),
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          ],
        ),
      );
      await _sharePdf(await pdf.save(), 'employees_report.pdf');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportExcel(List<Map<String, dynamic>> data) async {
    setState(() => _loading = true);
    try {
      final excel = _createExcel('Employees');
      final sheet = excel['Employees'];
      _excelHeader(sheet, [
        'Code',
        'Name',
        'Email',
        'Job Title',
        'Department',
        'Role',
        'Admin',
        'Join Date',
        'Status',
        'Phone',
      ]);
      for (var ri = 1; ri <= data.length; ri++) {
        final e = data[ri - 1];
        final joinDate = e['joinDate'] is Timestamp
            ? _fmtDate(e['joinDate'])
            : '—';
        _excelRow(sheet, [
          TextCellValue(e['employeeCode'] ?? ''),
          TextCellValue(e['name'] ?? ''),
          TextCellValue(e['email'] ?? ''),
          TextCellValue(e['jobTitle'] ?? ''),
          TextCellValue(e['department'] ?? ''),
          TextCellValue(e['role'] ?? ''),
          TextCellValue(e['adminFlag'] == true ? 'Yes' : 'No'),
          TextCellValue(joinDate),
          TextCellValue(e['status'] ?? ''),
          TextCellValue(e['phone'] ?? ''),
        ], ri);
      }
      await _shareExcel(excel, 'employees_report.xlsx');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════════════════════
// CLIENTS REPORT TAB
// ══════════════════════════════════════════════════════════════════════════════

class _ClientsReportTab extends StatefulWidget {
  final UserModel user;
  const _ClientsReportTab({required this.user});
  @override
  State<_ClientsReportTab> createState() => _ClientsReportTabState();
}

class _ClientsReportTabState extends State<_ClientsReportTab> {
  bool _loading = false;
  List<Map<String, dynamic>>? _data;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    // جلب الـ users اللي role = 'client' من نفس المكتب
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('officeId', isEqualTo: widget.user.officeId)
        .where('role', isEqualTo: 'client')
        .get();
    if (mounted) {
      setState(() => _data = snap.docs.map((d) => d.data()).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) return const Center(child: CircularProgressIndicator());

    // نجيب أسماء الـ clients المرتبطين من clients collection
    return _ClientsReportBody(
      officeId: widget.user.officeId,
      clientUsers: data,
      loading: _loading,
      onExportPdf: () => _exportPdf(data),
      onExportExcel: () => _exportExcel(data),
    );
  }

  Future<void> _exportPdf(List<Map<String, dynamic>> data) async {
    setState(() => _loading = true);
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => [
            _pdfHeader('Clients Report'),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: ['Code', 'Name', 'Email', 'Phone', 'Status'],
              data: data
                  .map(
                    (e) => [
                      e['employeeCode'] ?? '—',
                      e['name'] ?? '—',
                      e['email'] ?? '—',
                      e['phone'] ?? '—',
                      e['status'] ?? '—',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          ],
        ),
      );
      await _sharePdf(await pdf.save(), 'clients_report.pdf');
    } catch (e) {
      debugPrint('PDF error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportExcel(List<Map<String, dynamic>> data) async {
    setState(() => _loading = true);
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Clients'];
      sheet.appendRow(
        [
          'Code',
          'Name',
          'Email',
          'Phone',
          'Status',
        ].map(TextCellValue.new).toList(),
      );
      for (final e in data) {
        sheet.appendRow([
          TextCellValue(e['employeeCode'] ?? ''),
          TextCellValue(e['name'] ?? ''),
          TextCellValue(e['email'] ?? ''),
          TextCellValue(e['phone'] ?? ''),
          TextCellValue(e['status'] ?? ''),
        ]);
      }
      await _shareExcel(excel, 'clients_report.xlsx');
    } catch (e) {
      debugPrint('Excel error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _ClientsReportBody extends StatelessWidget {
  final String officeId;
  final List<Map<String, dynamic>> clientUsers;
  final bool loading;
  final Future<void> Function() onExportPdf;
  final Future<void> Function() onExportExcel;

  const _ClientsReportBody({
    required this.officeId,
    required this.clientUsers,
    required this.loading,
    required this.onExportPdf,
    required this.onExportExcel,
  });

  @override
  Widget build(BuildContext context) {
    return _ReportLayout(
      filters: const SizedBox.shrink(),
      summary: _SummaryRow(
        items: [
          _SI(
            'Total Clients',
            clientUsers.length.toString(),
            Icons.business_outlined,
          ),
          _SI(
            'Active',
            clientUsers.where((e) => e['isActive'] == true).length.toString(),
            Icons.check_circle_outline,
            Colors.green,
          ),
        ],
      ),
      exportButtons: _ExportButtons(
        loading: loading,
        onPdf: onExportPdf,
        onExcel: onExportExcel,
      ),
      table: _Table(
        columns: const ['Code', 'Name', 'Email', 'Phone', 'Status'],
        rows: clientUsers
            .map(
              (e) => [
                e['employeeCode'] ?? '—',
                e['name'] ?? '—',
                e['email'] ?? '—',
                e['phone'] ?? '—',
                e['status'] ?? '—',
              ],
            )
            .toList(),
      ),
    );
  }
}

class _ReportLayout extends StatelessWidget {
  final Widget filters, summary, exportButtons, table;
  const _ReportLayout({
    required this.filters,
    required this.summary,
    required this.exportButtons,
    required this.table,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          filters,
          const SizedBox(height: 14),
          summary,
          const SizedBox(height: 16),
          exportButtons,
          const SizedBox(height: 16),
          table,
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SI {
  final String label, value;
  final IconData icon;
  final Color? color;
  const _SI(this.label, this.value, this.icon, [this.color]);
}

class _SummaryRow extends StatelessWidget {
  final List<_SI> items;
  const _SummaryRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: items.asMap().entries.map((e) {
        final item = e.value;
        final color = item.color ?? cs.primary;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: e.key < items.length - 1 ? 8 : 0),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: color, size: 16),
                const SizedBox(height: 6),
                Text(
                  item.value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 9,
                    color: cs.onSurface.withOpacity(0.55),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ExportButtons extends StatelessWidget {
  final bool loading;
  final Future<void> Function() onPdf, onExcel;
  const _ExportButtons({
    required this.loading,
    required this.onPdf,
    required this.onExcel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: loading
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
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: loading ? null : onPdf,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            icon: loading
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
            onPressed: loading ? null : onExcel,
          ),
        ),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  final List<String> columns;
  final List<List<dynamic>> rows;
  const _Table({required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.inbox_outlined,
                color: cs.onSurface.withOpacity(0.3),
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                'No data found',
                style: TextStyle(color: cs.onSurface.withOpacity(0.4)),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            cs.primaryContainer.withOpacity(0.4),
          ),
          dataRowMinHeight: 38,
          dataRowMaxHeight: 46,
          columnSpacing: 14,
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: cs.onSurface,
          ),
          dataTextStyle: TextStyle(
            fontSize: 11,
            color: cs.onSurface.withOpacity(0.85),
          ),
          columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
          rows: rows
              .asMap()
              .entries
              .map(
                (entry) => DataRow(
                  color: WidgetStateProperty.all(
                    entry.key.isEven
                        ? Colors.transparent
                        : cs.surfaceContainerHighest.withOpacity(0.3),
                  ),
                  cells: entry.value
                      .map((cell) => DataCell(Text(cell?.toString() ?? '—')))
                      .toList(),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  const _FilterChips({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.entries
          .map(
            (e) => FilterChip(
              label: Text(
                e.value,
                style: TextStyle(
                  fontSize: 11,
                  color: selected == e.key ? cs.onPrimary : cs.onSurface,
                ),
              ),
              selected: selected == e.key,
              onSelected: (_) => onSelected(e.key),
              backgroundColor: cs.surfaceContainerHighest,
              selectedColor: cs.primary,
              checkmarkColor: cs.onPrimary,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? cs.onPrimary : cs.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _MonthPicker extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;
  const _MonthPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCurrentMonth =
        selected.year == DateTime.now().year &&
        selected.month == DateTime.now().month;
    return Row(
      children: [
        IconButton(
          onPressed: () =>
              onChanged(DateTime(selected.year, selected.month - 1)),
          icon: const Icon(Icons.chevron_left_rounded),
          style: IconButton.styleFrom(
            backgroundColor: cs.surfaceContainerHighest,
          ),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  color: cs.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _fmtMonthYear(selected),
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: isCurrentMonth
              ? null
              : () => onChanged(DateTime(selected.year, selected.month + 1)),
          icon: const Icon(Icons.chevron_right_rounded),
          style: IconButton.styleFrom(
            backgroundColor: cs.surfaceContainerHighest,
          ),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════════════════

pw.Widget _pdfHeader(String title) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 18,
        fontWeight: pw.FontWeight.bold,
        color: const PdfColor.fromInt(0xFF2E7D32),
      ),
    ),
    pw.SizedBox(height: 4),
    pw.Text(
      'Generated: ${_fmtNow()}',
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
    ),
    pw.Divider(color: PdfColors.grey300),
  ],
);

void _excelHeader(Sheet sheet, List<String> headers) {
  // Header row
  sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

  // تنسيق الـ header
  for (var i = 0; i < headers.length; i++) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
    );
    cell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#2E7D32'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      fontSize: 11,
    );
    sheet.setColumnWidth(i, _colWidth(headers[i]));
  }
}

Excel _createExcel(String sheetName) {
  final excel = Excel.createExcel();
  // بدل ما نحذف Sheet1، نعمل rename ليها بالاسم المطلوب
  excel.rename('Sheet1', sheetName);
  return excel;
}

double _colWidth(String header) {
  switch (header.toLowerCase()) {
    case 'name':
    case 'project name':
    case 'project':
    case 'task':
      return 28;
    case 'email':
      return 30;
    case 'job title':
      return 24;
    case 'department':
      return 18;
    case 'role':
      return 16;
    case 'status':
      return 14;
    case 'code':
      return 12;
    case 'phone':
      return 18;
    case 'admin':
      return 10;
    case 'join date':
    case 'due date':
    case 'end date':
    case 'start date':
    case 'date':
      return 16;
    case 'check in':
    case 'check out':
      return 12;
    case 'hours':
    case 'est. hours':
    case 'actual hours':
    case 'progress %':
      return 14;
    default:
      return 20;
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

String _statusLabel(String? s) =>
    const {
      'active': 'Active',
      'completed': 'Completed',
      'on_hold': 'On Hold',
      'cancelled': 'Cancelled',
    }[s] ??
    (s ?? '—');
String _taskStatusLabel(String? s) =>
    const {
      'not_started': 'Not Started',
      'in_progress': 'In Progress',
      'under_review': 'Under Review',
      'completed': 'Completed',
    }[s] ??
    (s ?? '—');
String _attendanceLabel(String? s) =>
    const {'present': 'Present', 'late': 'Late', 'absent': 'Absent'}[s] ??
    (s ?? '—');

Future<void> _sharePdf(Uint8List bytes, String filename) async {
  // Printing.sharePdf بيشتغل على Web + Android + iOS
  await Printing.sharePdf(bytes: bytes, filename: filename);
}

Future<void> _shareExcel(Excel excel, String filename) async {
  try {
    final bytes = excel.encode();
    if (bytes == null) return;
    // downloadExcel بييجي من conditional import (web أو mobile)
    await downloadExcel(Uint8List.fromList(bytes), filename);
  } catch (e) {
    debugPrint('Excel export error: $e');
  }
}
