import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/booking.dart';
import 'booking_providers.dart';

class BookingRequestState {
  const BookingRequestState({this.isSubmitting = false});

  final bool isSubmitting;

  BookingRequestState copyWith({bool? isSubmitting}) {
    return BookingRequestState(isSubmitting: isSubmitting ?? this.isSubmitting);
  }
}

/// Owns just the submit action for the booking request screen — date
/// selection and the price preview are local `State` on the screen widget
/// itself (nothing about them is async or needs to survive the screen
/// being popped), matching the split `AssetCreateController` uses for the
/// create-listing form.
class BookingRequestController extends Notifier<BookingRequestState> {
  @override
  BookingRequestState build() => const BookingRequestState();

  Future<Booking> submit({
    required String assetId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      return await ref.read(bookingRepositoryProvider).createBooking(
            assetId: assetId,
            startDate: startDate,
            endDate: endDate,
          );
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}

final NotifierProvider<BookingRequestController, BookingRequestState> bookingRequestControllerProvider =
    NotifierProvider<BookingRequestController, BookingRequestState>(BookingRequestController.new);
