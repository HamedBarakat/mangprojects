import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models/employee_model.dart';
import 'package:firebase_core/firebase_core.dart';

class EmployeeRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ── Get all employees for an office ──────────────────────────────────────
  Stream<List<EmployeeModel>> watchEmployees(String officeId) {
    return _db
        .collection('users')
        .where('officeId', isEqualTo: officeId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => EmployeeModel.fromFirestore(doc))
            .toList());
  }

  // ── Get single employee ───────────────────────────────────────────────────
  Future<EmployeeModel?> getEmployee(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return EmployeeModel.fromFirestore(doc);
  }

  // ── Add employee ──────────────────────────────────────────────────────────
  Future<void> addEmployee({
    required String officeId,
    required String email,
    required String password,
    required String name,
    required String employeeCode,
    required String phone,
    required String address,
    required String role,
    required bool adminFlag,
    required String department,
    required String jobTitle,
    required String specialization,
    required int graduationYear,
    required DateTime joinDate,
    required String notes,
  }) async {
    final secondaryApp = await Firebase.initializeApp(
      name: 'secondaryApp',
      options: Firebase.app().options,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      await _db.collection('users').doc(uid).set({
        'uid':            uid,
        'officeId':       officeId,
        'employeeCode':   employeeCode,
        'name':           name,
        'email':          email,
        'phone':          phone,
        'address':        address,
        'role':           role,
        'adminFlag':      adminFlag,
        'department':     department,
        'jobTitle':       jobTitle,
        'specialization': specialization,
        'graduationYear': graduationYear,
        'joinDate':       Timestamp.fromDate(joinDate),
        'status':         'active',
        'rating':         0.0,
        'notes':          notes,
        'isActive':       true,
        'createdAt':      FieldValue.serverTimestamp(),
      });

      await secondaryAuth.signOut();
    } finally {
      await secondaryApp.delete();
    }
  }

  // ── Update employee ───────────────────────────────────────────────────────
  Future<void> updateEmployee(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  // ── Toggle employee status ────────────────────────────────────────────────
  Future<void> toggleStatus(String uid, String newStatus) async {
    await _db.collection('users').doc(uid).update({
      'status':   newStatus,
      'isActive': newStatus == 'active',
    });
  }

  // ── Update rating ─────────────────────────────────────────────────────────
  Future<void> updateRating(String uid, double rating) async {
    await _db.collection('users').doc(uid).update({'rating': rating});
  }

  // ── Generate next employee code ───────────────────────────────────────────
  Future<String> generateEmployeeCode(String officeId) async {
    final snap = await _db
        .collection('users')
        .where('officeId', isEqualTo: officeId)
        .get();
    final count = snap.docs.length + 1;
    return 'EMP${count.toString().padLeft(3, '0')}';
  }
}
