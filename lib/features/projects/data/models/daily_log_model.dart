import 'package:cloud_firestore/cloud_firestore.dart';

// ── Daily Log Entry ────────────────────────────────────────────────────────────
// كل entry بتمثل ساعات على تاسك معين في يوم معين

class DailyLogEntry {
  final String taskId;
  final String taskTitle;
  final String projectId;
  final String projectName;
  final double hours;

  const DailyLogEntry({
    required this.taskId,
    required this.taskTitle,
    required this.projectId,
    required this.projectName,
    required this.hours,
  });

  factory DailyLogEntry.fromMap(Map<String, dynamic> d) {
    return DailyLogEntry(
      taskId:      d['taskId'] ?? '',
      taskTitle:   d['taskTitle'] ?? '',
      projectId:   d['projectId'] ?? '',
      projectName: d['projectName'] ?? '',
      hours:       (d['hours'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId':      taskId,
      'taskTitle':   taskTitle,
      'projectId':   projectId,
      'projectName': projectName,
      'hours':       hours,
    };
  }
}

// ── Daily Log ──────────────────────────────────────────────────────────────────
// سجل يومي للموظف — بيوزع ساعات الـ Attendance على التاسكات

class DailyLogModel {
  final String id;
  final String officeId;
  final String employeeId;
  final String employeeName;
  final String date;              // "yyyy-MM-dd"
  final double totalHours;        // من الـ Attendance تلقائي
  final double distributedHours;  // مجموع الـ entries
  final List<DailyLogEntry> entries;
  final bool isSubmitted;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DailyLogModel({
    required this.id,
    required this.officeId,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.totalHours,
    required this.distributedHours,
    required this.entries,
    required this.isSubmitted,
    required this.createdAt,
    this.updatedAt,
  });

  // ── Computed ─────────────────────────────────────────────────────────────
  double get remainingHours => totalHours - distributedHours;
  bool get isFullyDistributed => remainingHours <= 0;
  bool get hasEntries => entries.isNotEmpty;

  // ── Firestore ─────────────────────────────────────────────────────────────
  factory DailyLogModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DailyLogModel(
      id:                 doc.id,
      officeId:           d['officeId'] ?? '',
      employeeId:         d['employeeId'] ?? '',
      employeeName:       d['employeeName'] ?? '',
      date:               d['date'] ?? '',
      totalHours:         (d['totalHours'] ?? 0).toDouble(),
      distributedHours:   (d['distributedHours'] ?? 0).toDouble(),
      entries:            (d['entries'] as List<dynamic>? ?? [])
                            .map((e) => DailyLogEntry.fromMap(e as Map<String, dynamic>))
                            .toList(),
      isSubmitted:        d['isSubmitted'] ?? false,
      createdAt:          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:          (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'officeId':           officeId,
      'employeeId':         employeeId,
      'employeeName':       employeeName,
      'date':               date,
      'totalHours':         totalHours,
      'distributedHours':   distributedHours,
      'entries':            entries.map((e) => e.toMap()).toList(),
      'isSubmitted':        isSubmitted,
      'createdAt':          Timestamp.fromDate(createdAt),
      'updatedAt':          updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // ── copyWith ──────────────────────────────────────────────────────────────
  DailyLogModel copyWith({
    List<DailyLogEntry>? entries,
    double? distributedHours,
    bool? isSubmitted,
    DateTime? updatedAt,
  }) {
    return DailyLogModel(
      id:               id,
      officeId:         officeId,
      employeeId:       employeeId,
      employeeName:     employeeName,
      date:             date,
      totalHours:       totalHours,
      distributedHours: distributedHours ?? this.distributedHours,
      entries:          entries ?? this.entries,
      isSubmitted:      isSubmitted ?? this.isSubmitted,
      createdAt:        createdAt,
      updatedAt:        updatedAt ?? this.updatedAt,
    );
  }
}
