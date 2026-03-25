import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/client_model.dart';
import '../client_repository.dart';
import '../../../home/presentation/controllers/home_providers.dart';

// ── Repository ────────────────────────────────────────────────────────────────
final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return ClientRepository(officeId: user?.officeId ?? '');
});

// ── Watch all clients ─────────────────────────────────────────────────────────
final clientsStreamProvider = StreamProvider<List<ClientModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(clientRepositoryProvider).watchClients();
    },
    loading: () => const Stream.empty(),
    error: (_, _) => const Stream.empty(),
  );
});
