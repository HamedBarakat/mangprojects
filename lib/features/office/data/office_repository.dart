import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/office_model.dart';

class OfficeRepository {
  final FirebaseFirestore _db;

  OfficeRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// Find an office by its code (e.g. "AFAQ2026").
  Future<OfficeModel?> findByCode(String code) async {
    final snap = await _db
        .collection('offices')
        .where('code', isEqualTo: code.trim().toUpperCase())
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return OfficeModel.fromFirestore(snap.docs.first);
  }

  /// Get office by ID
  Future<OfficeModel?> getOffice(String officeId) async {
    final doc = await _db.collection('offices').doc(officeId).get();
    if (!doc.exists) return null;
    return OfficeModel.fromFirestore(doc);
  }

  /// Watch office changes in real-time
  Stream<OfficeModel?> watchOffice(String officeId) {
    return _db
        .collection('offices')
        .doc(officeId)
        .snapshots()
        .map((doc) => doc.exists ? OfficeModel.fromFirestore(doc) : null);
  }

  /// Update work hours (Admin only)
  Future<void> updateWorkHours({
    required String officeId,
    required String workStartTime,
    required String workEndTime,
  }) async {
    await _db.collection('offices').doc(officeId).update({
      'workStartTime': workStartTime,
      'workEndTime': workEndTime,
    });
  }

  /// Write officeId into users/{userId} after login + office confirmed.
  Future<void> assignOfficeToUser({
    required String userId,
    required String officeId,
  }) async {
    await _db.collection('users').doc(userId).update({'officeId': officeId});
  }
}
