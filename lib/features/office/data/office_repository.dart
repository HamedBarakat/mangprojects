import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/office_model.dart';

class OfficeRepository {
  final FirebaseFirestore _db;

  OfficeRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// Find an office by its code (e.g. "SLL-EGY")
  Future<OfficeModel?> findByCode(String code) async {
    try {
      final normalizedCode = code.trim().toUpperCase();

      final querySnapshot = await _db
          .collection('offices')
          .where('code', isEqualTo: normalizedCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;

      final data = doc.data();

      return OfficeModel.fromMap(data, doc.id);
    } catch (e) {
      print("🔥 Firestore ERROR: $e");
      return null;
    }
  }

  /// Get office by ID
  Future<OfficeModel?> getOffice(String officeId) async {
    try {
      final doc = await _db.collection('offices').doc(officeId).get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return OfficeModel.fromFirestore(doc);
    } catch (e) {
      print("OfficeRepository.getOffice ERROR: $e");
      rethrow;
    }
  }

  /// Watch office changes in real-time
  Stream<OfficeModel?> watchOffice(String officeId) {
    return _db.collection('offices').doc(officeId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return OfficeModel.fromFirestore(doc);
    });
  }

  /// Update work hours (Admin only)
  Future<void> updateWorkHours({
    required String officeId,
    required String workStartTime,
    required String workEndTime,
  }) async {
    try {
      await _db.collection('offices').doc(officeId).update({
        'workStartTime': workStartTime,
        'workEndTime': workEndTime,
      });
    } catch (e) {
      print("OfficeRepository.updateWorkHours ERROR: $e");
      rethrow;
    }
  }

  /// Assign officeId to user after login
  Future<void> assignOfficeToUser({
    required String userId,
    required String officeId,
  }) async {
    try {
      await _db.collection('users').doc(userId).update({'officeId': officeId});
    } catch (e) {
      print("OfficeRepository.assignOfficeToUser ERROR: $e");
      rethrow;
    }
  }
}
