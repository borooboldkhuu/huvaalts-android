import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_providers.dart';

class BookingRefundState {
  const BookingRefundState({this.isSubmitting = false});

  final bool isSubmitting;
}

/// Drives the admin "Refund renter" action
/// (`admin_refund_booking_payment`,
/// `supabase/migrations/0018_security_and_consistency_hardening.sql`) —
/// deliberately separate from [DisputeResolutionController]: refunding is
/// its own explicit, irreversible action an admin takes on a booking, not
/// an automatic side effect of resolving a dispute (plenty of disputes
/// resolve in the owner's favor and should never trigger a refund).
class BookingRefundController extends Notifier<BookingRefundState> {
  @override
  BookingRefundState build() => const BookingRefundState();

  Future<void> refund({required String bookingId, String? reason}) async {
    state = const BookingRefundState(isSubmitting: true);
    try {
      await ref.read(adminRepositoryProvider).refundBookingPayment(bookingId: bookingId, reason: reason);
    } finally {
      state = const BookingRefundState(isSubmitting: false);
    }
  }
}

final NotifierProvider<BookingRefundController, BookingRefundState> bookingRefundControllerProvider =
    NotifierProvider<BookingRefundController, BookingRefundState>(BookingRefundController.new);
