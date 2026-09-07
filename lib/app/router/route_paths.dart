/// Central registry of route paths + names. Features reference these
/// constants rather than hardcoding path strings, so a path rename is a
/// one-file edit. Deep link paths (spec section 41) mirror these.
class RoutePaths {
  const RoutePaths._();

  static const String onboarding = '/onboarding';

  static const String authPhone = '/auth/phone';
  static const String authOtp = '/auth/otp';
  static const String authCompleteProfile = '/auth/complete-profile';

  static const String home = '/home';
  static const String profile = '/profile';
  static const String verification = '/profile/verify';
  static const String settingsLanguage = '/settings/language';

  static const String search = '/search';
  static const String assetDetail = '/asset/:id';
  static const String assetCreate = '/assets/new';
  static const String myAssets = '/assets/mine';

  static const String bookingRequest = '/asset/:id/book';
  static const String bookingDetail = '/booking/:id';
  static const String bookingChat = '/booking/:id/chat';
  static const String myBookings = '/bookings/mine';

  static const String wallet = '/wallet';
  static const String notifications = '/notifications';

  static const String bookingConditionReport = '/booking/:id/condition/:stage';
  static const String bookingReview = '/booking/:id/review';
  static const String bookingDispute = '/booking/:id/dispute';
  static const String myReviews = '/profile/reviews';

  static const String adminDashboard = '/admin';
  static const String adminAssetModeration = '/admin/assets';
  static const String adminDisputes = '/admin/disputes';
  static const String adminPayouts = '/admin/payouts';
  static const String adminReports = '/admin/reports';
  static const String adminCommissionSettings = '/admin/commission';
  static const String adminPromotions = '/admin/promotions';
  static const String adminPromotionForm = '/admin/promotions/form';
  static const String adminBanners = '/admin/banners';
  static const String adminBannerForm = '/admin/banners/form';
}

class RouteNames {
  const RouteNames._();

  static const String onboarding = 'onboarding';
  static const String authPhone = 'authPhone';
  static const String authOtp = 'authOtp';
  static const String authCompleteProfile = 'authCompleteProfile';
  static const String home = 'home';
  static const String profile = 'profile';
  static const String verification = 'verification';
  static const String settingsLanguage = 'settingsLanguage';
  static const String search = 'search';
  static const String assetDetail = 'assetDetail';
  static const String assetCreate = 'assetCreate';
  static const String myAssets = 'myAssets';
  static const String bookingRequest = 'bookingRequest';
  static const String bookingDetail = 'bookingDetail';
  static const String bookingChat = 'bookingChat';
  static const String myBookings = 'myBookings';

  static const String wallet = 'wallet';
  static const String notifications = 'notifications';

  static const String bookingConditionReport = 'bookingConditionReport';
  static const String bookingReview = 'bookingReview';
  static const String bookingDispute = 'bookingDispute';
  static const String myReviews = 'myReviews';

  static const String adminDashboard = 'adminDashboard';
  static const String adminAssetModeration = 'adminAssetModeration';
  static const String adminDisputes = 'adminDisputes';
  static const String adminPayouts = 'adminPayouts';
  static const String adminReports = 'adminReports';
  static const String adminCommissionSettings = 'adminCommissionSettings';
  static const String adminPromotions = 'adminPromotions';
  static const String adminPromotionForm = 'adminPromotionForm';
  static const String adminBanners = 'adminBanners';
  static const String adminBannerForm = 'adminBannerForm';
}
