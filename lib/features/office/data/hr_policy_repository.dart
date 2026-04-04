import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/hr_policy_model.dart';

class HRPolicyRepository {
  final _db = FirebaseFirestore.instance;

  DocumentReference _policyDoc(String officeId) => _db
      .collection('offices')
      .doc(officeId)
      .collection('settings')
      .doc('hr_policy');

  Stream<HRPolicyModel> watchPolicy(String officeId) {
    return _policyDoc(officeId).snapshots().map((doc) {
      if (!doc.exists) return HRPolicyModel.defaults();
      return HRPolicyModel.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  Future<HRPolicyModel> getPolicy(String officeId) async {
    final doc = await _policyDoc(officeId).get();
    if (!doc.exists) return HRPolicyModel.defaults();
    return HRPolicyModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  Future<void> savePolicy(String officeId, HRPolicyModel policy) async {
    await _policyDoc(officeId).set(policy.toMap());
  }
}
