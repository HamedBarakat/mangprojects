import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String officeId;
  final String employeeId;
  final String employeeName;
  final String employeeCode; // e.g. ADMIN001
  final DateTime checkIn;
  final DateTime? checkOut;
  final String status; // present / late / absent
  final String date; // yyyy-MM-dd — للـ queries اليومية
  final String notes;

  const AttendanceModel({
    required this.id,
    required this.officeId,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.checkIn,
    this.checkOut,
    required this.status,
    required this.date,
    this.notes = '',
  });

  // ── مدة الدوام ────────────────────────────────────────────────────────────
  Duration? get workDuration {
    if (checkOut == null) return null;
    return checkOut!.difference(checkIn);
  }

  String get workDurationLabel {
    final d = workDuration;
    if (d == null) return '—';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m}m';
  }

  // ── Status helpers ─────────────────────────────────────────────────────────
  String get statusLabel {
    switch (status) {
      case 'present':
        return 'Present';
      case 'late':
        return 'Late';
      case 'absent':
        return 'Absent';
      default:
        return status;
    }
  }

  bool get isCheckedOut => checkOut != null;

  // ── Firestore ──────────────────────────────────────────────────────────────
  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AttendanceModel(
      id: doc.id,
      officeId: d['officeId'] ?? '',
      employeeId: d['employeeId'] ?? '',
      employeeName: d['employeeName'] ?? '',
      employeeCode: d['employeeCode'] ?? '',
      checkIn: (d['checkIn'] as Timestamp).toDate(),
      checkOut: d['checkOut'] != null
          ? (d['checkOut'] as Timestamp).toDate()
          : null,
      status: d['status'] ?? 'present',
      date: d['date'] ?? '',
      notes: d['notes'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'officeId': officeId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeeCode': employeeCode,
      'checkIn': Timestamp.fromDate(checkIn),
      'checkOut': checkOut != null ? Timestamp.fromDate(checkOut!) : null,
      'status': status,
      'date': date,
      'notes': notes,
    };
  }
}
