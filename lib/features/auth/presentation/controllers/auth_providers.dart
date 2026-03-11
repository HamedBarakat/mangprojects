import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

/// Stream Provider لمراقبة حالة تسجيل الدخول
final authStateProvider = StreamProvider<User?>((ref) {
  final repo = ref.read(authRepositoryProvider);
  return repo.authStateChanges();
});

/// Provider لجلب بيانات المستخدم من Firestore
final userDataProvider =
FutureProvider.family<bool, String>((ref, uid) async {
  final repo = ref.read(authRepositoryProvider);
  return await repo.isUserActivated(uid);
});