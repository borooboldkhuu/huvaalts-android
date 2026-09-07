import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Real implementation backed by Supabase Auth (phone OTP + OAuth). Maps
/// Supabase's `User`/`AuthException` into our own [AppUser]/[AppException]
/// types so nothing above this layer imports `supabase_flutter` directly
/// (spec section 32/34 — keep the backend swappable, never leak SDK types
/// into the domain layer).
///
/// NOTE: the `profiles` row (display name, avatar, verification level) is
/// expected to be created/kept in sync by a Supabase trigger on
/// `auth.users` insert/update — see `supabase/migrations/0001_init_schema.sql`.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  AppUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() {
    return _client.auth.onAuthStateChange.map((event) => _mapUser(event.session?.user));
  }

  @override
  Future<void> sendPhoneOtp(String phoneE164) async {
    try {
      await _client.auth.signInWithOtp(phone: phoneE164);
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  @override
  Future<AppUser> verifyPhoneOtp({required String phoneE164, required String otp}) async {
    try {
      final AuthResponse response = await _client.auth.verifyOTP(
        type: OtpType.sms,
        phone: phoneE164,
        token: otp,
      );
      final AppUser? user = _mapUser(response.user);
      if (user == null) {
        throw const UnauthorizedException(message: 'otp_verification_failed');
      }
      return user;
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      // Native Google Sign-In on mobile is completed by the
      // `google_sign_in` flow feeding an ID token into
      // `signInWithIdToken(provider: OAuthProvider.google, ...)`. Kept as a
      // single entry point here so the controller doesn't need to know the
      // platform-specific handshake details.
      throw const ValidationException(
        message: 'google_sign_in_requires_native_flow_wiring',
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  @override
  Future<AppUser> signInWithApple() async {
    try {
      // Same shape as Google — Apple's native `sign_in_with_apple` flow
      // supplies the identity token consumed by `signInWithIdToken`.
      throw const ValidationException(
        message: 'apple_sign_in_requires_native_flow_wiring',
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  AppUser? _mapUser(User? user) {
    if (user == null) return null;
    final Map<String, dynamic> meta = user.userMetadata ?? const {};
    return AppUser(
      id: user.id,
      phone: user.phone,
      email: user.email,
      displayName: meta['display_name'] as String?,
      avatarUrl: meta['avatar_url'] as String?,
      // Verification level lives on `profiles`, not `auth.users` — the
      // profile repository is the source of truth for it. Default to 0
      // (phone-verified, since OTP just succeeded) until the profile loads.
      verificationLevel: 0,
      createdAt: DateTime.parse(user.createdAt),
    );
  }

  AppException _mapAuthException(AuthException e) {
    final int? status = e.statusCode == null ? null : int.tryParse(e.statusCode!);
    return switch (status) {
      401 => const UnauthorizedException(),
      403 => const ForbiddenException(),
      429 => const RateLimitedException(),
      _ => UnknownException(message: e.message, cause: e),
    };
  }
}
