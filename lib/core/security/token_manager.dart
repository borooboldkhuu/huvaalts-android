import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/secure_storage_service.dart';

/// Single source of truth for "what access token do outgoing requests use".
///
/// Supabase's client already manages its own session/refresh internally;
/// this class exists so non-Supabase backend calls (Dio, e.g. DAN exchange,
/// payment intents) can read the *current* Supabase access token without
/// every call site reaching into `Supabase.instance` directly, and so the
/// token source is swappable in tests.
class TokenManager {
  TokenManager({SupabaseClient? client, SecureStorageService? secureStorage})
    : _client = client,
      _secureStorage = secureStorage ?? SecureStorageService();

  final SupabaseClient? _client;
  final SecureStorageService _secureStorage;

  static const String _biometricLockKey = 'biometric_lock_enabled';

  Future<String?> readAccessToken() async {
    return _client?.auth.currentSession?.accessToken;
  }

  Future<bool> isBiometricLockEnabled() async {
    final String? value = await _secureStorage.read(_biometricLockKey);
    return value == 'true';
  }

  Future<void> setBiometricLockEnabled(bool enabled) =>
      _secureStorage.write(_biometricLockKey, enabled.toString());

  Future<void> clearSensitiveData() => _secureStorage.deleteAll();
}
