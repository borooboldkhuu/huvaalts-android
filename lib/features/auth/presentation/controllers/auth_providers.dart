import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/supabase_auth_repository.dart';
import '../../data/repositories/supabase_identity_details_repository.dart';
import '../../data/repositories/supabase_identity_verification_repository.dart';
import '../../data/services/dan_auth_service.dart';
import '../../data/services/dan_auth_service_factory.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/identity_details_repository.dart';
import '../../domain/repositories/identity_verification_repository.dart';

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

final Provider<DanAuthService> danAuthServiceProvider = Provider<DanAuthService>((ref) {
  final AppConfig config = ref.watch(appConfigProvider);
  final client = ref.watch(supabaseClientProvider);
  return DanAuthServiceFactory.create(config: config, client: client);
});

final Provider<IdentityVerificationRepository> identityVerificationRepositoryProvider =
    Provider<IdentityVerificationRepository>((ref) {
  return SupabaseIdentityVerificationRepository(ref.watch(danAuthServiceProvider));
});

final Provider<IdentityDetailsRepository> identityDetailsRepositoryProvider =
    Provider<IdentityDetailsRepository>((ref) {
  return SupabaseIdentityDetailsRepository(ref.watch(supabaseClientProvider));
});

/// Whether [userId] has completed the post-registration овог/нэр/
/// регистрийн дугаар step — the router's redirect (`app_router.dart`)
/// awaits this (via `.future`) to decide whether to send a signed-in user
/// to `CompleteProfileScreen` before anywhere else in the app. Cached per
/// userId like every other `FutureProvider.family` in this project
/// (`profileProvider`, `walletProvider`, ...); `IdentityDetailsController`
/// invalidates it the moment a submit succeeds so the very next redirect
/// re-check sees the fresh `true` instead of a stale cached `false`.
final identityDetailsCompletedProvider = FutureProvider.family<bool, String>((ref, userId) {
  return ref.watch(identityDetailsRepositoryProvider).exists(userId);
});
