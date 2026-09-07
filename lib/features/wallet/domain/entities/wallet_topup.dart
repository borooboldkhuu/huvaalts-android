import 'package:freezed_annotation/freezed_annotation.dart';

import 'wallet_topup_status.dart';

part 'wallet_topup.freezed.dart';
part 'wallet_topup.g.dart';

/// A `public.wallet_topups` row — created by the `wire-topup` Edge
/// Function (never by the client directly; that table has no client
/// insert/update RLS policy, same posture as `payments` — see
/// `0017_wire_topup_and_wallet_payments.sql`), transitioned to `paid`
/// exclusively by `credit_wallet_for_topup`, called only from
/// `wire-topup-webhook` (real payments) or `wire-topup`'s
/// `mock_complete` action (mock mode only).
@freezed
abstract class WalletTopup with _$WalletTopup {
  const factory WalletTopup({
    required String id,
    required String userId,
    required String provider,
    required String? providerReference,
    required double amount,
    required String currency,
    required WalletTopupStatus status,
    required DateTime createdAt,
  }) = _WalletTopup;

  factory WalletTopup.fromJson(Map<String, dynamic> json) => _$WalletTopupFromJson(json);
}
