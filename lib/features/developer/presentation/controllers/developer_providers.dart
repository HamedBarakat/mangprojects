import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/developer_repository.dart';

final developerRepositoryProvider = Provider<DeveloperRepository>((ref) {
  return DeveloperRepository();
});

final isDeveloperProvider = FutureProvider.family<bool, String>((ref, uid) async {
  return ref.read(developerRepositoryProvider).isDeveloper(uid);
});

// ── Stores dev credentials in memory for the session ─────────────────────────
class DevCredentials {
  final String email;
  final String password;
  DevCredentials(this.email, this.password);
}

final devCredentialsProvider = StateProvider<DevCredentials?>((ref) => null);
