import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/payment_status.dart';
import '../../domain/repositories/payment_repository.dart';

class SupabasePaymentRepository implements PaymentRepository {
  SupabasePaymentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Payment> payFromWallet(String bookingId) async {
    try {
      final dynamic response = await _client.rpc<dynamic>('pay_booking_from_wallet', params: {
        'p_booking_id': bookingId,
      });
      return _fromRow((response as Map).cast<String, dynamic>());
    } on PostgrestException catch (e) {
      throw _mapWalletRpcError(e);
    }
  }

  @override
  Future<Payment?> getForBooking(String bookingId) async {
    try {
      final Map<String, dynamic>? row = await _client
          .from('payments')
          .select()
          .eq('booking_id', bookingId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return _fromRow(row);
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  /// `pay_booking_from_wallet` (`0017_wire_topup_and_wallet_payments.sql`)
  /// raises plain-text exceptions the same way the booking RPCs do —
  /// matched by exact message, same reasoning as
  /// `SupabaseBookingRepository._mapRpcError`. Also handles Postgres's own
  /// `40P01 deadlock_detected` by Postgres error *code* rather than
  /// message text — a concurrent payment/refund pair touching the same
  /// two users' wallets can legitimately deadlock and get rolled back by
  /// Postgres itself (see `lock_wallet_pair` in
  /// `0018_security_and_consistency_hardening.sql` for why this is rare
  /// but not impossible even with canonical lock ordering under retries);
  /// that's a transient failure the caller should be told is safe to
  /// retry, not a generic error.
  AppException _mapWalletRpcError(PostgrestException e) {
    if (e.code == '40P01') {
      return const ConflictException(message: 'transient_conflict_retry');
    }
    return switch (e.message) {
      'auth_required' => const UnauthorizedException(message: 'auth_required'),
      'not_authorized' => const ForbiddenException(message: 'not_authorized'),
      'booking_not_found' || 'wallet_not_found' => const NotFoundException(message: 'not_found'),
      'booking_not_confirmed' => const ConflictException(message: 'booking_not_confirmed'),
      'insufficient_balance' => const ConflictException(message: 'insufficient_balance'),
      _ => UnknownException(message: e.message, cause: e),
    };
  }

  Payment _fromRow(Map<String, dynamic> row) {
    return Payment(
      id: row['id'] as String,
      bookingId: row['booking_id'] as String,
      payerId: row['payer_id'] as String,
      provider: row['provider'] as String? ?? 'mock',
      providerReference: row['provider_reference'] as String?,
      amount: (row['amount'] as num).toDouble(),
      currency: row['currency'] as String? ?? 'MNT',
      status: PaymentStatus.fromId(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
