import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet.freezed.dart';
part 'wallet.g.dart';

/// A `public.wallets` row (spec sections 20, 33) — one per user, created
/// automatically by the `handle_new_auth_user` trigger on sign-up, so
/// every signed-in user has one by the time this is ever read. Balances
/// are mutated exclusively by backend code (`credit_wallet_for_payment`,
/// future payout-processing) — the client only ever reads this shape
/// (`wallets_select_own` RLS; no client write policy exists at all).
@freezed
abstract class Wallet with _$Wallet {
  const factory Wallet({
    required String userId,

    /// Spendable / withdrawable right now.
    required double availableBalance,

    /// Earned but not yet released. `credit_wallet_for_payment` still
    /// credits everything here first — as of Phase 9, it moves to
    /// [availableBalance] automatically once the booking's *return*
    /// condition report is confirmed by both parties
    /// (`advance_booking_on_condition_report`,
    /// `supabase/migrations/0010_condition_reports_reviews_disputes.sql`).
    /// Before that confirmation happens, a completed rental's payout still
    /// sits here — see that trigger's header comment.
    required double pendingBalance,

    /// Lifetime total, regardless of current available/pending split.
    required double totalEarned,
    required DateTime updatedAt,
  }) = _Wallet;

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);
}
