import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a [Stream] (e.g. Supabase auth state changes) into a
/// [Listenable] so [GoRouter]'s `refreshListenable` re-evaluates redirects
/// whenever auth state changes, without polling.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
