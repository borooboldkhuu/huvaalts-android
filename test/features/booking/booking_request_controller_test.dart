import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/booking/domain/entities/booking.dart';
import 'package:huvalts/features/booking/domain/entities/booking_status.dart';
import 'package:huvalts/features/booking/domain/repositories/booking_repository.dart';
import 'package:huvalts/features/booking/presentation/controllers/booking_providers.dart';
import 'package:huvalts/features/booking/presentation/controllers/booking_request_controller.dart';

Booking _booking({BookingStatus status = BookingStatus.pending}) {
  return Booking(
    id: 'booking-1',
    assetId: 'asset-1',
    renterId: 'renter-1',
    ownerId: 'owner-1',
    startDate: DateTime(2026, 8, 20),
    endDate: DateTime(2026, 8, 22),
    status: status,
    rentalAmount: 80000,
    platformFee: 8000,
    deliveryFee: 0,
    totalAmount: 88000,
    commissionPercent: 10,
    cancellationReason: null,
    createdAt: DateTime(2026, 8, 17),
    assetTitle: 'Canon EOS R5',
    assetImagePath: null,
    renterDisplayName: 'Renter',
    ownerDisplayName: 'Owner',
  );
}

class _FakeBookingRepository implements BookingRepository {
  ({String assetId, DateTime start, DateTime end})? lastCreateArgs;
  Object? errorToThrow;

  @override
  Future<Booking> createBooking({
    required String assetId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    lastCreateArgs = (assetId: assetId, start: startDate, end: endDate);
    if (errorToThrow != null) throw errorToThrow!;
    return _booking();
  }

  @override
  Future<Booking> cancelBooking(String bookingId, {String? reason}) async => _booking();

  @override
  Future<Booking> confirmBooking(String bookingId) async => _booking();

  @override
  Future<List<(DateTime, DateTime)>> getBlockedRanges(String assetId) async => const [];

  @override
  Future<Booking?> getById(String bookingId) async => _booking();

  @override
  Future<List<Booking>> getMyBookingsAsOwner() async => const [];

  @override
  Future<List<Booking>> getMyBookingsAsRenter() async => const [];

  @override
  Future<Booking> rejectBooking(String bookingId, {String? reason}) async => _booking();
}

void main() {
  test('submit forwards asset id and dates, returns the created booking', () async {
    final fake = _FakeBookingRepository();
    final container = ProviderContainer(
      overrides: [bookingRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(bookingRequestControllerProvider.notifier);
    final start = DateTime(2026, 8, 20);
    final end = DateTime(2026, 8, 22);

    final booking = await controller.submit(assetId: 'asset-1', startDate: start, endDate: end);

    expect(booking.id, 'booking-1');
    expect(fake.lastCreateArgs?.assetId, 'asset-1');
    expect(fake.lastCreateArgs?.start, start);
    expect(fake.lastCreateArgs?.end, end);
    expect(controller.state.isSubmitting, isFalse, reason: 'must reset after completing');
  });

  test('isSubmitting is true only while the call is in flight', () async {
    final fake = _FakeBookingRepository();
    final container = ProviderContainer(
      overrides: [bookingRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(bookingRequestControllerProvider.notifier);
    expect(controller.state.isSubmitting, isFalse);

    final future = controller.submit(
      assetId: 'asset-1',
      startDate: DateTime(2026, 8, 20),
      endDate: DateTime(2026, 8, 22),
    );
    expect(controller.state.isSubmitting, isTrue);

    await future;
    expect(controller.state.isSubmitting, isFalse);
  });

  test('rethrows on failure and still resets isSubmitting', () async {
    final fake = _FakeBookingRepository()..errorToThrow = Exception('dates_unavailable');
    final container = ProviderContainer(
      overrides: [bookingRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(bookingRequestControllerProvider.notifier);

    await expectLater(
      controller.submit(
        assetId: 'asset-1',
        startDate: DateTime(2026, 8, 20),
        endDate: DateTime(2026, 8, 22),
      ),
      throwsException,
    );
    expect(controller.state.isSubmitting, isFalse);
  });
}
