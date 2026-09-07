import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/repositories/identity_verification_repository.dart';
import 'dan_auth_service.dart';

/// The real client-side half of the DAN flow — calls the `dan-verify`
/// Edge Function (see `supabase/functions/dan-verify/index.ts`) for both
/// `start` and `status`, never a DAN endpoint directly, and never sees a
/// DAN client secret.
///
/// This is "the production adapter": going live with real DAN needs zero
/// changes here. Whether a given deployment is faking DAN or actually
/// talking to it is decided entirely server-side by that function's own
/// `DAN_AUTH_MODE` secret — this class just relays whatever it gets back,
/// the same way [DanAuthServiceFactory] picks it for anything that isn't
/// explicitly the fully-offline [MockDanAuthAdapter].
///
/// [startSession]'s `userId` parameter is intentionally unused: the
/// backend identifies the caller from the Bearer token on the request
/// (`supabase.auth.getUser`), never from anything the client asserts —
/// it's kept on the interface only so [MockDanAuthAdapter], which has no
/// backend to ask, still has something to build a fake session id from.
class EdgeFunctionDanAuthAdapter implements DanAuthService {
  EdgeFunctionDanAuthAdapter(this._client);

  final SupabaseClient _client;

  @override
  Future<DanVerificationSession> startSession({required String userId}) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'dan-verify',
        body: {'action': 'start'},
      );
      final Map<String, dynamic> data = (response.data as Map).cast<String, dynamic>();
      return DanVerificationSession(
        sessionId: data['session_id'] as String,
        consentUrl: data['consent_url'] as String,
        status: _statusFromId(data['status'] as String?),
      );
    } on FunctionException catch (e) {
      throw _mapFunctionError(e);
    }
  }

  @override
  Future<DanVerificationStatus> pollStatus({required String sessionId}) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'dan-verify',
        body: {'action': 'status', 'session_id': sessionId},
      );
      final Map<String, dynamic> data = (response.data as Map).cast<String, dynamic>();
      return _statusFromId(data['status'] as String?);
    } on FunctionException catch (e) {
      throw _mapFunctionError(e);
    }
  }

  DanVerificationStatus _statusFromId(String? id) {
    return switch (id) {
      'verified' => DanVerificationStatus.verified,
      'failed' => DanVerificationStatus.failed,
      'cancelled' => DanVerificationStatus.cancelled,
      _ => DanVerificationStatus.pending,
    };
  }

  /// Same status-code-based approach as `SupabasePaymentRepository` —
  /// this function doesn't raise Postgres-style named exceptions, so the
  /// HTTP status this project's own function code chose to return is the
  /// only reliable signal.
  AppException _mapFunctionError(FunctionException e) {
    return switch (e.status) {
      401 => const UnauthorizedException(message: 'auth_required'),
      400 => const ValidationException(message: 'invalid_verification_request'),
      501 => const ValidationException(message: 'dan_production_adapter_not_implemented'),
      _ => UnknownException(message: 'dan_function_error', cause: e),
    };
  }
}
