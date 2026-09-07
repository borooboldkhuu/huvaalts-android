import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../features/admin/presentation/screens/admin_asset_moderation_screen.dart';
import '../../features/admin/presentation/screens/admin_banner_form_screen.dart';
import '../../features/admin/presentation/screens/admin_banners_screen.dart';
import '../../features/admin/presentation/screens/admin_commission_settings_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_dispute_queue_screen.dart';
import '../../features/admin/presentation/screens/admin_payout_queue_screen.dart';
import '../../features/admin/presentation/screens/admin_promotion_form_screen.dart';
import '../../features/admin/presentation/screens/admin_promotions_screen.dart';
import '../../features/admin/presentation/screens/admin_report_queue_screen.dart';
import '../../features/admin/domain/entities/promotion.dart';
import '../../shared/entities/app_banner.dart';
import '../../features/assets/domain/entities/asset_search_filters.dart';
import '../../features/assets/presentation/screens/asset_create_screen.dart';
import '../../features/assets/presentation/screens/asset_detail_screen.dart';
import '../../features/assets/presentation/screens/my_assets_screen.dart';
import '../../features/booking/domain/entities/condition_report_stage.dart';
import '../../features/booking/presentation/screens/booking_detail_screen.dart';
import '../../features/booking/presentation/screens/booking_request_screen.dart';
import '../../features/booking/presentation/screens/condition_report_screen.dart';
import '../../features/booking/presentation/screens/my_bookings_screen.dart';
import '../../features/auth/presentation/controllers/auth_providers.dart';
import '../../features/auth/presentation/screens/complete_profile_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/phone_entry_screen.dart';
import '../../features/auth/presentation/screens/verification_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/disputes/presentation/screens/dispute_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/reviews/presentation/screens/my_reviews_screen.dart';
import '../../features/reviews/presentation/screens/review_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/language_settings_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import 'app_shell.dart';
import 'go_router_refresh_stream.dart';
import 'route_paths.dart';

