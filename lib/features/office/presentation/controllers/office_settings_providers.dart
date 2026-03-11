import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/office_settings_model.dart';
import '../../data/office_settings_repository.dart';
import '../../../../features/home/presentation/controllers/home_providers.dart';

// ── Repository ────────────────────────────────────────────────────────────────
final officeSettingsRepositoryProvider = Provider<OfficeSettingsRepository>((
  ref,
) {
  return OfficeSettingsRepository();
});

// ── Watch settings (real-time) ────────────────────────────────────────────────
final officeSettingsProvider = StreamProvider<OfficeSettingsModel>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref
          .watch(officeSettingsRepositoryProvider)
          .watchSettings(user.officeId);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// ── Individual lists — للاستخدام في الـ dropdowns ────────────────────────────

final projectTypesProvider = Provider<List<String>>((ref) {
  final settingsAsync = ref.watch(officeSettingsProvider);
  return settingsAsync.when(
    data: (s) => s.projectTypes,
    loading: () => OfficeSettingsModel.defaults('').projectTypes,
    error: (_, __) => OfficeSettingsModel.defaults('').projectTypes,
  );
});

final disciplinesProvider = Provider<List<String>>((ref) {
  final settingsAsync = ref.watch(officeSettingsProvider);
  return settingsAsync.when(
    data: (s) => s.disciplines,
    loading: () => OfficeSettingsModel.defaults('').disciplines,
    error: (_, __) => OfficeSettingsModel.defaults('').disciplines,
  );
});

final taskCategoriesProvider = Provider<List<String>>((ref) {
  final settingsAsync = ref.watch(officeSettingsProvider);
  return settingsAsync.when(
    data: (s) => s.taskCategories,
    loading: () => OfficeSettingsModel.defaults('').taskCategories,
    error: (_, __) => OfficeSettingsModel.defaults('').taskCategories,
  );
});

final departmentsProvider = Provider<List<String>>((ref) {
  final settingsAsync = ref.watch(officeSettingsProvider);
  return settingsAsync.when(
    data: (s) => s.departments,
    loading: () => OfficeSettingsModel.defaults('').departments,
    error: (_, __) => OfficeSettingsModel.defaults('').departments,
  );
});
