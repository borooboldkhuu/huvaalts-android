import 'package:dio/dio.dart';

import '../../security/token_manager.dart';

/// Attaches the current Supabase session's access token to every outgoing
/// request, and reacts to 401s by attempting a single silent refresh
/// (actual refresh is delegated to Supabase's own client — this interceptor
/// only decides whether to retry once the token has been rotated).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenManager);

  final TokenManager _tokenManager;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final String? token = await _tokenManager.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 401 handling: the presentation layer listens to the Supabase auth
    // state stream and routes to sign-in on `SIGNED_OUT` / expired-session
    // events. We deliberately do not attempt token refresh here — Supabase
    // owns refresh-token rotation internally.
    handler.next(err);
  }
}
