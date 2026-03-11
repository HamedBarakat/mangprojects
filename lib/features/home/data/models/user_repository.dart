import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class UserRepository {
  final _db = FirebaseFirestore.instance;

  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  Stream<UserModel?> watchUser(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<int> getActiveEmployeesCount(String officeId) async {
    try {
      final snap = await _db
          .collection('users')
          .where('officeId', isEqualTo: officeId)
          .where('status', isEqualTo: 'active')
          .where('role', whereIn: ['engineer', 'admin']).get();
      return snap.docs.length;
    } catch (e) {
      return 0;
    }
  }
}
