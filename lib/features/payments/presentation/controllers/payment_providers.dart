import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/supabase_payment_repository.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/payment_repository.dart';

final Provider<PaymentRepository> paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return SupabasePaymentRepository(ref.watch(supabaseClientProvider));
});

final paymentForBookingProvider =
    FutureProvider.family<Payment?, String>((ref, bookingId) {
  return ref.watch(paymentRepositoryProvider).getForBooking(bookingId);
});
