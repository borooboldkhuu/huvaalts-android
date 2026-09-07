import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps [FlutterSecureStorage] for anything sensitive: auth tokens,
/// biometric flags, DAN verification session references. Never store raw
/// national ID numbers or payment secrets here — those never leave the
/// backend (spec sections 9, 33, 34).
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ??
          const FlutterSecureStorage(
            // `encryptedSharedPreferences` was removed in flutter_secure_storage
            // 11.0.0 (Jetpack Crypto, which it wrapped, was deprecated upstream) —
            // AndroidOptions now always stores through the library's own secure
            // mechanism, so there is nothing to opt into here anymore.
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> deleteAll() => _storage.deleteAll();
}
