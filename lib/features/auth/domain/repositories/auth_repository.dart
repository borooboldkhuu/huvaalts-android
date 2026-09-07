import '../entities/app_user.dart';

/// Abstraction over "how a user authenticates". The presentation layer only
/// ever talks to this interface — never to `supabase_flutter` directly —
/// so the backend auth provider is swappable and controllers are testable
/// with a fake implementation.
abstract interface class AuthRepository {
  AppUser? get currentUser;

  Stream<AppUser?> authStateChanges();

  /// Sends a one-time code to [phoneE164] (e.g. `+97699112233`).
  Future<void> sendPhoneOtp(String phoneE164);

  Future<AppUser> verifyPhoneOtp({required String phoneE164, required String otp});

  Future<AppUser> signInWithGoogle();

  Future<AppUser> signInWithApple();

  Future<void> signOut();
}
