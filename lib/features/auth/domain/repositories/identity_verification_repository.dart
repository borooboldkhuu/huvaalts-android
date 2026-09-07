/// Status of a DAN (or future e-Mongolia) identity verification attempt.
enum DanVerificationStatus { notStarted, pending, verified, failed, cancelled }

class DanVerificationSession {
  const DanVerificationSession({
    required this.sessionId,
    required this.consentUrl,
    required this.status,
  });

  final String sessionId;

  /// URL the user is redirected to for consent (mock adapter serves a local
  /// placeholder; production adapter must serve the real DAN consent URL —
  /// see spec section 9 architecture diagram).
  final String consentUrl;

  final DanVerificationStatus status;
}

/// Abstraction the app codes against for "verify this user's identity via
/// DAN / e-Mongolia". The presentation layer never talks to
/// [DanAuthService] directly — only through this repository — so the
/// backend verification call chain (Flutter -> Backend Auth Endpoint -> DAN
/// -> consent -> callback -> backend verification -> account link, spec
/// section 9) stays entirely server-side and swappable.
abstract interface class IdentityVerificationRepository {
  Future<DanVerificationSession> startVerification({required String userId});

  Future<DanVerificationStatus> checkStatus({required String sessionId});
}
