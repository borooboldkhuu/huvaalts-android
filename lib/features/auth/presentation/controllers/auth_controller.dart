import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import 'auth_providers.dart';

/// App-wide "who is signed in" stream, exposed as an [AsyncNotifier] so
/// screens can `ref.watch(authControllerProvider)` and get `AsyncLoading` /
/// `AsyncData(user)` / `AsyncError` directly, rather than each screen
/// re-deriving it from the raw Supabase stream.
class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final repo = ref.watch(authRepositoryProvider);
    // Keep the notifier in sync with subsequent auth changes.
    final subscription = repo.authStateChanges().listen((user) {
      state = AsyncData(user);
    });
    ref.onDispose(subscription.cancel);
    return repo.currentUser;
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }
}

final AsyncNotifierProvider<AuthController, AppUser?> authControllerProvider =
    AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);
