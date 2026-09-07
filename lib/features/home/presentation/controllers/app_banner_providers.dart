import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../shared/entities/app_banner.dart';

/// Active app-open banners, sorted for display (spec: admin-uploaded
/// images shown in a rotating popup the first time Home renders after
/// app open — `app_banner_popup.dart`). Queries `public.app_banners`
/// directly rather than going through `AdminRepository` — that
/// repository's `getAppBanners` is deliberately the admin-only "see
/// everything, active or not" query (`0023_app_banners.sql`'s own doc
/// comment); this one relies on `app_banners_select_active`'s RLS policy
/// doing the `is_active = true` filtering server-side for any signed-in
/// user, admin or not, same as how Home's asset queries never duplicate
/// RLS filtering client-side either.
final FutureProvider<List<AppBanner>> activeAppBannersProvider = FutureProvider<List<AppBanner>>((ref) async {
  final List<Map<String, dynamic>> rows = await ref
      .watch(supabaseClientProvider)
      .from('app_banners')
      .select()
      .order('sort_order', ascending: true);
  return rows.map(AppBanner.fromRow).toList();
});
