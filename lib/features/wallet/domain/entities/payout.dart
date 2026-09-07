import 'package:freezed_annotation/freezed_annotation.dart';

import 'payout_status.dart';

part 'payout.freezed.dart';
part 'payout.g.dart';

/// A `public.payouts` row — a user-initiated request to withdraw from
/// their wallet's [availableBalance]. Unlike `payments`, the client *is*
/// allowed to insert this directly (`payouts_insert_own` RLS) since
/// creating the request doesn't move any money — a
/// `validate_payout_request` trigger (`0008_wallet_credit_rpc.sql`)
/// still rejects it server-side if the amount exceeds what's actually
/// available, so the client is never trusted to self-report a valid
/// amount either.
@freezed
abstract class Payout with _$Payout {
  const factory Payout({
    required String id,
    required String userId,
    required double amount,
    required PayoutStatus status,
    required String? destinationReference,
    required DateTime requestedAt,
    required DateTime? processedAt,
  }) = _Payout;

  factory Payout.fromJson(Map<String, dynamic> json) => _$PayoutFromJson(json);
}
