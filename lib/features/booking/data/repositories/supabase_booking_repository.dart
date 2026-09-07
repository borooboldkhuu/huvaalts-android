import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/booking_status.dart';
import '../../domain/repositories/booking_repository.dart';

class SupabaseBookingRepository implements BookingRepository {
  SupabaseBookingRepository(this._client);

  final SupabaseClient _client;

  static const String _cardsView = 'booking_cards';

  @override
  Future<Booking> createBooking({
    required String assetId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final dynamic response = await _client.rpc<dynamic>('create_booking', params: {
        'p_asset_id': assetId,
        'p_start_date': _dateOnly(startDate),
        'p_end_date': _dateOnly(endDate),
      });
      final String id = (response as Map<String, dynamic>)['id'] as String;
      // `create_booking` returns a bare `bookings` row, not the enriched
      // `booking_cards` shape (asset title/photo, counterparty names) —
      // re-fetch through the same view every other read uses so there's
      // exactly one place (`_fromRow`) that knows how to build a [Booking].
      final Booking? enriched = await getById(id);
      if (enriched == null) {
        throw const UnknownException(message: 'booking_created_but_not_found');
      }
      return enriched;
    } on PostgrestException catch (e) {
      throw _mapRpcError(e);
    }
  }

  @override
  Future<Booking?> getById(String bookingId) async {
    try {
      final Map<String, dynamic>? row =
          await _client.from(_cardsView).select().eq('id', bookingId).maybeSingle();
      if (row == null) return null;
      return _fromRow(row);
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<List<Booking>> getMyBookingsAsRenter() async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) throw const UnauthorizedException(message: 'not_signed_in');
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from(_cardsView)
          .select()
          .eq('renter_id', userId)
          .order('created_at', ascending: false);
      return rows.map(_fromRow).toList();
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<List<Booking>> getMyBookingsAsOwner() async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) throw const UnauthorizedException(message: 'not_signed_in');
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from(_cardsView)
          .select()
          .eq('owner_id', userId)
          .order('created_at', ascending: false);
      return rows.map(_fromRow).toList();
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<List<(DateTime start, DateTime end)>> getBlockedRanges(String assetId) async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('asset_booked_ranges')
          .select('start_date, end_date')
          .eq('asset_id', assetId);
      return rows
          .map(
            (r) => (
              DateTime.parse(r['start_date'] as String),
              DateTime.parse(r['end_date'] as String),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<Booking> confirmBooking(String bookingId) => _callStatusRpc('confirm_booking', bookingId);

  @override
  Future<Booking> rejectBooking(String bookingId, {String? reason}) =>
      _callStatusRpc('reject_booking', bookingId, reason: reason);

  @override
  Future<Booking> cancelBooking(String bookingId, {String? reason}) =>
      _callStatusRpc('cancel_booking', bookingId, reason: reason);

  Future<Booking> _callStatusRpc(String function, String bookingId, {String? reason}) async {
    try {
      final Map<String, dynamic> params = {'p_booking_id': bookingId};
      if (reason != null) params['p_reason'] = reason;
      await _client.rpc<dynamic>(function, params: params);
      final Booking? updated = await getById(bookingId);
      if (updated == null) {
        throw const UnknownException(message: 'booking_updated_but_not_found');
      }
      return updated;
    } on PostgrestException catch (e) {
      throw _mapRpcError(e);
    }
  }

  /// Maps the plain-text `RAISE EXCEPTION '<code>'` messages from
  /// `0006_booking_rpc.sql`'s functions to the matching [AppException]
  /// subtype, so the UI can show something more specific than "something
  /// went wrong" for the cases a renter/owner can actually do something
  /// about (picking different dates, not booking their own listing).
  AppException _mapRpcError(PostgrestException e) {
    return switch (e.message) {
      'auth_required' => const UnauthorizedException(message: 'auth_required'),
      'not_authorized' => const ForbiddenException(message: 'not_authorized'),
      'asset_not_found' || 'booking_not_found' => const NotFoundException(message: 'not_found'),
      'dates_unavailable' => const ConflictException(message: 'dates_unavailable'),
      'invalid_status_transition' => const ConflictException(message: 'invalid_status_transition'),
      'cannot_cancel_paid_booking' =>
        const ConflictException(message: 'cannot_cancel_paid_booking'),
      'invalid_date_range' ||
      'cannot_book_own_asset' ||
      'asset_missing_daily_price' =>
        ValidationException(message: e.message),
      _ => UnknownException(message: e.message, cause: e),
    };
  }

  Booking _fromRow(Map<String, dynamic> row) {
    return Booking(
      id: row['id'] as String,
      assetId: row['asset_id'] as String,
      renterId: row['renter_id'] as String,
      ownerId: row['owner_id'] as String,
      startDate: DateTime.parse(row['start_date'] as String),
      endDate: DateTime.parse(row['end_date'] as String),
      status: BookingStatus.fromId(row['status'] as String),
      rentalAmount: (row['rental_amount'] as num).toDouble(),
      platformFee: (row['platform_fee'] as num).toDouble(),
      deliveryFee: (row['delivery_fee'] as num?)?.toDouble() ?? 0,
      totalAmount: (row['total_amount'] as num).toDouble(),
      commissionPercent: (row['commission_percent'] as num).toDouble(),
      cancellationReason: row['cancellation_reason'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      assetTitle: row['asset_title'] as String?,
      assetImagePath: row['asset_image_path'] as String?,
      renterDisplayName: row['renter_display_name'] as String?,
      ownerDisplayName: row['owner_display_name'] as String?,
    );
  }

  String _dateOnly(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
