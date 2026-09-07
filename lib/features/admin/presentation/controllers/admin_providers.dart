import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../shared/entities/app_banner.dart';
import '../../../disputes/domain/entities/dispute.dart';
import '../../../wallet/domain/entities/payout.dart';
import '../../data/repositories/supabase_admin_repository.dart';
import '../../domain/entities/asset_moderation_summary.dart';
import '../../domain/entities/platform_settings.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/admin_repository.dart';

final Provider<AdminRepository> adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return SupabaseAdminRepository(ref.watch(supabaseClientProvider));
});

/// Drives whether admin navigation (the Profile entry point, the
/// dashboard routes) shows at all. See `AdminRepository.isCurrentUserAdmin`
/// doc — this is a UX convenience, not the authorization boundary.
final FutureProvider<bool> isAdminProvider = FutureProvider<bool>((ref) {
  return ref.watch(adminRepositoryProvider).isCurrentUserAdmin();
});

final FutureProvider<List<AssetModerationSummary>> pendingAssetsProvider =
    FutureProvider<List<AssetModerationSummary>>((ref) {
  return ref.watch(adminRepositoryProvider).getPendingAssets();
});

final FutureProvider<List<Payout>> adminPendingPayoutsProvider = FutureProvider<List<Payout>>((ref) {
  return ref.watch(adminRepositoryProvider).getPendingPayouts();
});

final FutureProvider<List<Dispute>> adminOpenDisputesProvider = FutureProvider<List<Dispute>>((ref) {
  return ref.watch(adminRepositoryProvider).getOpenDisputes();
});

final FutureProvider<List<Report>> adminOpenReportsProvider = FutureProvider<List<Report>>((ref) {
  return ref.watch(adminRepositoryProvider).getOpenReports();
});

final FutureProvider<PlatformSettings> platformSettingsProvider = FutureProvider<PlatformSettings>((ref) {
  return ref.watch(adminRepositoryProvider).getPlatformSettings();
});

final FutureProvider<List<Promotion>> adminPromotionsProvider = FutureProvider<List<Promotion>>((ref) {
  return ref.watch(adminRepositoryProvider).getPromotions();
});

final FutureProvider<List<AppBanner>> adminAppBannersProvider = FutureProvider<List<AppBanner>>((ref) {
  return ref.watch(adminRepositoryProvider).getAppBanners();
});
