import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/local_storage_service.dart';
import '../../data/models/office_model.dart';
import '../../data/office_repository.dart';
import '../../../../core/providers/shared_prefs_provider.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────────

final localStorageProvider = Provider<LocalStorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  return LocalStorageService(prefs!);
});

final officeRepositoryProvider = Provider<OfficeRepository>((ref) {
  return OfficeRepository();
});

// ── Selected office state ──────────────────────────────────────────────────────

class SelectedOfficeNotifier extends Notifier<OfficeModel?> {
  @override
  OfficeModel? build() {
    final s = ref.read(localStorageProvider);
    if (s.officeId != null && s.officeName != null) {
      return OfficeModel(
        id: s.officeId!,
        name: s.officeName!,
        code: s.officeCode ?? '',
        logo: s.officeLogo ?? '',
      );
    }
    return null;
  }

  /// Called when the user enters a valid office code.
  /// Saves office locally but does NOT mark setup complete yet.
  Future<void> setOffice(OfficeModel office) async {
    state = office;
    await ref
        .read(localStorageProvider)
        .saveOffice(
          id: office.id,
          name: office.name,
          code: office.code,
          logo: office.logo,
        );
  }

  /// Called when user taps "Get Started" on the welcome screen.
  Future<void> completeSetup() async {
    await ref.read(localStorageProvider).markOfficeSetupComplete();
  }

  Future<void> clearOffice() async {
    state = null;
    await ref.read(localStorageProvider).clearOffice();
  }
}

final selectedOfficeProvider =
    NotifierProvider<SelectedOfficeNotifier, OfficeModel?>(
      SelectedOfficeNotifier.new,
    );
