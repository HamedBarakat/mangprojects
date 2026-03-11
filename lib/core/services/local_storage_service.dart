import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const _keyOfficeId = 'selected_office_id';
  static const _keyOfficeName = 'selected_office_name';
  static const _keyOfficeCode = 'selected_office_code';
  static const _keyOfficeLogo = 'selected_office_logo';
  static const _keyOfficeSetup =
      'office_setup_complete'; // true after welcome screen

  final SharedPreferences _prefs;
  LocalStorageService(this._prefs);

  // ── Office ─────────────────────────────────────────────────────────────────

  Future<void> saveOffice({
    required String id,
    required String name,
    required String code,
    String logo = '',
  }) async {
    await _prefs.setString(_keyOfficeId, id);
    await _prefs.setString(_keyOfficeName, name);
    await _prefs.setString(_keyOfficeCode, code);
    await _prefs.setString(_keyOfficeLogo, logo);
  }

  /// Called after the user taps "Get Started" on the welcome screen.
  Future<void> markOfficeSetupComplete() async {
    await _prefs.setBool(_keyOfficeSetup, true);
  }

  String? get officeId => _prefs.getString(_keyOfficeId);
  String? get officeName => _prefs.getString(_keyOfficeName);
  String? get officeCode => _prefs.getString(_keyOfficeCode);
  String? get officeLogo => _prefs.getString(_keyOfficeLogo);

  /// True only after the user has passed the welcome screen at least once.
  bool get isOfficeSetupComplete => _prefs.getBool(_keyOfficeSetup) ?? false;

  Future<void> clearOffice() async {
    await _prefs.remove(_keyOfficeId);
    await _prefs.remove(_keyOfficeName);
    await _prefs.remove(_keyOfficeCode);
    await _prefs.remove(_keyOfficeLogo);
    await _prefs.remove(_keyOfficeSetup);
  }

  // ── Full reset (logout) ────────────────────────────────────────────────────

  Future<void> clearAll() => _prefs.clear();
}
