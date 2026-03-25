import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../data/auth_repository.dart';

/// FirebaseAuth Provider
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final firebaseAuth = ref.read(firebaseAuthProvider);
  return AuthRepository(firebaseAuth);
});

/// Android manual auth state — stores uid after REST API login
final androidAuthUidProvider = StateProvider<String?>((ref) => null);

/// Stream Provider لمراقبة حالة تسجيل الدخول
final authStateProvider = StreamProvider<User?>((ref) {
  final repo = ref.read(authRepositoryProvider);
  return repo.authStateChanges();
});

/// Combined auth uid — works for both Firebase SDK and Android REST login
final effectiveUidProvider = Provider<String?>((ref) {
  final authAsync = ref.watch(authStateProvider);
  final androidUid = ref.watch(androidAuthUidProvider);

  final firebaseUid = authAsync.whenOrNull(data: (user) => user?.uid);

  if (firebaseUid != null) return firebaseUid;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return androidUid;
  }
  return null;
});

/// Provider لجلب بيانات المستخدم من Firestore
final userDataProvider =
    FutureProvider.family<bool, String>((ref, uid) async {
  final repo = ref.read(authRepositoryProvider);
  return await repo.isUserActivated(uid);
});
