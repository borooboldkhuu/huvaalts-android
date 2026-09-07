import '../entities/wallet_topup.dart';

/// The result of starting a top-up — [checkoutUrl] is null exactly when
/// [mock] is true (mock mode never calls wire.mn, so there's no hosted
/// page to open; the caller instead offers the mock-complete action).
class WalletTopupStart {
  const WalletTopupStart({required this.topup, required this.checkoutUrl, required this.mock});

  final WalletTopup topup;
  final String? checkoutUrl;
  final bool mock;
}

abstract interface class WalletTopupRepository {
  /// Calls the `wire-topup` Edge Function's `create` action. [amountMnt]
  /// is whole төгрөг, chosen by the user themselves for their *own*
  /// wallet — there is no trust boundary being crossed by accepting it
  /// from the client here the way there would be for a booking amount
  /// (spec section 34's "never trust the client for money" is about
  /// amounts affecting *someone else's* balance).
  Future<WalletTopupStart> create({required double amountMnt});

  /// `wire-topup`'s `mock_complete` action — only meaningful while
  /// `WIRE_TOPUP_MODE=mock`; the backend refuses this outright otherwise.
  /// See that function's header comment.
  Future<WalletTopup> mockComplete(String topupId);

  /// Plain read against `public.wallet_topups` (allowed by
  /// `wallet_topups_select_own` RLS) — used to poll a top-up's status
  /// after the user returns from the hosted checkout page.
  Future<WalletTopup?> getById(String topupId);
}
