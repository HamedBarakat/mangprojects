import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_model.dart';
import '../../data/models/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final auth = FirebaseAuth.instance;
  final repo = ref.watch(userRepositoryProvider);

  return auth.authStateChanges().asyncMap((firebaseUser) async {
    if (firebaseUser == null) return null;
    return await repo.getUser(firebaseUser.uid);
  });
});

// ✅ بنحسب العدد من الـ employeesProvider مباشرة بدل query منفصلة
final activeEmployeesCountProvider = FutureProvider.family<int, String>((
  ref,
  officeId,
) async {
  final repo = ref.watch(userRepositoryProvider);
  return await repo.getActiveEmployeesCount(officeId);
});

// ✅ نسخة real-time من عداد الموظفين — بتشتغل مع الـ Stream
final employeesCountProvider = StreamProvider.family<int, String>((
  ref,
  officeId,
) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('officeId', isEqualTo: officeId)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snap) => snap.docs.length);
});
