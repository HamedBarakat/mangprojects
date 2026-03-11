import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../office/data/models/office_model.dart';
import '../../office/data/models/office_settings_model.dart';
import '../../home/data/models/user_model.dart';

class DeveloperRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Check if current user is developer ───────────────────────────────────
  Future<bool> isDeveloper(String uid) async {
    final doc = await _db.collection('developers').doc(uid).get();
    return doc.exists;
  }

  // ── Watch all offices ─────────────────────────────────────────────────────
  Stream<List<OfficeModel>> watchAllOffices() {
    return _db
        .collection('offices')
        .snapshots()
        .map((s) => s.docs.map((d) => OfficeModel.fromFirestore(d)).toList());
  }

  // ── Create new office + admin user ───────────────────────────────────────
  Future<void> createOffice({
    required String officeName,
    required String officeCode,
    required String adminEmail,
    required String adminPassword,
    required String adminName,
    required String devEmail,
    required String devPassword,
    String workStartTime = '09:00',
    String workEndTime   = '17:00',
  }) async {
    // 1. Create admin user (this will sign out developer)
    final cred = await _auth.createUserWithEmailAndPassword(
      email: adminEmail,
      password: adminPassword,
    );
    final adminUid = cred.user!.uid;

    // 2. Sign out admin immediately
    await _auth.signOut();

    // 3. Re-login as developer
    await _auth.signInWithEmailAndPassword(
      email: devEmail,
      password: devPassword,
    );

    // 4. Create office doc
    final officeRef = _db.collection('offices').doc();
    await officeRef.set({
      'name':          officeName,
      'code':          officeCode.toUpperCase(),
      'logo':          '',
      'isActive':      true,
      'workStartTime': workStartTime,
      'workEndTime':   workEndTime,
      'createdAt':     FieldValue.serverTimestamp(),
    });

    // 5. Create admin user doc
    await _db.collection('users').doc(adminUid).set({
      'uid':          adminUid,
      'officeId':     officeRef.id,
      'employeeCode': 'ADMIN001',
      'name':         adminName,
      'email':        adminEmail,
      'phone':        '',
      'role':         'admin',
      'adminFlag':    true,
      'department':   '',
      'jobTitle':     '',
      'status':       'active',
      'isActive':     true,
      'createdAt':    FieldValue.serverTimestamp(),
    });

    // 6. Initialize office settings
    await _db
        .collection('offices')
        .doc(officeRef.id)
        .collection('settings')
        .doc('main')
        .set(OfficeSettingsModel.defaults(officeRef.id).toFirestore());
  }

  // ── Toggle office active status ───────────────────────────────────────────
  Future<void> toggleOfficeStatus({
    required String officeId,
    required bool isActive,
    String? suspendReason,
  }) async {
    await _db.collection('offices').doc(officeId).update({
      'isActive':       isActive,
      'suspendedAt':    isActive ? null : FieldValue.serverTimestamp(),
      'suspendReason':  isActive ? null : (suspendReason ?? ''),
    });
  }

  // ── Get all users of an office ────────────────────────────────────────────
  Future<List<UserModel>> getOfficeUsers(String officeId) async {
    final snap = await _db
        .collection('users')
        .where('officeId', isEqualTo: officeId)
        .get();
    return snap.docs.map((d) => UserModel.fromFirestore(d)).toList();
  }

  // ── Update user email in Firestore (label only) ───────────────────────────
  Future<void> updateUserEmail({
    required String uid,
    required String newEmail,
  }) async {
    await _db.collection('users').doc(uid).update({'email': newEmail});
  }

  // ── Reset user password via Firebase Auth email ───────────────────────────
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Update office settings ────────────────────────────────────────────────
  Future<void> updateOfficeName({
    required String officeId,
    required String name,
  }) async {
    await _db.collection('offices').doc(officeId).update({'name': name});
  }

  Future<void> updateOfficeWorkHours({
    required String officeId,
    required String start,
    required String end,
  }) async {
    await _db.collection('offices').doc(officeId).update({
      'workStartTime': start,
      'workEndTime':   end,
    });
  }

  // ── Watch office settings ─────────────────────────────────────────────────
  Stream<OfficeSettingsModel> watchOfficeSettings(String officeId) {
    return _db
        .collection('offices')
        .doc(officeId)
        .collection('settings')
        .doc('main')
        .snapshots()
        .map((doc) => doc.exists
            ? OfficeSettingsModel.fromFirestore(doc)
            : OfficeSettingsModel.defaults(officeId));
  }

  // ── Delete office (careful!) ──────────────────────────────────────────────
  Future<void> deleteOffice(String officeId) async {
    await _db.collection('offices').doc(officeId).delete();
  }
}
