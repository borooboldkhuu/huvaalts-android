import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/supabase_profile_repository.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';

final Provider<ProfileRepository> profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SupabaseProfileRepository(ref.watch(supabaseClientProvider));
});

/// Loads the signed-in user's own public profile. Parameterized by userId
/// so the same provider family can later back "view someone else's
/// profile" screens.
final profileProvider =
    FutureProvider.family<Profile, String>((ref, userId) {
  return ref.watch(profileRepositoryProvider).getProfile(userId);
});
