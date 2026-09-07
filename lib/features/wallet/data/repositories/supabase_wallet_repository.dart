import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/payout.dart';
import '../../domain/entities/payout_status.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/entities/wallet_transaction_type.dart';
import '../../domain/repositories/wallet_repository.dart';

class SupabaseWalletRepository implements WalletRepository {
  SupabaseWalletRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Wallet> getWallet(String userId) async {
    try {
      final Map<String, dynamic>? row =
          await _client.from('wallets').select().eq('user_id', userId).maybeSingle();
      if (row == null) {
        // Shouldn't happen — `handle_new_auth_user` creates a wallet row
        // for every user at sign-up — but a missing row is a data
        // problem, not something to paper over with a fake zero wallet.
        throw const NotFoundException(message: 'wallet_not_found');
      }
      return _walletFromRow(row);
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<List<WalletTransaction>> getTransactions(String userId) async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('wallet_transactions')
          .select()
          .eq('wallet_user_id', userId)
          .order('created_at', ascending: false);
      return rows.map(_transactionFromRow).toList();
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<List<Payout>> getPayouts(String userId) async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('payouts')
          .select()
          .eq('user_id', userId)
          .order('requested_at', ascending: false);
      return rows.map(_payoutFromRow).toList();
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<Payout> requestPayout({required double amount}) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const UnauthorizedException(message: 'auth_required');
    }
    try {
      final Map<String, dynamic> row = await _client
          .from('payouts')
          .insert({'user_id': userId, 'amount': amount})
          .select()
          .single();
      return _payoutFromRow(row);
    } on PostgrestException catch (e) {
      throw _mapInsertError(e);
    }
  }

  /// `validate_payout_request` (`0008_wallet_credit_rpc.sql`) raises
  /// plain-text exceptions the same way the booking RPCs do — matched by
  /// exact message rather than by parsing a Postgres error code, same
  /// reasoning as `SupabaseBookingRepository._mapRpcError`.
  AppException _mapInsertError(PostgrestException e) {
    return switch (e.message) {
      'insufficient_available_balance' =>
        const ValidationException(message: 'insufficient_available_balance'),
      'wallet_not_found' => const NotFoundException(message: 'wallet_not_found'),
      _ => UnknownException(message: e.message, cause: e),
    };
  }

  Wallet _walletFromRow(Map<String, dynamic> row) {
    return Wallet(
      userId: row['user_id'] as String,
      availableBalance: (row['available_balance'] as num).toDouble(),
      pendingBalance: (row['pending_balance'] as num).toDouble(),
      totalEarned: (row['total_earned'] as num).toDouble(),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  WalletTransaction _transactionFromRow(Map<String, dynamic> row) {
    return WalletTransaction(
      id: row['id'] as String,
      walletUserId: row['wallet_user_id'] as String,
      bookingId: row['booking_id'] as String?,
      type: WalletTransactionType.fromId(row['type'] as String),
      amount: (row['amount'] as num).toDouble(),
      description: row['description'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Payout _payoutFromRow(Map<String, dynamic> row) {
    return Payout(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      amount: (row['amount'] as num).toDouble(),
      status: PayoutStatus.fromId(row['status'] as String),
      destinationReference: row['destination_reference'] as String?,
      requestedAt: DateTime.parse(row['requested_at'] as String),
      processedAt:
          row['processed_at'] == null ? null : DateTime.parse(row['processed_at'] as String),
    );
  }
}
