import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_model.dart';
import '../../data/chat_repository.dart';
import '../../../../features/home/presentation/controllers/home_providers.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (_) => ChatRepository(),
);

// ── Chat doc for a given project ──────────────────────────────────────────────
final chatForProjectProvider =
    StreamProvider.family<ChatModel?, String>((ref, projectId) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const Stream.empty();
  return ref
      .read(chatRepositoryProvider)
      .watchChatForProject(projectId, user.officeId);
});

// ── All messages for a chat ───────────────────────────────────────────────────
final chatMessagesProvider =
    StreamProvider.family<List<ChatMessageModel>, String>((ref, chatId) {
  return ref.read(chatRepositoryProvider).watchMessages(chatId);
});
