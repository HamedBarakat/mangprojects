import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/attendance_model.dart';
import 'package:mang_projects/features/office/data/models/office_model.dart';

class AttendanceRepository {
  final _db = FirebaseFirestore.instance;

  // ── Get office work times ─────────────────────────────────────────────────
  Future<OfficeModel> _getOffice(String officeId) async {
    final doc = await _db.collection('offices').doc(officeId).get();
    return OfficeModel.fromFirestore(doc);
  }

  // ── Check In ──────────────────────────────────────────────────────────────
  Future<String> checkIn({
    required String officeId,
    required String employeeId,
    required String employeeName,
    required String employeeCode,
  }) async {
    final now = DateTime.now();
    final date = _dateKey(now);

    // منع الـ duplicate في نفس اليوم
    final existing = await _db
        .collection('attendance')
        .where('officeId', isEqualTo: officeId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isEqualTo: date)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Already checked in today');
    }

    // جيب وقت بداية العمل من الـ office
    final office = await _getOffice(officeId);
    final status = office.isLate(now) ? 'late' : 'present';

    final doc = await _db.collection('attendance').add({
      'officeId': officeId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeeCode': employeeCode,
      'checkIn': Timestamp.fromDate(now),
      'checkOut': null,
      'status': status,
      'date': date,
      'notes': '',
    });

    return doc.id;
  }

  // ── Check Out ─────────────────────────────────────────────────────────────
  /// بيرجع true لو الوقت بعد workEndTime → يعني في overtime
  /// الـ UI هيسأل الموظف يطلب موافقة على الـ overtime
  Future<bool> checkOut({
    required String officeId,
    required String recordId,
  }) async {
    final now = DateTime.now();
    final office = await _getOffice(officeId);
    final isOvertime = office.isOvertime(now);

    await _db.collection('attendance').doc(recordId).update({
      'checkOut': Timestamp.fromDate(now),
    });

    return isOvertime;
  }

  // ── Request Overtime ──────────────────────────────────────────────────────
  Future<void> requestOvertime({
    required String officeId,
    required String employeeId,
    required String employeeName,
    required String attendanceRecordId,
    required String date,
    required double extraHours,
    String notes = '',
  }) async {
    await _db.collection('overtime_requests').add({
      'officeId': officeId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'attendanceRecordId': attendanceRecordId,
      'date': date,
      'extraHours': extraHours,
      'status': 'pending', // pending / approved / rejected
      'approvedBy': null,
      'approvedAt': null,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Approve / Reject Overtime (Admin only) ────────────────────────────────
  Future<void> respondToOvertime({
    required String requestId,
    required String adminId,
    required bool approved,
  }) async {
    await _db.collection('overtime_requests').doc(requestId).update({
      'status': approved ? 'approved' : 'rejected',
      'approvedBy': adminId,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Watch pending overtime requests (Admin) ───────────────────────────────
  Stream<List<Map<String, dynamic>>> watchPendingOvertimeRequests(
    String officeId,
  ) {
    return _db
        .collection('overtime_requests')
        .where('officeId', isEqualTo: officeId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }

  // ── Watch today's record for a specific employee ──────────────────────────
  Stream<AttendanceModel?> watchTodayRecord({
    required String officeId,
    required String employeeId,
  }) {
    final today = _dateKey(DateTime.now());
    return _db
        .collection('attendance')
        .where('officeId', isEqualTo: officeId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isEqualTo: today)
        .limit(1)
        .snapshots()
        .map(
          (snap) => snap.docs.isEmpty
              ? null
              : AttendanceModel.fromFirestore(snap.docs.first),
        );
  }

  // ── Watch all attendance for today (Admin view) ───────────────────────────
  Stream<List<AttendanceModel>> watchTodayAll(String officeId) {
    final today = _dateKey(DateTime.now());
    return _db
        .collection('attendance')
        .where('officeId', isEqualTo: officeId)
        .where('date', isEqualTo: today)
        .orderBy('checkIn', descending: false)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => AttendanceModel.fromFirestore(d)).toList(),
        );
  }

  // ── Watch monthly records for one employee ────────────────────────────────
  Stream<List<AttendanceModel>> watchMonthlyRecords({
    required String officeId,
    required String employeeId,
    required int year,
    required int month,
  }) {
    final prefix = '${year.toString()}-${month.toString().padLeft(2, '0')}';
    return _db
        .collection('attendance')
        .where('officeId', isEqualTo: officeId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isGreaterThanOrEqualTo: '$prefix-01')
        .where('date', isLessThanOrEqualTo: '$prefix-31')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => AttendanceModel.fromFirestore(d)).toList(),
        );
  }

  // ── Monthly stats for one employee ────────────────────────────────────────
  Future<Map<String, int>> getMonthlyStats({
    required String officeId,
    required String employeeId,
    required int year,
    required int month,
  }) async {
    final prefix = '${year.toString()}-${month.toString().padLeft(2, '0')}';
    final snap = await _db
        .collection('attendance')
        .where('officeId', isEqualTo: officeId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isGreaterThanOrEqualTo: '$prefix-01')
        .where('date', isLessThanOrEqualTo: '$prefix-31')
        .get();

    final records = snap.docs
        .map((d) => AttendanceModel.fromFirestore(d))
        .toList();

    return {
      'present': records.where((r) => r.status == 'present').length,
      'late': records.where((r) => r.status == 'late').length,
      'absent': records.where((r) => r.status == 'absent').length,
    };
  }

  // ── Helper ────────────────────────────────────────────────────────────────
  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