final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  final localCache = ref.watch(localCacheProvider);
  final supabase = ref.watch(supabaseClientProvider);

  return GoRouter(
    initialLocation: localCache.onboardingComplete ? RoutePaths.home : RoutePaths.onboarding,
    debugLogDiagnostics: false,
    refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange),
    redirect: (context, state) async {
      final bool onboardingDone = localCache.onboardingComplete;
      final bool signedIn = supabase.auth.currentSession != null;
      final String location = state.matchedLocation;

      final bool isOnboardingRoute = location == RoutePaths.onboarding;
      final bool isAuthRoute = location.startsWith('/auth');
      final bool isCompleteProfileRoute = location == RoutePaths.authCompleteProfile;

      if (!onboardingDone && !isOnboardingRoute) {
        return RoutePaths.onboarding;
      }
      if (onboardingDone && isOnboardingRoute) {
        return signedIn ? RoutePaths.home : RoutePaths.authPhone;
      }
      // `isCompleteProfileRoute` is deliberately excluded from the
      // "signed-out user on an auth route is fine, leave them" carve-out
      // below even though it starts with `/auth` — that route requires an
      // active session (it's the step right after OTP verification, not
      // an entry point). Without this, a session that ends while a user
      // sits on CompleteProfileScreen (explicit sign-out elsewhere, or
      // Supabase's own `signedOut` event on a failed token refresh — both
      // fire through `GoRouterRefreshStream` and re-run this redirect for
      // the current location) left them permanently stranded there: every
      // other branch below requires `signedIn`, so nothing would ever
      // move them off it again.
      if (onboardingDone && !signedIn && (!isAuthRoute || isCompleteProfileRoute)) {
        return RoutePaths.authPhone;
      }
      if (signedIn && isAuthRoute && !isCompleteProfileRoute) {
        return RoutePaths.home;
      }

      // Registration confirmed decision: phone/OTP is (and stays) this
      // app's actual Supabase Auth credential; right after that, every
      // signed-in user must have a `identity_details` row (овог/нэр/
      // регистрийн дугаар) before reaching anywhere else in the app — see
      // `identityDetailsCompletedProvider`'s header comment and
      // `CompleteProfileScreen`. DAN verification itself stays optional
      // (not gated here), same as before this change.
      //
      // `ref.read(...future)` rather than `.watch`: a redirect callback
      // has no widget tree to rebuild — reading the cached/in-flight
      // Future is the correct way to await a `FutureProvider` here, and
      // `GoRouterRefreshStream` + this file's own `context.go(...)` calls
      // (after CompleteProfileScreen submits) are what re-trigger this
      // redirect to pick up a freshly-invalidated result.
      if (signedIn && !isOnboardingRoute && !isCompleteProfileRoute) {
        final String? uid = supabase.auth.currentUser?.id;
        if (uid != null) {
          bool hasIdentityDetails;
          try {
            hasIdentityDetails = await ref.read(identityDetailsCompletedProvider(uid).future);
          } catch (_) {
            // Can't confirm either way (offline, backend hiccup) — don't
            // trap the user on a redirect loop over a transient read
            // failure; let them through and re-check on the next
            // navigation.
            hasIdentityDetails = true;
          }
          if (!hasIdentityDetails) {
            return RoutePaths.authCompleteProfile;
          }
        }
      }
      if (signedIn && isCompleteProfileRoute) {
        final String? uid = supabase.auth.currentUser?.id;
        if (uid != null) {
          bool hasIdentityDetails;
          try {
            hasIdentityDetails = await ref.read(identityDetailsCompletedProvider(uid).future);
          } catch (_) {
            hasIdentityDetails = false;
          }
          if (hasIdentityDetails) {
            return RoutePaths.home;
          }
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.onboarding,
        name: RouteNames.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.authPhone,
        name: RouteNames.authPhone,
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: RoutePaths.authOtp,
        name: RouteNames.authOtp,
        builder: (context, state) {
          final String phone = state.extra is String ? state.extra! as String : '';
          return OtpVerificationScreen(phone: phone);
        },
      ),
      GoRoute(
        path: RoutePaths.authCompleteProfile,
        name: RouteNames.authCompleteProfile,
        builder: (context, state) => const CompleteProfileScreen(),
      ),

      // Bottom tab shell (UI/UX pass, Aug 2026): Home, Search, Bookings,
      // Wallet, Profile are the five persistent destinations reachable in
      // one tap, matching the product's nav mockup. Everything else
      // (asset/booking detail, create flows, settings, admin) pushes on
      // top of whichever tab launched it — standard mobile shell-nav
      // convention. `StatefulShellBranch` gives each tab its own
      // Navigator, so switching tabs preserves that tab's scroll position
      // and push stack instead of resetting it.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                name: RouteNames.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.search,
                name: RouteNames.search,
                builder: (context, state) {
                  final AssetSearchFilters? initialFilters =
                      state.extra is AssetSearchFilters ? state.extra! as AssetSearchFilters : null;
                  return SearchScreen(initialFilters: initialFilters);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.myBookings,
                name: RouteNames.myBookings,
                builder: (context, state) => const MyBookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.wallet,
                name: RouteNames.wallet,
                builder: (context, state) => const WalletScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profile,
                name: RouteNames.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: RoutePaths.verification,
        name: RouteNames.verification,
        builder: (context, state) {
          final bool isPostRegistration = state.extra == true;
          return VerificationScreen(isPostRegistration: isPostRegistration);
        },
      ),
      GoRoute(
        path: RoutePaths.settingsLanguage,
        name: RouteNames.settingsLanguage,
        builder: (context, state) => const LanguageSettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.assetDetail,
        name: RouteNames.assetDetail,
        builder: (context, state) {
          final String id = state.pathParameters['id']!;
          return AssetDetailScreen(assetId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.assetCreate,
        name: RouteNames.assetCreate,
        builder: (context, state) => const AssetCreateScreen(),
      ),
      GoRoute(
        path: RoutePaths.myAssets,
        name: RouteNames.myAssets,
        builder: (context, state) => const MyAssetsScreen(),
      ),
      GoRoute(
        path: RoutePaths.bookingRequest,
        name: RouteNames.bookingRequest,
        builder: (context, state) {
          final String id = state.pathParameters['id']!;
          return BookingRequestScreen(assetId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.bookingDetail,
        name: RouteNames.bookingDetail,
        builder: (context, state) {
          final String id = state.pathParameters['id']!;
          return BookingDetailScreen(bookingId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.bookingChat,
        name: RouteNames.bookingChat,
        builder: (context, state) {
          final String id = state.pathParameters['id']!;
          return ChatScreen(bookingId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.notifications,
        name: RouteNames.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.bookingConditionReport,
        name: RouteNames.bookingConditionReport,
        builder: (context, state) {
          final String id = state.pathParameters['id']!;
          final String stageId = state.pathParameters['stage']!;
          return ConditionReportScreen(
            bookingId: id,
            stage: ConditionReportStage.fromId(stageId),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.bookingReview,
        name: RouteNames.bookingReview,
        builder: (context, state) {
          final String id = state.pathParameters['id']!;
          return ReviewScreen(bookingId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.bookingDispute,
        name: RouteNames.bookingDispute,
        builder: (context, state) {
          final String id = state.pathParameters['id']!;
          return DisputeScreen(bookingId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.myReviews,
        name: RouteNames.myReviews,
        builder: (context, state) => const MyReviewsScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminDashboard,
        name: RouteNames.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminAssetModeration,
        name: RouteNames.adminAssetModeration,
        builder: (context, state) => const AdminAssetModerationScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminDisputes,
        name: RouteNames.adminDisputes,
        builder: (context, state) => const AdminDisputeQueueScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminPayouts,
        name: RouteNames.adminPayouts,
        builder: (context, state) => const AdminPayoutQueueScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminReports,
        name: RouteNames.adminReports,
        builder: (context, state) => const AdminReportQueueScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminCommissionSettings,
        name: RouteNames.adminCommissionSettings,
        builder: (context, state) => const AdminCommissionSettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminPromotions,
        name: RouteNames.adminPromotions,
        builder: (context, state) => const AdminPromotionsScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminPromotionForm,
        name: RouteNames.adminPromotionForm,
        builder: (context, state) {
          final Promotion? existing = state.extra is Promotion ? state.extra! as Promotion : null;
          return AdminPromotionFormScreen(existing: existing);
        },
      ),
      GoRoute(
        path: RoutePaths.adminBanners,
        name: RouteNames.adminBanners,
        builder: (context, state) => const AdminBannersScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminBannerForm,
        name: RouteNames.adminBannerForm,
        builder: (context, state) {
          final AppBanner? existing = state.extra is AppBanner ? state.extra! as AppBanner : null;
          return AdminBannerFormScreen(existing: existing);
        },
      ),
    ],
  );
});
