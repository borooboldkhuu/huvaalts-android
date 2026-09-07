import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/supabase_listing_assistant_repository.dart';
import '../../domain/repositories/listing_assistant_repository.dart';

final Provider<ListingAssistantRepository> listingAssistantRepositoryProvider =
    Provider<ListingAssistantRepository>((ref) {
  return SupabaseListingAssistantRepository(ref.watch(supabaseClientProvider));
});
