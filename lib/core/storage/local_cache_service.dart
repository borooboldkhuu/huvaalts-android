import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive local cache/preferences: theme mode, locale, first-launch
/// flag, last-seen onboarding step. Anything sensitive belongs in
/// [SecureStorageService] instead.
class LocalCacheService {
  LocalCacheService(this._prefs);

  final SharedPreferences _prefs;

  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLocale = 'locale';

  bool get onboardingComplete => _prefs.getBool(keyOnboardingComplete) ?? false;

  Future<void> setOnboardingComplete(bool value) =>
      _prefs.setBool(keyOnboardingComplete, value);

  String? get themeMode => _prefs.getString(keyThemeMode);

  Future<void> setThemeMode(String value) => _prefs.setString(keyThemeMode, value);

  String? get locale => _prefs.getString(keyLocale);

  Future<void> setLocale(String value) => _prefs.setString(keyLocale, value);
}
