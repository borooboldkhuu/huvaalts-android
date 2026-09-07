import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/wallet_topup.dart';
import '../../domain/entities/wallet_topup_status.dart';
import '../../domain/repositories/wallet_topup_repository.dart';

class SupabaseWalletTopupRepository implements WalletTopupRepository {
  SupabaseWalletTopupRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<WalletTopupStart> create({required double amountMnt}) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'wire-topup',
        body: {'action': 'create', 'amount_mnt': amountMnt},
      );
      final Map<String, dynamic> data = (response.data as Map).cast<String, dynamic>();
      return WalletTopupStart(
        topup: _fromRow((data['topup'] as Map).cast<String, dynamic>()),
        checkoutUrl: data['checkout_url'] as String?,
        mock: data['mock'] as bool? ?? false,
      );
    } on FunctionException catch (e) {
      throw _mapFunctionError(e);
    }
  }

  @override
  Future<WalletTopup> mockComplete(String topupId) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'wire-topup',
        body: {'action': 'mock_complete', 'topup_id': topupId},
      );
      final Map<String, dynamic> data = (response.data as Map).cast<String, dynamic>();
      return _fromRow((data['topup'] as Map).cast<String, dynamic>());
    } on FunctionException catch (e) {
      throw _mapFunctionError(e);
    }
  }

  @override
  Future<WalletTopup?> getById(String topupId) async {
    try {
      final Map<String, dynamic>? row =
          await _client.from('wallet_topups').select().eq('id', topupId).maybeSingle();
      if (row == null) return null;
      return _fromRow(row);
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  /// Same status-based mapping reasoning as
  /// `SupabasePaymentRepository._mapFunctionError` — Edge Functions
  /// signal outcomes via HTTP status, not Postgres-style named
  /// exceptions.
  AppException _mapFunctionError(FunctionException e) {
    return switch (e.status) {
      401 => const UnauthorizedException(message: 'auth_required'),
      403 => const ForbiddenException(message: 'not_authorized'),
      404 => const NotFoundException(message: 'not_found'),
      409 => const ConflictException(message: 'topup_conflict'),
      400 || 422 => const ValidationException(message: 'invalid_topup_request'),
      500 => const UnknownException(message: 'wire_not_configured'),
      502 => const NetworkException(message: 'wire_request_failed'),
      _ => UnknownException(message: 'wallet_topup_function_error', cause: e),
    };
  }

  WalletTopup _fromRow(Map<String, dynamic> row) {
    return WalletTopup(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      provider: row['provider'] as String? ?? 'wire',
      providerReference: row['provider_reference'] as String?,
      amount: (row['amount'] as num).toDouble(),
      currency: row['currency'] as String? ?? 'MNT',
      status: WalletTopupStatus.fromId(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
