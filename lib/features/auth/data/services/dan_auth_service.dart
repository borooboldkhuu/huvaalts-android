import '../../domain/repositories/identity_verification_repository.dart';

/// Backend-facing service that talks to the DAN authentication endpoint.
///
/// CRITICAL: no implementation of this interface may run entirely
/// on-device. Every method here must, in production, call a *backend*
/// endpoint (Supabase Edge Function) that itself holds the DAN client
/// secret/API credentials — those credentials must never be embedded in
/// the Flutter binary (spec section 9). This class is the thin client-side
/// half of that flow: it asks the backend to start/poll a DAN session and
/// returns the result; it never sees a DAN client secret.
///
/// Two implementations exist:
///  - [MockDanAuthAdapter]: fully functional, fully offline, isolated, safe
///    to run with no real DAN access and no deployed backend, so the rest
///    of the app (booking, verification badges, etc.) can be built and
///    demoed today.
///  - `EdgeFunctionDanAuthAdapter` (`edge_function_dan_auth_adapter.dart`):
///    the real client — always calls the `dan-verify` Supabase Edge
///    Function. Whether that function answers with mock data or real DAN
///    data is a *server-side* config flip (`DAN_AUTH_MODE` Edge Function
///    secret), not a Flutter code change — no documented DAN
///    endpoint/credentials were available when this was written, so the
///    function's production branches currently return `501` until they
///    are filled in. See [DanAuthServiceFactory] for how the swap happens
///    without touching call sites.
abstract interface class DanAuthService {
  Future<DanVerificationSession> startSession({required String userId});

  Future<DanVerificationStatus> pollStatus({required String sessionId});
}
