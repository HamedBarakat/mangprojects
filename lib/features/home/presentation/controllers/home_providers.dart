import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_model.dart';
import '../../data/models/user_repository.dart';
import '../../../../features/auth/data/auth_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final currentUserProvider = StreamProvider<UserModel?>((ref) async* {
  final repo = ref.watch(userRepositoryProvider);

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await for (final firebaseUser in FirebaseAuth.instance.authStateChanges()) {
      final uid = firebaseUser?.uid ?? AuthRepository.androidUid;
      if (kDebugMode) debugPrint('[currentUserProvider] android auth uid=$uid');
      if (uid == null) {
        yield null;
        continue;
      }
      final user = await repo.getUser(uid);
      if (kDebugMode) debugPrint('[currentUserProvider] android loaded user=${user?.uid} role=${user?.role}');
      yield user;
    }
    return;
  }

  await for (final firebaseUser in FirebaseAuth.instance.authStateChanges()) {
    final uid = firebaseUser?.uid;
    if (kDebugMode) debugPrint('[currentUserProvider] web auth uid=$uid');
    if (uid == null) {
      yield null;
      continue;
    }
    final user = await repo.getUser(uid);
    if (kDebugMode) debugPrint('[currentUserProvider] web loaded user=${user?.uid} role=${user?.role}');
    yield user;
  }
});

final activeEmployeesCountProvider = FutureProvider.family<int, String>((ref, officeId) async {
  final repo = ref.watch(userRepositoryProvider);
  return await repo.getActiveEmployeesCount(officeId);
});

final employeesCountProvider = StreamProvider.family<int, String>((ref, officeId) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('officeId', isEqualTo: officeId)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snap) => snap.docs.length);
});
