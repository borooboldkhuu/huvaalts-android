import 'package:freezed_annotation/freezed_annotation.dart';

import 'booking_status.dart';

part 'booking.freezed.dart';
part 'booking.g.dart';

/// Read-optimized projection backing booking list/detail screens (spec
/// sections 15, 17, 18), sourced from the `public.booking_cards` view
/// (see `supabase/migrations/0006_booking_rpc.sql`) rather than
/// `public.bookings` directly, so the asset's title/photo and both
/// participants' display names come back in one round trip instead of
/// N+1 lookups per booking.
@freezed
abstract class Booking with _$Booking {
  const factory Booking({
    required String id,
    required String assetId,
    required String renterId,
    required String ownerId,
    required DateTime startDate,
    required DateTime endDate,
    required BookingStatus status,
    required double rentalAmount,
    required double platformFee,
    required double deliveryFee,
    required double totalAmount,
    required double commissionPercent,
    required String? cancellationReason,
    required DateTime createdAt,
    required String? assetTitle,
    required String? assetImagePath,
    required String? renterDisplayName,
    required String? ownerDisplayName,
  }) = _Booking;

  factory Booking.fromJson(Map<String, dynamic> json) => _$BookingFromJson(json);
}

/// Convenience view-model helpers — kept on an extension (not the freezed
/// class body) since freezed classes can't have their own instance
/// methods declared inline alongside `const factory`.
extension BookingViewHelpers on Booking {
  bool isRenter(String userId) => renterId == userId;
  bool isOwner(String userId) => ownerId == userId;

  int get nights {
    final int n = endDate.difference(startDate).inDays;
    return n < 1 ? 1 : n;
  }
}
