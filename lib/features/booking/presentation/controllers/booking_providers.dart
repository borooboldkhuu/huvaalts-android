import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/supabase_booking_repository.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/booking_repository.dart';

final Provider<BookingRepository> bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return SupabaseBookingRepository(ref.watch(supabaseClientProvider));
});

final bookingByIdProvider =
    FutureProvider.family<Booking?, String>((ref, bookingId) {
  return ref.watch(bookingRepositoryProvider).getById(bookingId);
});

final assetBlockedRangesProvider =
    FutureProvider.family<List<(DateTime, DateTime)>, String>((ref, assetId) {
  return ref.watch(bookingRepositoryProvider).getBlockedRanges(assetId);
});

final FutureProvider<List<Booking>> myBookingsAsRenterProvider = FutureProvider<List<Booking>>((ref) {
  return ref.watch(bookingRepositoryProvider).getMyBookingsAsRenter();
});

final FutureProvider<List<Booking>> myBookingsAsOwnerProvider = FutureProvider<List<Booking>>((ref) {
  return ref.watch(bookingRepositoryProvider).getMyBookingsAsOwner();
});
