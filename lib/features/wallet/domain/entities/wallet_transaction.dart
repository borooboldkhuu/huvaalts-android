import 'package:freezed_annotation/freezed_annotation.dart';

import 'wallet_transaction_type.dart';

part 'wallet_transaction.freezed.dart';
part 'wallet_transaction.g.dart';

/// A single `public.wallet_transactions` ledger entry. `amount` is signed
/// — positive is a credit, negative is a debit (matches the column
/// comment in `0001_init_schema.sql`) — so the UI never needs to infer
/// direction from [type] alone.
@freezed
abstract class WalletTransaction with _$WalletTransaction {
  const factory WalletTransaction({
    required String id,
    required String walletUserId,
    required String? bookingId,
    required WalletTransactionType type,
    required double amount,
    required String? description,
    required DateTime createdAt,
  }) = _WalletTransaction;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      _$WalletTransactionFromJson(json);
}
