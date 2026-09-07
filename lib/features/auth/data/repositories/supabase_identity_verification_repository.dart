import '../../domain/repositories/identity_verification_repository.dart';
import '../services/dan_auth_service.dart';

/// Thin adapter from [DanAuthService] to the domain-facing
/// [IdentityVerificationRepository]. Works unchanged whether the injected
/// [DanAuthService] is [MockDanAuthAdapter] (fully offline, no backend
/// call) or [EdgeFunctionDanAuthAdapter] (talks to the real `dan-verify`
/// Edge Function, which is itself either running in its own mock mode or
/// wired to real DAN — see `DanAuthServiceFactory`).
///
/// Note: despite the similarly-named file this replaced
/// (`mock_identity_verification_repository.dart`), this class is not
/// itself a mock — it never fakes anything; all faking lives behind the
/// [DanAuthService] interface it's handed.
class SupabaseIdentityVerificationRepository implements IdentityVerificationRepository {
  SupabaseIdentityVerificationRepository(this._danAuthService);

  final DanAuthService _danAuthService;

  @override
  Future<DanVerificationSession> startVerification({required String userId}) {
    return _danAuthService.startSession(userId: userId);
  }

  @override
  Future<DanVerificationStatus> checkStatus({required String sessionId}) {
    return _danAuthService.pollStatus(sessionId: sessionId);
  }
}
