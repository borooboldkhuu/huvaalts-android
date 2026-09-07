import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config/app_config.dart';
import '../network/dio_client.dart';
import '../security/token_manager.dart';
import '../storage/local_cache_service.dart';
import '../storage/secure_storage_service.dart';

/// Overridden in `main.dart` (`ProviderScope(overrides: [...])`) once the
/// real [AppConfig] / [SharedPreferences] instances are available, since
/// both require an async bootstrap before `runApp`.
final Provider<AppConfig> appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('appConfigProvider must be overridden in main()');
});

final Provider<SharedPreferences> sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');
});

final Provider<SupabaseClient> supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final Provider<SecureStorageService> secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final Provider<LocalCacheService> localCacheProvider = Provider<LocalCacheService>((ref) {
  return LocalCacheService(ref.watch(sharedPreferencesProvider));
});

final Provider<TokenManager> tokenManagerProvider = Provider<TokenManager>((ref) {
  return TokenManager(
    client: ref.watch(supabaseClientProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final Provider<DioClient> dioClientProvider = Provider<DioClient>((ref) {
  final AppConfig config = ref.watch(appConfigProvider);
  return DioClient(
    baseUrl: config.backendApiBaseUrl,
    tokenManager: ref.watch(tokenManagerProvider),
  );
});

/// Emits the live Supabase auth state so the router can redirect on
/// sign-in/sign-out without every screen polling `Supabase.instance` itself.
final StreamProvider<AuthState> authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});
