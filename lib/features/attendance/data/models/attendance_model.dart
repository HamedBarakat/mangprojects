import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String officeId;
  final String employeeId;
  final String employeeName;
  final String employeeCode;
  final DateTime checkIn;
  final DateTime? checkOut;
  final String status;   // present / late / absent
  final String date;     // yyyy-MM-dd
  final String notes;
  // ── Location tracking (NEW) ───────────────────────────────────────────────
  final double? checkInLat;
  final double? checkInLng;
  final double? checkOutLat;
  final double? checkOutLng;
  final String? checkInAddress;

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
    this.checkInLat,
    this.checkInLng,
    this.checkOutLat,
    this.checkOutLng,
    this.checkInAddress,
  });

  Duration? get workDuration {
    if (checkOut == null) return null;
    return checkOut!.difference(checkIn);
  }

  String get workDurationLabel {
    final d = workDuration;
    if (d == null) return '—';
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }

  bool get isCheckedOut => checkOut != null;
  bool get hasLocation => checkInLat != null && checkInLng != null;

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AttendanceModel(
      id:            doc.id,
      officeId:      d['officeId'] ?? '',
      employeeId:    d['employeeId'] ?? '',
      employeeName:  d['employeeName'] ?? '',
      employeeCode:  d['employeeCode'] ?? '',
      checkIn:       (d['checkIn'] as Timestamp).toDate(),
      checkOut:      d['checkOut'] != null ? (d['checkOut'] as Timestamp).toDate() : null,
      status:        d['status'] ?? 'present',
      date:          d['date'] ?? '',
      notes:         d['notes'] ?? '',
      checkInLat:    (d['checkInLat'] as num?)?.toDouble(),
      checkInLng:    (d['checkInLng'] as num?)?.toDouble(),
      checkOutLat:   (d['checkOutLat'] as num?)?.toDouble(),
      checkOutLng:   (d['checkOutLng'] as num?)?.toDouble(),
      checkInAddress: d['checkInAddress'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'officeId':      officeId,
    'employeeId':    employeeId,
    'employeeName':  employeeName,
    'employeeCode':  employeeCode,
    'checkIn':       Timestamp.fromDate(checkIn),
    'checkOut':      checkOut != null ? Timestamp.fromDate(checkOut!) : null,
    'status':        status,
    'date':          date,
    'notes':         notes,
    'checkInLat':    checkInLat,
    'checkInLng':    checkInLng,
    'checkOutLat':   checkOutLat,
    'checkOutLng':   checkOutLng,
    'checkInAddress': checkInAddress,
  };
}
