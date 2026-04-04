import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'models/employee_model.dart';

class EmployeeRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Stream<List<EmployeeModel>> watchEmployees(String officeId) {
    return _db
        .collection('users')
        .where('officeId', isEqualTo: officeId)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => EmployeeModel.fromFirestore(doc))
              .where((e) => e.role != 'client')
              .toList(),
        );
  }

  Stream<List<EmployeeModel>> watchClientAccounts(String officeId) {
    return _db
        .collection('users')
        .where('officeId', isEqualTo: officeId)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => EmployeeModel.fromFirestore(doc))
              .where((e) => e.role == 'client')
              .toList(),
        );
  }

  Future<EmployeeModel?> getEmployee(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return EmployeeModel.fromFirestore(doc);
  }

  Future<String?> addEmployee({
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
    String? linkedClientId,
  }) async {
    final appName = 'secondaryApp_${DateTime.now().millisecondsSinceEpoch}';
    final secondaryApp = await Firebase.initializeApp(
      name: appName,
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
        'uid': uid,
        'officeId': officeId,
        'employeeCode': employeeCode,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'role': role,
        'adminFlag': adminFlag,
        'department': department,
        'jobTitle': jobTitle,
        'specialization': specialization,
        'graduationYear': graduationYear,
        'joinDate': Timestamp.fromDate(joinDate),
        'status': 'active',
        'rating': 0.0,
        'notes': notes,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        if (linkedClientId != null && linkedClientId.isNotEmpty)
          'linkedClientId': linkedClientId,
      });

      await secondaryAuth.signOut();
      return uid;
    } finally {
      await secondaryApp.delete();
    }
  }

  Future<void> updateEmployee(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  Future<void> toggleStatus(String uid, String newStatus) async {
    await _db.collection('users').doc(uid).update({
      'status': newStatus,
      'isActive': newStatus == 'active',
    });
  }

  Future<void> updateRating(String uid, double rating) async {
    await _db.collection('users').doc(uid).update({'rating': rating});
  }

  Future<String> generateEmployeeCode(String officeId) async {
    final snap = await _db
        .collection('users')
        .where('officeId', isEqualTo: officeId)
        .get();

    int maxNum = 0;
    for (final doc in snap.docs) {
      final code = doc.data()['employeeCode'] as String? ?? '';
      if (code.startsWith('EMP')) {
        final num = int.tryParse(code.substring(3)) ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }
    return 'EMP${(maxNum + 1).toString().padLeft(3, '0')}';
  }
}
