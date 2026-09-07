import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_config.dart';
import 'dan_auth_service.dart';
import 'edge_function_dan_auth_adapter.dart';
import 'mock_dan_auth_adapter.dart';

/// Chooses the [DanAuthService] implementation. This is the single place
/// that decides which adapter runs — call sites (repositories,
/// controllers) only ever depend on the [DanAuthService] interface, so
/// this is the only file that changes as the app moves from local dev to
/// a deployed backend to real DAN (spec section 9/51).
///
/// Two adapters, not three: there's no separate "mock" vs "production"
/// class on the client. [MockDanAuthAdapter] is a fully offline local
/// fake — no network call at all, so widget/unit tests and demos work
/// with no backend deployed, but it never persists anything to
/// `identity_verifications`/`profiles`. [EdgeFunctionDanAuthAdapter] is
/// the one real client — it always calls the `dan-verify` Edge Function,
/// and that function's own `DAN_AUTH_MODE` secret (not anything client
/// side) decides whether the request is answered by that function's mock
/// branch or, once credentials/docs exist, real DAN. Picking
/// [EdgeFunctionDanAuthAdapter] here is therefore *also* "the production
/// adapter" — going live needs a backend config change, not a Flutter
/// code change.
class DanAuthServiceFactory {
  const DanAuthServiceFactory._();

  static DanAuthService create({required AppConfig config, required SupabaseClient client}) {
    if (config.isDanMock) {
      return MockDanAuthAdapter();
    }
    return EdgeFunctionDanAuthAdapter(client);
  }
}
