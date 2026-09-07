import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Hand-written localization (Mongolian primary, English secondary — spec
/// section 38) rather than a `flutter gen-l10n`-generated class.
///
/// Why hand-written: this project was built in an environment without a
/// working Flutter SDK, so the generated output of `flutter gen-l10n`
/// could never actually be produced or verified here (see README "Known
/// issues"). Rather than ship an unverifiable codegen dependency for
/// something as basic as string lookup, this class is plain Dart, checked
/// by inspection like everything else in this scaffold. This is now the
/// ONLY localization system in this repo — a parallel ARB/`gen-l10n`
/// scaffold used to sit alongside it with a comment claiming the keys
/// matched 1:1; that was true only very early on (~45 keys) and was never
/// kept in sync as this class grew to 400+ getters, so an external audit
/// (Aug 2026) correctly flagged it as stale/false documentation. The dead
/// ARB files were removed rather than reconciled by hand — see README's
/// "Localization" section for the full reasoning.
///
/// Usage: `AppLocalizations.of(context).onboardingCta`.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = [Locale('mn'), Locale('en')];

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final AppLocalizations? l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(l10n != null, 'AppLocalizations.of() called without an AppLocalizations ancestor. '
        'Did you forget to add AppLocalizations.delegate to MaterialApp.localizationsDelegates?');
    return l10n!;
  }

  bool get _isMn => locale.languageCode == 'mn';

  String _t(String mn, String en) => _isMn ? mn : en;

  // Brand — not translated.
  String get appName => 'ХУВААЛЦ';

  String get tagline =>
      _t('Ашигладаггүй зүйлээ мөнгө болго.', "Turn what you don't use into money.");

  /// The short English ethos-line under the wordmark on the onboarding
  /// brand banner (`_BrandBanner`) — a deliberate stylistic pairing with
  /// the untranslated Cyrillic [appName], not a functional description
  /// like [tagline], so it stays the same across locales.
  String get brandTagline => 'share • connect • grow';

  // Onboarding
  String get onboardingTitle1 => _t('Хэрэгтэй зүйлээ түрээслэ.', 'Rent what you need.');
  String get onboardingTitle2 =>
      _t('Ашигладаггүй зүйлээ мөнгө болго.', "Turn what you don't use into money.");
  String get onboardingTitle3 => _t(
        'Баталгаатай хүмүүсээс найдвартай түрээслэ.',
        'Rent safely from verified people.',
      );
  String get onboardingCta => _t('Эхлэх', 'Get started');
  String get onboardingSkip => _t('Алгасах', 'Skip');

  // Auth
  String get authPhoneTitle => _t('Утасны дугаараа оруулна уу', 'Enter your phone number');
  String get authPhoneHint => '99112233';
  String get authOtpTitle => _t('Баталгаажуулах код', 'Verification code');

  String authOtpSubtitle(String phone) => _t(
        '$phone дугаарт илгээсэн 6 оронтой кодыг оруулна уу',
        'Enter the 6-digit code sent to $phone',
      );

  String get authOtpResend => _t('Дахин илгээх', 'Resend');

  String authOtpResendIn(int seconds) =>
      _t('Дахин илгээх (${seconds}с)', 'Resend (${seconds}s)');

  String get authContinueWithGoogle => _t('Google-ээр үргэлжлүүлэх', 'Continue with Google');
  String get authContinueWithApple => _t('Apple-ээр үргэлжлүүлэх', 'Continue with Apple');
  String get authOr => _t('эсвэл', 'or');
  String get authInvalidPhone => _t('Утасны дугаар буруу байна', 'Invalid phone number');
  String get authInvalidOtp => _t('Код буруу байна', 'Invalid code');
  String get authSignedOut => _t('Нэвтрээгүй байна', 'Not signed in');

  // Complete profile — collects овог/нэр + регистрийн дугаар right after
  // phone/OTP sign-up, before DAN verification (confirmed product
  // decision: registration starts with phone/OTP as the actual
  // Supabase Auth credential, then this step, then DAN — see
  // `identity_details` table's header comment,
  // `supabase/migrations/0017_wire_topup_and_wallet_payments.sql`).
  String get authCompleteProfileTitle => _t('Мэдээллээ бөглөнө үү', 'Complete your profile');
  String get authCompleteProfileBody => _t(
        'Овог, нэр, регистрийн дугаараа үнэн зөв оруулна уу. Энэ мэдээллийг зөвхөн та '
            'болон ХУВААЛЦ харах бөгөөд бусад хэрэглэгчид харагдахгүй.',
        'Enter your surname, given name, and register number. Only you and ХУВААЛЦ '
            'can see this — it is never shown to other users.',
      );
  String get authSurnameLabel => _t('Овог', 'Surname');
  String get authGivenNameLabel => _t('Нэр', 'Given name');
  String get authRegisterNumberLabel => _t('Регистрийн дугаар', 'Register number');
  String get authRegisterNumberHint => 'АА12345678';
  String get authSurnameRequired => _t('Овгоо оруулна уу', 'Enter your surname');
  String get authGivenNameRequired => _t('Нэрээ оруулна уу', 'Enter your given name');
  String get authRegisterNumberInvalid =>
      _t('Регистрийн дугаар буруу байна', 'Enter a valid register number');
  String get authRegisterNumberAlreadyUsed => _t(
        'Энэ регистрийн дугаар өөр бүртгэлд бүртгэгдсэн байна',
        'This register number is already linked to another account',
      );
  String get authCompleteProfileSubmitAction => _t('Үргэлжлүүлэх', 'Continue');

  // Verification
  String get verifiedUser => _t('Баталгаатай хэрэглэгч', 'Verified user');
  String get verificationLevelPhone => _t('Утас баталгаажсан', 'Phone verified');
  String get verificationLevelDan => _t('DAN-аар баталгаажсан', 'DAN verified');
  String get verificationLevelIdentity =>
      _t('Иргэний үнэмлэхээр баталгаажсан', 'Identity verified');
  String get verificationLevelBusiness => _t('Байгууллага баталгаажсан', 'Business verified');

  // Profile
  String get profileTitle => _t('Профайл', 'Profile');
  String get profileEditAction => _t('Засах', 'Edit');
  String get profileCompletedRentals => _t('Дууссан түрээс', 'Completed rentals');
  String get profileAssets => _t('Хөрөнгө', 'Assets');
  String get profileReviews => _t('Сэтгэгдэл', 'Reviews');
  String get profileSignOut => _t('Гарах', 'Sign out');

  // Settings / language
  String get settingsTitle => _t('Тохиргоо', 'Settings');
  String get settingsLanguage => _t('Хэл', 'Language');
  String get languageMongolian => 'Монгол';
  String get languageEnglish => 'English';

  // Home
  /// The reference design's personalized "Hello Michael!" header — shown
  /// above [homeWhatDoYouNeed] when the signed-in user has a display name,
  /// falling back to [homeGreetingGeneric] otherwise (no name on file, or
  /// still loading). Kept as a secondary line rather than replacing
  /// [homeWhatDoYouNeed] — that headline is the functional "what are you
  /// here to do" prompt, not just brand chrome, so it stays.
  String homeGreeting(String name) => _t('Сайн байна уу, $name!', 'Hello, $name!');
  String get homeGreetingGeneric => _t('Сайн байна уу!', 'Hello!');
  String get homeWhatDoYouNeed => _t('Танд юу хэрэгтэй вэ?', 'What do you need?');
  String get homePhase2Notice =>
      _t('Хайлт, ангилал зэрэг Phase 2-т нэмэгдэнэ.', 'Search and categories arrive in Phase 2.');

  // Home — quick filter pills (short forms distinct from the full section
  // titles below, which stay unchanged since Search still uses them).
  String get quickFilterAvailableToday => _t('Өнөөдөр авах', 'Available today');
  String get quickFilterUnder50k => _t('50K-с доош', 'Under 50K');
  String get quickFilterNearby3km => _t('3 км дотор', 'Within 3 km');

  // Home — featured hero carousel.
  String get homeFeaturedBadge => _t('Онцлох', 'Featured');
  String homeDistanceKm(String km) => _t('$km км', '$km km');

  // Home — value-proposition banner.
  String get homePromoTitle => _t('Хуваалцъя, хэмнээ', 'Share more, spend less');
  String get homePromoEasySearchTitle => _t('Хялбар хайлт', 'Easy search');
  String get homePromoEasySearchDesc => _t('Хэрэгтэйгээ хурдан ол', 'Find what you need fast');
  String get homePromoNearbyTitle => _t('Ойрхон түрээслэнэ', 'Rent nearby');
  String get homePromoNearbyDesc => _t('Хамгийн ойрхон эзэмшигчээс', 'From owners close to you');
  String get homePromoSafePaymentTitle => _t('Аюулгүй төлбөр', 'Safe payment');
  String get homePromoSafePaymentDesc => _t('Хэтэвчээр найдвартай төлнө', 'Pay securely from your wallet');
  String get homePromoVerifiedTitle => _t('Баталгаатай эзэмшигч', 'Verified owners');
  String get homePromoVerifiedDesc => _t('Шалгагдсан хэрэглэгчид', 'Checked, trusted users');

  // Home — wallet summary card.
  String get homeWalletCardTitle => _t('Миний хэтэвч', 'My wallet');
  String get homeWalletBalanceLabel => _t('Үлдэгдэл', 'Balance');
  String get homeWalletTopUpCta => _t('Цэнэглэх', 'Top up');
  String get homeWalletDetailsCta => _t('Дэлгэрэнгүй', 'Details');

  // Bottom tab navigation
  String get navHome => _t('Нүүр', 'Home');
  String get navSearch => _t('Хайх', 'Search');
  String get navBookings => _t('Захиалга', 'Bookings');
  String get navWallet => _t('Хэтэвч', 'Wallet');
  String get navProfile => _t('Профайл', 'Profile');

  // Common
  String get commonRetry => _t('Дахин оролдох', 'Retry');
  String get commonCancel => _t('Цуцлах', 'Cancel');
  String get commonSave => _t('Хадгалах', 'Save');
  String get commonContinue => _t('Үргэлжлүүлэх', 'Continue');
  String get commonLoading => _t('Уншиж байна...', 'Loading...');
  String get commonClose => _t('Хаах', 'Close');

  // Errors
  String get errorNetwork => _t('Интернет холболт тасарлаа.', "You're offline.");
  String get errorUnknown =>
      _t('Тодорхойгүй алдаа гарлаа. Дахин оролдоно уу.', 'Something went wrong. Please try again.');
  String get errorAuthRequired => _t('Нэвтрэх шаардлагатай байна.', 'Please sign in to continue.');
  String get errorSessionExpired => _t(
        'Нэвтрэх хугацаа дууссан байна. Дахин нэвтэрнэ үү.',
        'Your session expired. Please sign in again.',
      );
  String get errorPermission =>
      _t('Танд энэ үйлдлийг хийх эрх алга.', "You don't have permission to do this.");
  String get errorNotFound => _t('Олдсонгүй.', 'Not found.');
  String get errorValidation => _t('Мэдээлэл дутуу байна.', 'Some information is missing.');
  String get errorConflict => _t('Зөрчил илэрлээ.', 'Something conflicts with this action.');
  String get errorRateLimited =>
      _t('Түр хүлээгээд дахин оролдоно уу.', 'Please wait a moment and try again.');

  // Empty states
  String get emptyAssetsTitle => _t('Одоогоор энд хөрөнгө алга.', 'No assets here yet.');
  String get emptyAssetsAction => _t('Бүгдийг харах', 'See all');

  // Price units
  String get unitHour => _t('цаг', 'hr');
  String get unitDay => _t('өдөр', 'day');
  String get unitWeek => _t('долоо хоног', 'week');

  // Categories (spec section 11) — expanded 2026-08 from 9 to 16 real
  // categories (see `AssetCategory`'s doc comment for why `space` was
  // dropped and every other original id kept).
  String get categoryAll => _t('Бүгд', 'All');
  String get categoryCamera => _t('Камер & Зураг авалт', 'Camera & Photography');
  String get categoryDrone => _t('Дрон', 'Drones');
  String get categoryElectronics => _t('Компьютер & Электрон бараа', 'Computers & Electronics');
  String get categoryGaming => _t('Тоглоомын төхөөрөмж', 'Gaming');
  String get categoryAudio => _t('Дуу хөгжим & Аудио төхөөрөмж', 'Music & Audio');
  String get categoryProjector => _t('Проектор & Дэлгэц', 'Projectors & Screens');
  String get categoryEvent => _t('Арга хэмжээ & Үдэшлэг', 'Events & Parties');
  String get categoryTools => _t('Багаж хэрэгсэл & Засвар', 'Tools & Repair');
  String get categoryTravel => _t('Аялал & Зуслангийн хэрэгсэл', 'Travel & Camping');
  String get categorySports => _t('Спорт & Дасгал', 'Sports & Fitness');
  String get categoryVehicle => _t('Машин & Тээврийн хэрэгсэл', 'Cars & Vehicles');
  String get categoryHousehold => _t('Гэр ахуйн хэрэгсэл', 'Household');
  String get categoryOffice => _t('Оффисын хэрэгсэл & Тоног төхөөрөмж', 'Office Supplies & Equipment');
  String get categoryKids => _t('Хүүхдийн хэрэгсэл', "Kids' Gear");
  String get categoryFashion => _t('Хувцас & Гоёл чимэглэл', 'Fashion & Accessories');
  String get categoryConstruction => _t('Барилга & Хүнд тоног төхөөрөмж', 'Construction & Heavy Equipment');
  String get categoryOther => _t('Бусад', 'Other');

  // Home sections (spec section 11)
  String get searchHint => _t('Камер, дрон, projector...', 'Camera, drone, projector...');
  String get addAssetAction => _t('Хөрөнгө нэмэх', 'Add an asset');
  String get sectionNearby => _t('Ойролцоо', 'Nearby');
  String get sectionPopular => _t('Их үзсэн', 'Popular');
  String get sectionRecentlyAdded => _t('Саяхан нэмэгдсэн', 'Recently added');
  String get sectionRecommended => _t('Танд санал болгож байна', 'Recommended for you');
  String get sectionUnder50k => _t('50,000₮-с доош', 'Under 50,000₮');
  String get sectionVerifiedOwners => _t('Баталгаатай эзэмшигчид', 'Verified owners');
  String get sectionTrending => _t('Эрэлттэй байгаа', 'Trending');
  String get sectionSeeAll => _t('Бүгдийг харах', 'See all');

  // Search (spec section 12)
  String get searchTitle => _t('Хайх', 'Search');
  String get searchFilters => _t('Шүүлтүүр', 'Filters');
  String get searchSortLabel => _t('Эрэмбэлэх', 'Sort');
  String get sortRecommended => _t('Санал болгох', 'Recommended');
  String get sortCheapest => _t('Хямд эхэлж', 'Cheapest first');
  String get sortMostExpensive => _t('Үнэтэй эхэлж', 'Most expensive first');
  String get sortClosest => _t('Хамгийн ойр', 'Closest');
  String get sortHighestRated => _t('Өндөр үнэлгээтэй', 'Highest rated');
  String get sortNewest => _t('Шинэ нэмэгдсэн', 'Newest');
  String get filterVerifiedOwnersOnly => _t('Зөвхөн баталгаатай эзэмшигч', 'Verified owners only');
  String get filterPriceRange => _t('Үнийн хязгаар', 'Price range');
  String get filterMinPrice => _t('Доод үнэ', 'Min price');
  String get filterMaxPrice => _t('Дээд үнэ', 'Max price');
  String get filterApply => _t('Хэрэглэх', 'Apply');
  String get filterClear => _t('Цэвэрлэх', 'Clear');
  String get loadMore => _t('Цааш үзэх', 'Load more');

  // Map view (spec section 13)
  String get searchShowMapAction => _t('Газрын зураг', 'Map');
  String get searchShowListAction => _t('Жагсаалт', 'List');
  String get mapNoLocatedAssets =>
      _t('Байршил бүхий хөрөнгө алга.', 'No located assets to show.');
  String get mapMyLocationUnavailable => _t(
        'Таны байршлыг тодорхойлж чадсангүй — байршлын зөвшөөрлөө шалгана уу.',
        "Couldn't determine your location — check your location permission.",
      );

  // Asset create form (spec section 14 — the AI listing assistant itself
  // remains a later-phase addition; this is the plain manual form)
  String get assetCreateSectionPhotos => _t('Зураг', 'Photos');
  String get assetCreateAddPhotos => _t('Зураг нэмэх', 'Add photos');
  String assetCreatePhotosHint(int max) =>
      _t('Хамгийн ихдээ $max зураг', 'Up to $max photos');
  String get assetCreateRemovePhoto => _t('Устгах', 'Remove');

  String get assetCreateSectionBasics => _t('Үндсэн мэдээлэл', 'Basic info');
  String get assetCreateTitleLabel => _t('Гарчиг', 'Title');
  String get assetCreateTitleHint =>
      _t('Жишээ: Canon EOS R5 камер', 'e.g. Canon EOS R5 camera');
  String get assetCreateDescriptionLabel => _t('Тайлбар', 'Description');
  String get assetCreateDescriptionHint => _t(
        'Хөрөнгийн байдал, юу орсныг дэлгэрэнгүй бичнэ үү',
        "Describe the item's condition and what's included",
      );
  String get assetCreateCategoryLabel => _t('Ангилал', 'Category');
  String get assetCreateBrandLabel => _t('Брэнд', 'Brand');
  String get assetCreateModelLabel => _t('Модел', 'Model');
  String get assetCreateConditionLabel => _t('Байдал', 'Condition');
  String get conditionNew => _t('Шинэ', 'New');
  String get conditionLikeNew => _t('Бараг шинэ', 'Like new');
  String get conditionGood => _t('Сайн', 'Good');
  String get conditionFair => _t('Хэрэглэсэн', 'Fair');

  String get assetCreateSectionSpecs => _t('Техник үзүүлэлт', 'Specifications');
  String get assetCreateSpecKeyHint => _t('Жишээ: Мегапиксель', 'e.g. Megapixels');
  String get assetCreateSpecValueHint => _t('Жишээ: 45MP', 'e.g. 45MP');
  String get assetCreateAddSpec => _t('Үзүүлэлт нэмэх', 'Add specification');

  String get assetCreateSectionPricing => _t('Үнэ', 'Pricing');
  String get assetCreatePricePerHourLabel => _t('Цагийн үнэ', 'Price per hour');
  String get assetCreatePricePerDayLabel => _t('Өдрийн үнэ', 'Price per day');
  String get assetCreatePricePerWeekLabel =>
      _t('Долоо хоногийн үнэ', 'Price per week');

  String get assetCreateSectionLogistics => _t('Хүргэлт, байршил', 'Pickup & location');
  String get assetCreatePickupMethodLabel => _t('Хүлээн авах хэлбэр', 'Pickup method');
  String get pickupMethodPickup => _t('Өөрөө очиж авах', 'Renter picks up');
  String get pickupMethodDelivery => _t('Хүргэж өгнө', 'Owner delivers');
  String get pickupMethodBoth => _t('Аль ч тохиромжтой', 'Either works');
  String get assetCreateDeliveryAvailableLabel => _t('Хүргэлттэй', 'Delivery available');
  String get assetCreateLocationLabel => _t('Байршил', 'Location');
  String get assetCreateLocationHint =>
      _t('Жишээ: Сүхбаатар дүүрэг, Улаанбаатар', 'e.g. Sükhbaatar district, Ulaanbaatar');

  String get assetCreateSectionRules => _t('Түрээсийн нөхцөл', 'Rental rules');
  String get assetCreateRuleHint =>
      _t('Жишээ: Тамхи татахыг хориглоно', 'e.g. No smoking');
  String get assetCreateAddRule => _t('Нөхцөл нэмэх', 'Add rule');

  String get assetCreateSubmit => _t('Нийтлэх', 'Publish');
  String get assetCreateSuccess =>
      _t('Хөрөнгө амжилттай нийтлэгдлээ', 'Your asset was published');
  String get assetCreateErrorTitleRequired => _t('Гарчиг оруулна уу', 'Enter a title');
  String get assetCreateErrorCategoryRequired =>
      _t('Ангилал сонгоно уу', 'Choose a category');
  String get assetCreateErrorPriceRequired =>
      _t('Хамгийн багадаа нэг үнэ оруулна уу', 'Enter at least one price');
  String get assetCreateErrorPriceInvalid =>
      _t('Үнэ сөрөг байж болохгүй', 'Price cannot be negative');
  String get assetCreateImagePickError =>
      _t('Зураг сонгоход алдаа гарлаа', "Couldn't select photos");

  // My assets (spec section 22 — minimal listing slice)
  String get myAssetsTitle => _t('Миний хөрөнгө', 'My assets');
  String get myAssetsEmptyTitle =>
      _t('Та одоогоор хөрөнгө нэмээгүй байна.', "You haven't listed any assets yet.");

  // Asset detail (spec section 16)
  String get assetDetailSectionDescription => _t('Тайлбар', 'Description');
  String get assetDetailSectionSpecifications => _t('Техник үзүүлэлт', 'Specifications');
  String get assetDetailSectionRules => _t('Түрээсийн нөхцөл', 'Rental rules');
  String get assetDetailSectionOwner => _t('Эзэмшигч', 'Owner');
  String get assetDetailSectionLogistics => _t('Хүлээн авах', 'Pickup');
  String assetDetailMemberSince(String date) => _t('$date-с гишүүн', 'Member since $date');
  String get assetDetailBookCta => _t('Захиалах', 'Book');
  String get assetDetailCancellationTitle => _t('Цуцлах нөхцөл', 'Cancellation policy');
  String get assetDetailCancellationBody => _t(
        'Захиалгаас 24 цагийн өмнө цуцалбал бүтэн буцаалттай. Дараа нь цуцалбал эзэмшигчийн '
            'нөхцөлөөр тодорхойлогдоно.',
        'Cancel 24+ hours before the booking starts for a full refund. Later cancellations '
            "follow the owner's policy.",
      );
  String get assetDetailDeliveryAvailable => _t('Хүргэлттэй', 'Delivery available');

  // Booking request (spec sections 17, 18)
  String get bookingRequestTitle => _t('Захиалга', 'Booking request');
  String get bookingSelectDates => _t('Огноо сонгох', 'Select dates');
  String get bookingPickDates => _t('Огноо сонгох', 'Choose dates');
  String get bookingDatesUnavailable => _t(
        'Сонгосон огноо аль хэдийн захиалагдсан байна. Өөр огноо сонгоно уу.',
        'Those dates are already taken. Please choose different dates.',
      );
  String get bookingNotBookableTitle =>
      _t('Энэ хөрөнгийг одоогоор захиалах боломжгүй', 'This asset can\'t be booked yet');
  String get bookingNotBookableBody => _t(
        'Захиалга зөвхөн өдрийн үнэтэй хөрөнгөд ажиллана.',
        'Booking currently only works for assets with a daily price.',
      );
  String get bookingPriceBreakdown => _t('Үнийн задаргаа', 'Price breakdown');
  String bookingRentalAmountLabel(int nights) => _t(
        '$nights хоног түрээс',
        '$nights ${nights == 1 ? 'night' : 'nights'} rental',
      );
  String get bookingPlatformFeeLabel => _t('Үйлчилгээний хөлс', 'Service fee');
  String get bookingTotalLabel => _t('Нийт дүн', 'Total');
  String get bookingEstimateDisclaimer => _t(
        'Энэ бол тооцоолсон үнэ — эцсийн дүнг илгээхэд баталгаажуулна.',
        'This is an estimate — the final amount is confirmed when you submit.',
      );
  String get bookingSubmit => _t('Захиалга илгээх', 'Send request');

  // Booking status (spec section 17)
  String get bookingStatusPending => _t('Хүлээгдэж буй', 'Pending');
  String get bookingStatusConfirmed => _t('Баталгаажсан', 'Confirmed');
  String get bookingStatusRejected => _t('Татгалзсан', 'Rejected');
  String get bookingStatusCancelled => _t('Цуцлагдсан', 'Cancelled');
  String get bookingStatusActive => _t('Идэвхтэй', 'Active');
  String get bookingStatusCompleted => _t('Дууссан', 'Completed');
  String get bookingStatusDisputed => _t('Маргаантай', 'Disputed');

  // Booking detail (spec sections 17, 18)
  String get bookingDetailTitle => _t('Захиалгын дэлгэрэнгүй', 'Booking details');
  String get bookingDetailDatesLabel => _t('Огноо', 'Dates');
  String get bookingDetailWithOwnerLabel => _t('Эзэмшигч', 'Owner');
  String get bookingDetailWithRenterLabel => _t('Түрээслэгч', 'Renter');
  String get bookingDetailCancellationReasonLabel => _t('Шалтгаан', 'Reason');
  String get bookingConfirmAction => _t('Баталгаажуулах', 'Confirm');
  String get bookingRejectAction => _t('Татгалзах', 'Reject');
  String get bookingCancelAction => _t('Цуцлах', 'Cancel booking');
  String get bookingConfirmedMessage => _t('Захиалгыг баталгаажууллаа', 'Booking confirmed');
  String get bookingRejectedMessage => _t('Захиалгаас татгалзлаа', 'Booking rejected');
  String get bookingCancelledMessage => _t('Захиалгыг цуцаллаа', 'Booking cancelled');
  String get bookingCancelReasonPromptTitle => _t('Цуцлах шалтгаан', 'Reason for cancelling');
  String get bookingCancelReasonHint =>
      _t('Шалтгаанаа бичнэ үү (заавал биш)', 'Optional — let them know why');
  String get bookingRejectReasonPromptTitle => _t('Татгалзах шалтгаан', 'Reason for rejecting');
  String get bookingConfirmDialogTitle => _t('Захиалгыг баталгаажуулах уу?', 'Confirm this booking?');
  String get bookingConfirmDialogBody => _t(
        'Та энэ захиалгыг хүлээн авахад бэлэн үү?',
        'Are you ready to accept this booking?',
      );

  // My bookings (spec section 15)
  String get myBookingsTitle => _t('Миний захиалгууд', 'My bookings');
  String get myBookingsAsRenterTab => _t('Түрээслэсэн', 'Renting');
  String get myBookingsAsOwnerTab => _t('Хүлээн авсан', 'Hosting');
  String get myBookingsEmptyTitle => _t('Захиалга алга байна.', 'No bookings yet.');

  // Payments — booking payments are wallet-balance-based end to end (see
  // `pay_booking_from_wallet`,
  // `supabase/migrations/0017_wire_topup_and_wallet_payments.sql`); the
  // renter's own wallet is debited directly, no external gateway step.
  String get paymentSectionTitle => _t('Төлбөр', 'Payment');
  String get paymentStatusPending => _t('Хүлээгдэж буй', 'Pending');
  String get paymentStatusPaid => _t('Төлөгдсөн', 'Paid');
  String get paymentStatusFailed => _t('Амжилтгүй', 'Failed');
  String get paymentStatusRefunded => _t('Буцаагдсан', 'Refunded');
  String get paymentAmountDueLabel => _t('Төлөх дүн', 'Amount due');
  String get paymentNotPaidYetLabel => _t('Түрээслэгч төлбөр хийгээгүй байна', 'Renter hasn\'t paid yet');
  String get paymentPayNowAction => _t('Хэтэвчээр төлөх', 'Pay from wallet');
  String get paymentRetryAction => _t('Дахин оролдох', 'Retry payment');
  String get paymentSuccessMessage => _t('Төлбөр амжилттай хийгдлээ', 'Payment successful');
  String get paymentFailedMessage => _t('Төлбөр амжилтгүй боллоо', 'Payment failed');
  String paymentWalletBalanceLabel(String amount) =>
      _t('Хэтэвчний үлдэгдэл: $amount', 'Wallet balance: $amount');
  String get paymentInsufficientBalanceTitle =>
      _t('Хэтэвчинд мөнгө хүрэхгүй байна', 'Not enough in your wallet');
  String paymentInsufficientBalanceBody(String due, String available) => _t(
        'Төлөх дүн $due, харин хэтэвчинд $available байна. Эхлээд хэтэвчээ цэнэглэнэ үү.',
        'This booking costs $due but your wallet only has $available. Top up first.',
      );
  String get paymentTopUpAction => _t('Хэтэвч цэнэглэх', 'Top up wallet');

  // Mock payment sheet — always clearly labeled as a simulation, never
  // presented as a real payment (spec section 51).
  String get mockPaymentSheetTitle => _t('Төлбөрийн загвар (MOCK)', 'Mock payment');
  String get mockPaymentSheetWarning => _t(
        'Энэ бол загвар — жинхэнэ мөнгө шилжихгүй. Жинхэнэ төлбөрийн систем '
            'холбогдоогүй байна.',
        'This is a simulation — no real money moves. A real payment provider '
            "isn't connected yet.",
      );
  String get mockPaymentSimulateSuccess => _t('Амжилттай гэж дүрслэх', 'Simulate success');
  String get mockPaymentSimulateFailure => _t('Амжилтгүй гэж дүрслэх', 'Simulate failure');

  // Identity verification flow (Phase 6, spec section 9) — the DAN
  // start/poll UI that reads on `IdentityVerificationRepository` and was
  // previously scaffolded but unreachable from any screen.
  String get profileGetVerifiedAction => _t('Баталгаажуулах', 'Get verified');
  String get profileAlreadyVerifiedLabel => _t('Баталгаажсан', 'Verified');
  String get verificationScreenTitle => _t('Баталгаажуулалт', 'Verification');
  // Latin "DAN" (not the Cyrillic "ДЭМБ"/WHO mistranslation this
  // replaced) — matches how `verificationLevelDan` and every other brand
  // name in this file (Google, Apple, wire.mn) stays in Latin script
  // inside an otherwise-Cyrillic sentence.
  String get verificationIntroTitle =>
      _t('DAN-аар баталгаажуулах', 'Verify with DAN');
  String get verificationIntroBody => _t(
        'Таны хувийн мэдээллийг DAN (Digital Authentication Network) '
            'ашиглан баталгаажуулснаар бусад хэрэглэгчид танд итгэх итгэл '
            'нэмэгдэнэ.',
        'Verifying your identity through DAN (Digital Authentication '
            'Network) helps other users trust you as an owner or renter.',
      );
  String get verificationStartAction => _t('Баталгаажуулж эхлэх', 'Start verification');
  String get verificationStartingLabel => _t('Эхэлж байна...', 'Starting...');
  String get verificationConsentTitle =>
      _t('DAN-ы зөвшөөрөл', 'DAN consent');
  String get verificationConsentBody => _t(
        'Үргэлжлүүлэхийн тулд DAN-ы зөвшөөрлийн хуудсыг бөглөнө үү.',
        'Continue to DAN\'s consent page to finish verifying.',
      );
  String get verificationOpenConsentAction =>
      _t('Зөвшөөрлийн хуудас нээх', 'Open consent page');
  String get verificationIveCompletedAction =>
      _t('Би зөвшөөрлөө өгсөн', "I've given consent");
  // Mock consent — same "clearly loud fake" pattern as the mock payment
  // sheet (spec section 51). Shown instead of an external browser
  // whenever the session's consent URL is this project's own mock
  // placeholder host, regardless of which DanAuthService adapter
  // produced it — see verification_screen.dart.
  String get verificationMockConsentWarning => _t(
        'Энэ бол загвар зөвшөөрлийн дэлгэц — жинхэнэ DAN систем рүү холбогдохгүй. '
            'Жинхэнэ баталгаажуулалтын систем холбогдоогүй байна.',
        "This is a simulated consent screen — it doesn't connect to real "
            "DAN. A real verification provider isn't connected yet.",
      );
  String get verificationMockConsentAction =>
      _t('Зөвшөөрлийг дүрслэх (MOCK)', 'Simulate giving consent (MOCK)');
  String get verificationPollingLabel =>
      _t('Баталгаажуулалтыг шалгаж байна...', 'Checking verification status...');
  String get verificationSuccessTitle => _t('Баталгаажлаа!', 'Verified!');
  String get verificationSuccessBody => _t(
        'Таны профайл дээр баталгаатай тэмдэг харагдах болно.',
        'The verified badge will now show on your profile.',
      );
  String get verificationDoneAction => _t('Дуусгах', 'Done');
  String get verificationFailedTitle =>
      _t('Баталгаажуулж чадсангүй', 'Verification not completed');
  String get verificationTimeoutMessage => _t(
        'Хариу удаж байна. Дахин оролдоно уу.',
        'This is taking longer than expected. Please try again.',
      );
  String get verificationTryAgainAction => _t('Дахин оролдох', 'Try again');

  // Shown only when `VerificationScreen` is reached right after
  // registration (`isPostRegistration`) — DAN verification itself stays
  // optional there too, same as when reached later from Profile, so a
  // government-service outage can't trap a new user out of the app.
  String get verificationSkipForNowAction => _t('Дараа нь баталгаажуулах', 'Verify later');

  // Wallet (Phase 7, spec sections 20, 33 — balances/transactions are
  // read-only client side; see supabase/migrations/0008_wallet_credit_rpc.sql).
  String get profileWalletAction => _t('Хэтэвч', 'Wallet');
  String get walletTitle => _t('Хэтэвч', 'Wallet');
  String get walletTransactionsTab => _t('Гүйлгээ', 'Transactions');
  String get walletPayoutsTab => _t('Мөнгө татах хүсэлт', 'Payout requests');
  String get walletAvailableBalanceLabel => _t('Боломжтой үлдэгдэл', 'Available balance');
  String get walletPendingBalanceLabel => _t('Хүлээгдэж буй', 'Pending');
  String get walletTotalEarnedLabel => _t('Нийт орлого', 'Total earned');
  String get walletRequestPayoutAction => _t('Мөнгө татах', 'Request payout');
  String get walletEmptyTransactionsTitle =>
      _t('Гүйлгээ алга байна.', 'No transactions yet.');
  String get walletEmptyPayoutsTitle =>
      _t('Мөнгө татах хүсэлт алга байна.', 'No payout requests yet.');
  String get walletPayoutRequestedMessage =>
      _t('Мөнгө татах хүсэлт илгээгдлээ', 'Payout requested');
  String walletPayoutAvailableLabel(String amount) =>
      _t('Боломжтой: $amount', 'Available: $amount');
  String get walletPayoutAmountLabel => _t('Дүн', 'Amount');
  String get walletPayoutInvalidAmount =>
      _t('Зөв дүн оруулна уу', 'Enter a valid amount');
  String get walletPayoutExceedsAvailable =>
      _t('Боломжтой үлдэгдлээс хэтэрсэн байна', 'This exceeds your available balance');

  String get walletTransactionBookingIncome => _t('Захиалгын орлого', 'Booking income');
  String get walletTransactionPlatformFee => _t('Үйлчилгээний хураамж', 'Platform fee');
  String get walletTransactionRefund => _t('Буцаалт', 'Refund');
  String get walletTransactionPayout => _t('Татсан мөнгө', 'Payout');
  String get walletTransactionAdjustment => _t('Тохируулга', 'Adjustment');
  String get walletTransactionWalletTopup => _t('Хэтэвч цэнэглэлт', 'Wallet top-up');
  String get walletTransactionBookingPayment => _t('Захиалгын төлбөр', 'Booking payment');

  // Wallet top-up (wire.mn) — see `supabase/functions/wire-topup/` and
  // `wire-topup-webhook/`'s header comments for why every top-up creates
  // its own PaymentIntent instead of reusing one shared static link.
  String get walletTopUpAction => _t('Цэнэглэх', 'Top up');
  String get walletTopUpSheetTitle => _t('Хэтэвч цэнэглэх', 'Top up wallet');
  String get walletTopUpAmountLabel => _t('Цэнэглэх дүн', 'Amount to add');
  String get walletTopUpInvalidAmount => _t('Зөв дүн оруулна уу', 'Enter a valid amount');
  String walletTopUpAmountRange(String min, String max) =>
      _t('$min-с $max хооронд байна', 'Must be between $min and $max');
  String get walletTopUpContinueAction => _t('Үргэлжлүүлэх', 'Continue');
  String get walletTopUpOpenCheckoutAction => _t('Төлбөрийн хуудас руу очих', 'Open checkout');
  String get walletTopUpWaitingTitle => _t('Төлбөр хүлээгдэж байна', 'Waiting for payment');
  String get walletTopUpWaitingBody => _t(
        'Төлбөрөө хийсний дараа энэ цонх автоматаар шинэчлэгдэнэ. Хаагаад дараа шалгаж болно.',
        'This will update automatically once your payment completes. You can also close it and check later.',
      );
  String get walletTopUpCheckStatusAction => _t('Шалгах', 'Check now');
  String get walletTopUpMockNotice => _t(
        'Тест горим — жинхэнэ wire.mn төлбөр хийгдэхгүй.',
        'Test mode — no real wire.mn payment will be made.',
      );
  String get walletTopUpMockConfirmAction =>
      _t('Тест төлбөрийг баталгаажуулах', 'Simulate payment success');
  String get walletTopUpSuccessMessage => _t('Хэтэвч амжилттай цэнэглэгдлээ', 'Wallet topped up');
  String get walletTopUpStillPendingMessage =>
      _t('Төлбөр хараахан баталгаажаагүй байна', 'Payment hasn\'t been confirmed yet');
  String get walletTopUpFailedMessage => _t('Цэнэглэлт амжилтгүй боллоо', 'Top-up failed');

  String get payoutStatusPending => _t('Хүлээгдэж буй', 'Pending');
  String get payoutStatusProcessing => _t('Боловсруулж байна', 'Processing');
  String get payoutStatusPaid => _t('Төлөгдсөн', 'Paid');
  String get payoutStatusFailed => _t('Амжилтгүй', 'Failed');

  // Chat (Phase 8, spec sections 23, 32 — text-only this phase, see
  // supabase/migrations/0009_chat_notifications.sql).
  String get bookingMessageAction => _t('Мессеж бичих', 'Message');
  String get chatTitle => _t('Чат', 'Chat');
  String get chatComposerHint => _t('Мессеж бичих...', 'Write a message...');
  String get chatEmptyTitle =>
      _t('Мессеж алга байна. Эхлээд бичээрэй!', 'No messages yet. Say hello!');
  String get chatFlaggedNotice => _t(
        'Анхаар: платформоос гадуур төлбөр хийхийг зөвлөдөггүй',
        'Note: paying off-platform is not recommended',
      );

  // Notifications (Phase 8, spec section 24 — in-app only, no push; see
  // AppNotification's header comment).
  String get notificationsTitle => _t('Мэдэгдэл', 'Notifications');
  String get notificationsMarkAllReadAction => _t('Бүгдийг уншсан', 'Mark all read');
  String get notificationsEmptyTitle => _t('Мэдэгдэл алга байна.', 'No notifications yet.');
  String get notificationNewMessageTitle => _t('Шинэ мессеж', 'New message');
  String get notificationNewMessageBody => _t('Танд шинэ мессеж ирлээ', 'You have a new message');
  String get notificationBookingPendingTitle =>
      _t('Шинэ захиалгын хүсэлт', 'New booking request');
  String get notificationBookingConfirmedTitle =>
      _t('Захиалга баталгаажлаа', 'Booking confirmed');
  String get notificationBookingRejectedTitle =>
      _t('Захиалга татгалзагдлаа', 'Booking rejected');
  String get notificationBookingCancelledTitle =>
      _t('Захиалга цуцлагдлаа', 'Booking cancelled');
  String get notificationPaymentSucceededTitle =>
      _t('Төлбөр амжилттай хийгдлээ', 'Payment successful');
  String get notificationPaymentReceivedTitle =>
      _t('Төлбөр хүлээн авлаа', 'Payment received');
  String get notificationPaymentFailedTitle => _t('Төлбөр амжилтгүй боллоо', 'Payment failed');

  // Rental lifecycle (Phase 9, spec sections 25, 26, 27 — pickup/return
  // condition reports, reviews, disputes; see
  // supabase/migrations/0010_condition_reports_reviews_disputes.sql).
  String get rentalLifecycleSectionTitle => _t('Түрээсийн явц', 'Rental progress');

  String get conditionReportPickupTitle => _t('Хүлээлгэн өгөх тэмдэглэл', 'Pickup report');
  String get conditionReportReturnTitle => _t('Буцаах тэмдэглэл', 'Return report');
  String get conditionReportPickupIntro => _t(
        'Хөрөнгийг хүлээлгэн өгөхийн өмнөх байдлыг зурган болон тэмдэглэлээр баримтжуулна уу.',
        'Document the item\'s condition before handing it over — photos and notes.',
      );
  String get conditionReportReturnIntro => _t(
        'Хөрөнгийг буцааж хүлээн авах үеийн байдлыг зурган болон тэмдэглэлээр баримтжуулна уу.',
        'Document the item\'s condition when it comes back — photos and notes.',
      );
  String get conditionReportPhotosLabel => _t('Зураг (сонголт)', 'Photos (optional)');
  String get conditionReportNotesLabel => _t('Тэмдэглэл', 'Notes');
  String get conditionReportNotesHint =>
      _t('Хөрөнгийн байдлын талаар тэмдэглэл...', 'Notes about the item\'s condition...');
  String get conditionReportSubmitAction => _t('Илгээх', 'Submit');
  String get conditionReportConfirmAction => _t('Баталгаажуулах', 'Confirm');
  String get conditionReportNotSubmittedYet => _t('Тэмдэглэгдээгүй байна', 'Not reported yet');
  String get conditionReportAwaitingYourConfirmation =>
      _t('Таны баталгаажуулалтыг хүлээж байна', 'Awaiting your confirmation');
  String get conditionReportWaitingOnOtherPartyNotice =>
      _t('Нөгөө талын баталгаажуулалтыг хүлээж байна', 'Waiting on the other party to confirm');
  String get conditionReportFullyConfirmedNotice =>
      _t('Хоёр тал баталгаажууллаа', 'Confirmed by both parties');
  String get conditionReportRenterConfirmationLabel =>
      _t('Түрээслэгчийн баталгаажуулалт', 'Renter confirmation');
  String get conditionReportOwnerConfirmationLabel =>
      _t('Эзэмшигчийн баталгаажуулалт', 'Owner confirmation');

  String get reviewScreenTitle => _t('Үнэлгээ үлдээх', 'Leave a review');
  String reviewForCounterpartyLabel(String name) =>
      _t('$name-д үнэлгээ өгөх', 'Reviewing $name');
  String get reviewCategoriesLabel => _t('Ангилал тус бүрээр', 'By category');
  String get reviewCategoryCommunication => _t('Харилцаа холбоо', 'Communication');
  String get reviewCategoryAccuracy => _t('Мэдээллийн үнэн зөв байдал', 'Accuracy');
  String get reviewCategoryCondition => _t('Хөрөнгийн байдал', 'Item condition');
  String get reviewCommentLabel => _t('Сэтгэгдэл (сонголт)', 'Comment (optional)');
  String get reviewCommentHint => _t('Туршлагаа хуваалцаарай...', 'Share your experience...');
  String get reviewSubmitAction => _t('Үнэлгээ илгээх', 'Submit review');
  String get reviewSubmittedMessage => _t('Үнэлгээ илгээгдлээ. Баярлалаа!', 'Review submitted — thank you!');
  String get reviewNotLeftYetNotice => _t('Үнэлгээ үлдээгээгүй байна', 'Not reviewed yet');
  String get reviewAlreadyLeftNotice => _t('Та үнэлгээ өглөө', 'You reviewed this rental');

  String get disputeScreenTitle => _t('Маргаан', 'Dispute');
  String get disputeIntro => _t(
        'Асуудал гарсан бол доор дэлгэрэнгүй бичээд илгээнэ үү. Захиалгын байдал "Маргаантай" болж, зохицуулагч шийдвэрлэх хүртэл зогсоно.',
        'If something went wrong, describe it below. The booking will be marked "Disputed" until this is resolved.',
      );
  String get disputeCategoryLabel => _t('Ангилал', 'Category');
  String get disputeCategoryItemDamaged => _t('Хөрөнгө гэмтсэн', 'Item damaged');
  String get disputeCategoryItemNotAsDescribed =>
      _t('Тайлбартай тохирохгүй байсан', 'Item not as described');
  String get disputeCategoryLateReturn => _t('Хугацаандаа буцаагаагүй', 'Late return');
  String get disputeCategoryNoShow => _t('Ирээгүй', 'No-show');
  String get disputeCategoryPaymentIssue => _t('Төлбөрийн асуудал', 'Payment issue');
  String get disputeCategoryOther => _t('Бусад', 'Other');
  String get disputeDescriptionLabel => _t('Тайлбар', 'Description');
  String get disputeDescriptionHint => _t('Юу болсныг тайлбарлана уу...', 'Describe what happened...');
  String get disputeDescriptionRequiredError => _t('Тайлбар оруулна уу', 'Please add a description');
  String get disputeEvidenceLabel => _t('Нотлох баримт (сонголт)', 'Evidence (optional)');
  String get disputeSubmitAction => _t('Маргаан үүсгэх', 'Submit dispute');
  String get disputeResolutionNotesLabel => _t('Зохицуулагчийн тэмдэглэл', 'Resolution notes');
  String get disputeNotRaisedNotice => _t('Маргаан үүсээгүй байна', 'No dispute raised');
  String get disputeStatusOpen => _t('Нээлттэй', 'Open');
  String get disputeStatusUnderReview => _t('Хянагдаж байна', 'Under review');
  String get disputeStatusResolved => _t('Шийдэгдсэн', 'Resolved');
  String get disputeStatusRejected => _t('Татгалзсан', 'Rejected');
  String get disputeStatusEscalated => _t('Дээшлүүлсэн', 'Escalated');

  String get myReviewsEmptyTitle => _t('Одоогоор үнэлгээ алга байна.', 'No reviews yet.');

  // AI listing assistant (Phase 10, spec sections 14, 51 — mock only, see
  // supabase/functions/suggest-listing-from-photo's header comment).
  String get assetCreateAiSuggestAction => _t('AI-аар санал авах', 'Get AI suggestion');
  String get assetCreateAiSuggestionMockDisclaimer => _t(
        'MOCK: зурган дахь зүйлийг таньдаггүй — зөвхөн бөглөх загвар санал болгоно.',
        'MOCK — doesn\'t recognize what\'s in your photo, just suggests a template to fill in.',
      );
  String get assetCreateAiSuggestionAppliedMessage =>
      _t('AI-н санал ашиглагдлаа. Шалгаад засаарай.', 'AI suggestion applied — review and edit it.');
  String get assetCreateSuggestedSpecFieldsLabel =>
      _t('Бөглөвөл зохих талбарууд:', 'Fields worth filling in:');

  // Admin dashboard (Phase 11, spec sections 22, 29, 30, 34 — see
  // supabase/migrations/0012_admin_dashboard.sql). Only shown to users
  // present in `public.admin_users` — see `isAdminProvider`.
  String get profileAdminAction => _t('Админ самбар', 'Admin dashboard');
  String get adminDashboardTitle => _t('Админ самбар', 'Admin dashboard');

  String get adminAssetModerationTitle => _t('Хөрөнгийн хяналт', 'Asset moderation');
  String get adminAssetModerationSubtitle =>
      _t('Шинэ зарууд болон нийтлэгдсэн хөрөнгийг хянах', 'Review new listings and published assets');
  String get adminAssetModerationEmptyTitle =>
      _t('Хяналт хийх зар алга байна', 'Nothing waiting on moderation');

  String get adminDisputeQueueTitle => _t('Маргаанууд', 'Disputes');
  String get adminDisputeQueueSubtitle =>
      _t('Нээлттэй маргааныг шийдвэрлэх', 'Resolve open disputes');
  String get adminDisputeQueueEmptyTitle => _t('Нээлттэй маргаан алга байна', 'No open disputes');

  String get adminPayoutQueueTitle => _t('Мөнгө татан авалт', 'Payouts');
  String get adminPayoutQueueSubtitle =>
      _t('Хүлээгдэж буй татан авалтыг боловсруулах', 'Process pending payout requests');
  String get adminPayoutQueueEmptyTitle =>
      _t('Боловсруулах татан авалт алга байна', 'No payouts waiting on you');

  String get adminReportQueueTitle => _t('Гомдлууд', 'Reports');
  String get adminReportQueueSubtitle =>
      _t('Зөрчлийн мэдээллийг хянах', 'Review abuse/content reports');
  String get adminReportQueueEmptyTitle => _t('Нээлттэй гомдол алга байна', 'No open reports');

  String get adminCommissionSettingsTitle => _t('Шимтгэлийн тохиргоо', 'Commission settings');
  String get adminCommissionSettingsSubtitle =>
      _t('Платформын шимтгэлийн хувийг тохируулах', 'Set the platform commission rate');

  String get adminAssetStatusDraft => _t('Ноорог', 'Draft');
  String get adminAssetStatusPendingReview => _t('Хянагдаж байна', 'Pending review');
  String get adminAssetStatusPublished => _t('Нийтлэгдсэн', 'Published');
  String get adminAssetStatusSuspended => _t('Түдгэлзүүлсэн', 'Suspended');
  String get adminAssetStatusArchived => _t('Архивласан', 'Archived');

  String get adminReportStatusOpen => _t('Нээлттэй', 'Open');
  String get adminReportStatusReviewed => _t('Хянасан', 'Reviewed');
  String get adminReportStatusActioned => _t('Арга хэмжээ авсан', 'Actioned');
  String get adminReportStatusDismissed => _t('Няцаасан', 'Dismissed');

  String get adminReportTargetUser => _t('Хэрэглэгч', 'User');
  String get adminReportTargetAsset => _t('Зар', 'Asset');
  String get adminReportTargetMessage => _t('Мессеж', 'Message');
  String get adminReportTargetReview => _t('Сэтгэгдэл', 'Review');

  String get adminReasonRequiredError => _t('Шалтгаан оруулна уу', 'Please add a reason');
  String get adminReasonLabel => _t('Шалтгаан', 'Reason');
  String get adminConfirmAction => _t('Баталгаажуулах', 'Confirm');

  String get adminRejectAssetTitle => _t('Зар татгалзах', 'Reject listing');
  String get adminRejectAssetReasonHint =>
      _t('Яагаад татгалзаж буйгаа тайлбарлана уу...', 'Explain why this is being rejected...');
  String get adminSuspendAssetTitle => _t('Зар түдгэлзүүлэх', 'Suspend listing');
  String get adminSuspendAssetReasonHint =>
      _t('Яагаад түдгэлзүүлж буйгаа тайлбарлана уу...', 'Explain why this is being suspended...');
  String adminModerationNoteLabel(String note) => _t('Тэмдэглэл: $note', 'Note: $note');

  String get adminRejectAction => _t('Татгалзах', 'Reject');
  String get adminApproveAction => _t('Зөвшөөрөх', 'Approve');
  String get adminSuspendAction => _t('Түдгэлзүүлэх', 'Suspend');
  String get adminResolveAction => _t('Шийдвэрлэх', 'Resolve');

  String get adminResolveDisputeTitle => _t('Маргаан шийдвэрлэх', 'Resolve dispute');
  String get adminResolutionNotesHint =>
      _t('Шийдвэрийн тухай тэмдэглэл (сонголт)...', 'Notes about the resolution (optional)...');

  // Booking payment refund (0018_security_and_consistency_hardening.sql,
  // admin_refund_booking_payment) — a separate, explicit action from
  // resolving the dispute itself, since not every dispute resolves in
  // the renter's favor.
  String get adminRefundRenterAction => _t('Түрээслэгчид буцаах', 'Refund renter');
  String get adminRefundBookingTitle => _t('Төлбөр буцаах', 'Refund booking payment');
  String get adminRefundReasonHint =>
      _t('Буцаалтын шалтгаан (сонголт)...', 'Reason for the refund (optional)...');
  String get adminRefundConfirmMessage => _t(
        'Түрээслэгчийн төлсөн мөнгийг бүтнээр нь буцааж, эзэмшигчээс тухайн орлогыг буцаан авна. Энэ үйлдлийг буцаах боломжгүй.',
        'This returns the renter\'s full payment and claws the corresponding amount back from the owner. This action cannot be undone.',
      );
  String get adminRefundSuccessMessage => _t('Төлбөр амжилттай буцаагдлаа', 'Payment refunded');
  String get adminRefundNoPaidPaymentError =>
      _t('Энэ захиалгад төлөгдсөн төлбөр алга', 'This booking has no paid payment');
  String get adminRefundAlreadyRefundedError => _t('Аль хэдийн буцаагдсан', 'Already refunded');
  String get adminRefundOwnerBalanceInsufficientError => _t(
        'Эзэмшигч мөнгөө аль хэдийн татсан тул автоматаар буцаах боломжгүй — гараар шийднэ үү',
        'The owner has already withdrawn the funds — this needs manual reconciliation',
      );

  String get adminMarkPayoutPaidTitle => _t('Төлөгдсөн гэж тэмдэглэх', 'Mark as paid');
  String get adminDestinationReferenceLabel =>
      _t('Гүйлгээний дугаар (сонголт)', 'Destination reference (optional)');
  String get adminDestinationReferenceHint => _t('Банкны гүйлгээний дугаар...', 'Bank transfer reference...');
  String get adminMarkProcessingAction => _t('Боловсруулж эхлэх', 'Start processing');
  String get adminMarkPaidAction => _t('Төлөгдсөн', 'Mark paid');

  String get adminInvalidCommissionError =>
      _t('0-100 хооронд тоо оруулна уу', 'Enter a number between 0 and 100');
  String get adminCommissionUpdatedMessage =>
      _t('Шимтгэлийн хувь шинэчлэгдлээ', 'Commission rate updated');
  String adminCommissionCurrentLabel(String percent) =>
      _t('Одоогийн шимтгэл: $percent%', 'Current commission: $percent%');
  String get adminCommissionPercentLabel => _t('Шимтгэлийн хувь', 'Commission percent');
  String get adminSaveAction => _t('Хадгалах', 'Save');

  // Promotions (Phase 12, spec section 30 — see
  // supabase/migrations/0013_security_perf_hardening.sql). Admin-authoring
  // only; there's still no consumer-facing "apply a promo code" flow.
  String get adminPromotionsTitle => _t('Урамшуулал', 'Promotions');
  String get adminPromotionsSubtitle =>
      _t('Урамшууллын код удирдах', 'Manage promotional codes');
  String get adminPromotionsEmptyTitle => _t('Урамшуулал алга байна', 'No promotions yet');
  String get adminAddPromotionAction => _t('Урамшуулал нэмэх', 'Add promotion');
  String get adminDeactivateAction => _t('Идэвхгүй болгох', 'Deactivate');
  String get adminPromotionStatusInactive => _t('Идэвхгүй', 'Inactive');
  String get adminPromotionCreateTitle => _t('Урамшуулал нэмэх', 'New promotion');
  String get adminPromotionEditTitle => _t('Урамшуулал засах', 'Edit promotion');
  String get adminPromotionTitleLabel => _t('Гарчиг', 'Title');
  String get adminPromotionCodeLabel => _t('Код (сонголт)', 'Code (optional)');
  String get adminPromotionDescriptionLabel => _t('Тайлбар (сонголт)', 'Description (optional)');
  String get adminPromotionDiscountLabel => _t('Хөнгөлөлт (сонголт)', 'Discount (optional)');
  String get adminPromotionDateRangeLabel => _t('Хугацаа', 'Date range');
  String get adminPromotionPickDatesAction => _t('Огноо сонгох', 'Pick dates');
  String get adminPromotionActiveLabel => _t('Идэвхтэй', 'Active');
  String get adminPromotionTitleRequiredError => _t('Гарчиг оруулна уу', 'Please add a title');
  String get adminPromotionInvalidDateRangeError =>
      _t('Дуусах огноо эхлэх огнооноос хойш байх ёстой', 'End date must be after start date');

  // App-open banners (supabase/migrations/0023_app_banners.sql) — admin
  // uploads images shown in a rotating popup the first time Home renders
  // after app open. No tap-through action; closing/swiping is the only
  // interaction (see `app_banner_popup.dart`).
  String get adminBannersTitle => _t('Баннер', 'Banners');
  String get adminBannersSubtitle =>
      _t('Апп нээхэд гарах баннер удирдах', 'Manage the app-open banner');
  String get adminBannersEmptyTitle => _t('Баннер алга байна', 'No banners yet');
  String get adminAddBannerAction => _t('Баннер нэмэх', 'Add banner');
  String get adminBannerCreateTitle => _t('Баннер нэмэх', 'New banner');
  String get adminBannerEditTitle => _t('Баннер засах', 'Edit banner');
  String get adminBannerImageLabel => _t('Зураг', 'Image');
  String get adminBannerPickImageAction => _t('Зураг сонгох', 'Pick image');
  String get adminBannerReplaceImageAction => _t('Зураг солих', 'Replace image');
  String get adminBannerImageRequiredError => _t('Зураг сонгоно уу', 'Please pick an image');
  String get adminBannerSortOrderLabel => _t('Дараалал', 'Sort order');
  String get adminBannerActiveLabel => _t('Идэвхтэй', 'Active');
  String get adminBannerStatusActive => _t('Идэвхтэй', 'Active');
  String get adminBannerStatusInactive => _t('Идэвхгүй', 'Inactive');
  String get adminBannerDeleteAction => _t('Устгах', 'Delete');
  String get adminBannerDeleteConfirmTitle => _t('Баннер устгах уу?', 'Delete this banner?');
  String get adminBannerDeleteConfirmMessage => _t(
        'Энэ баннерыг устгавал буцаах боломжгүй.',
        'This banner will be permanently deleted.',
      );

  // Manual trigger for `reconcile-wire-topups` (see that Edge Function's
  // header comment, and README's "Known issues") — an admin can run it
  // on demand instead of/in addition to whatever schedule the deployment
  // has set up for it.
  String get adminReconcileWireTopupsTitle => _t('Wire дахин шалгах', 'Reconcile wire.mn top-ups');
  String get adminReconcileWireTopupsSubtitle => _t(
        'Зогсонги цэнэглэлтүүдийг wire.mn-тэй тулгах',
        'Check stuck top-ups against wire.mn',
      );
  String get adminReconcileWireTopupsConfirmMessage => _t(
        'Удаан хугацаанд "хүлээгдэж буй" төлөвтэй үлдсэн wire.mn цэнэглэлтүүдийг тухайн үйлчилгээнээс шалгаж, шаардлагатай бол хэтэвчид мөнгө орлогод авах эсвэл амжилтгүй гэж тэмдэглэнэ.',
        'Checks wallet top-ups still stuck "pending" against wire.mn itself, crediting the wallet or marking them failed as needed.',
      );
  String adminReconcileWireTopupsResultMessage(int checked, int credited, int markedFailed) => _t(
        'Шалгасан: $checked, орлогод авсан: $credited, амжилтгүй гэж тэмдэглэсэн: $markedFailed.',
        'Checked: $checked, credited: $credited, marked failed: $markedFailed.',
      );

  // Client-facing "report abuse" entry points (spec sections 26, 30) —
  // the backend (`reports` table, `reports_insert_own` RLS,
  // `admin_resolve_report`) existed since Phase 0/1 with no client UI
  // ever wired to actually create one; added in the post-wallet-
  // integration hardening pass. `reason` is stored as whichever of the
  // fixed options below the reporter picked (in their current app
  // locale) — freeform on the schema side, fixed-choice on the client,
  // same pattern `DisputeCategory`/`ReviewCategory` use for their own
  // nominally-freeform columns.
  String get reportAction => _t('Гомдол мэдэгдэх', 'Report');
  String reportSheetTitle(String targetTypeLabel) => _t('$targetTypeLabel мэдэгдэх', 'Report $targetTypeLabel');
  String get reportReasonLabel => _t('Шалтгаан', 'Reason');
  String get reportReasonInappropriateContent =>
      _t('Зохисгүй/хортой агуулга', 'Inappropriate or harmful content');
  String get reportReasonFraud => _t('Луйвар, хууран мэхлэлт', 'Fraud or scam');
  String get reportReasonHarassment => _t('Дорд үзэх, ёс зүйгүй харилцаа', 'Harassment or abuse');
  String get reportReasonMisleadingListing =>
      _t('Худал/төөрөгдүүлсэн мэдээлэл', 'Fake or misleading listing');
  String get reportReasonOther => _t('Бусад', 'Other');
  String get reportDetailsLabel => _t('Дэлгэрэнгүй (сонголт)', 'Details (optional)');
  String get reportDetailsHint =>
      _t('Юу болсныг товч тайлбарлана уу...', 'Briefly describe what happened...');
  String get reportDetailsRequiredForOtherError =>
      _t('"Бусад"-ыг сонгосон бол дэлгэрэнгүй бичнэ үү', 'Please add details when choosing "Other"');
  String get reportSubmitAction => _t('Илгээх', 'Submit');
  String get reportSubmittedMessage =>
      _t('Гомдлыг хүлээн авлаа — баг тантай холбогдоно', 'Report submitted — our team will review it');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
