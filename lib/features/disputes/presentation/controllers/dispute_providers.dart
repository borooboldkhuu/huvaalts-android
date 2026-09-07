import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/supabase_dispute_repository.dart';
import '../../domain/entities/dispute.dart';
import '../../domain/repositories/dispute_repository.dart';

final Provider<DisputeRepository> disputeRepositoryProvider = Provider<DisputeRepository>((ref) {
  return SupabaseDisputeRepository(ref.watch(supabaseClientProvider));
});

final latestDisputeForBookingProvider =
    FutureProvider.family<Dispute?, String>((ref, bookingId) {
  return ref.watch(disputeRepositoryProvider).getLatestDisputeForBooking(bookingId);
});
