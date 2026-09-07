import '../entities/profile.dart';

abstract interface class ProfileRepository {
  Future<Profile> getProfile(String userId);

  Future<Profile> updateDisplayName({required String userId, required String displayName});
}
