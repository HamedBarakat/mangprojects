import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/attendance_model.dart';
import 'package:mang_projects/features/office/data/models/office_model.dart';

class AttendanceRepository {
  final _db = FirebaseFirestore.instance;

  Future<OfficeModel> _getOffice(String officeId) async {
    final doc = await _db.collection('offices').doc(officeId).get();
    return OfficeModel.fromFirestore(doc);
  }

  // ── Distance between two geo coords in meters (Haversine) ─────────────────
  static double distanceMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  // ── Check In ──────────────────────────────────────────────────────────────
  Future<String> checkIn({
    required String officeId,
    required String employeeId,
    required String employeeName,
    required String employeeCode,
    double? lat,
    double? lng,
    String? address,
  }) async {
    final now = DateTime.now();
    final date = _dateKey(now);

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

    final office = await _getOffice(officeId);
    final status = office.isLate(now) ? 'late' : 'present';

    final data = <String, dynamic>{
      'officeId':      officeId,
      'employeeId':    employeeId,
      'employeeName':  employeeName,
      'employeeCode':  employeeCode,
      'checkIn':       Timestamp.fromDate(now),
      'checkOut':      null,
      'status':        status,
      'date':          date,
      'notes':         '',
    };
    if (lat != null) data['checkInLat'] = lat;
    if (lng != null) data['checkInLng'] = lng;
    if (address != null) data['checkInAddress'] = address;

    final doc = await _db.collection('attendance').add(data);
    return doc.id;
  }

  // ── Check Out ─────────────────────────────────────────────────────────────
  Future<bool> checkOut({
    required String officeId,
    required String recordId,
    double? lat,
    double? lng,
  }) async {
    final now = DateTime.now();
    final office = await _getOffice(officeId);
    final isOvertime = office.isOvertime(now);

    final updates = <String, dynamic>{
      'checkOut': Timestamp.fromDate(now),
    };
    if (lat != null) updates['checkOutLat'] = lat;
    if (lng != null) updates['checkOutLng'] = lng;

    await _db.collection('attendance').doc(recordId).update(updates);
    return isOvertime;
  }

  // ── Overtime ──────────────────────────────────────────────────────────────
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
      'officeId':            officeId,
      'employeeId':          employeeId,
      'employeeName':        employeeName,
      'attendanceRecordId':  attendanceRecordId,
      'date':                date,
      'extraHours':          extraHours,
      'status':              'pending',
      'approvedBy':          null,
      'approvedAt':          null,
      'notes':               notes,
      'createdAt':           FieldValue.serverTimestamp(),
    });
  }

  Future<void> respondToOvertime({
    required String requestId,
    required String adminId,
    required bool approved,
  }) async {
    await _db.collection('overtime_requests').doc(requestId).update({
      'status':     approved ? 'approved' : 'rejected',
      'approvedBy': adminId,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Streams ───────────────────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> watchPendingOvertimeRequests(String officeId) {
    return _db
        .collection('overtime_requests')
        .where('officeId', isEqualTo: officeId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

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
        .map((s) => s.docs.isEmpty ? null : AttendanceModel.fromFirestore(s.docs.first));
  }

  Stream<List<AttendanceModel>> watchTodayAll(String officeId) {
    final today = _dateKey(DateTime.now());
    return _db
        .collection('attendance')
        .where('officeId', isEqualTo: officeId)
        .where('date', isEqualTo: today)
        .orderBy('checkIn', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => AttendanceModel.fromFirestore(d)).toList());
  }

  Stream<List<AttendanceModel>> watchMonthlyRecords({
    required String officeId,
    required String employeeId,
    required int year,
    required int month,
  }) {
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    return _db
        .collection('attendance')
        .where('officeId', isEqualTo: officeId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isGreaterThanOrEqualTo: '$prefix-01')
        .where('date', isLessThanOrEqualTo: '$prefix-31')
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => AttendanceModel.fromFirestore(d)).toList());
  }

  Future<Map<String, int>> getMonthlyStats({
    required String officeId,
    required String employeeId,
    required int year,
    required int month,
  }) async {
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final snap = await _db
        .collection('attendance')
        .where('officeId', isEqualTo: officeId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isGreaterThanOrEqualTo: '$prefix-01')
        .where('date', isLessThanOrEqualTo: '$prefix-31')
        .get();
    final records = snap.docs.map((d) => AttendanceModel.fromFirestore(d)).toList();
    return {
      'present': records.where((r) => r.status == 'present').length,
      'late':    records.where((r) => r.status == 'late').length,
      'absent':  records.where((r) => r.status == 'absent').length,
    };
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
