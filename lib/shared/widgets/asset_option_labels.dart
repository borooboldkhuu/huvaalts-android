import '../../app/localization/app_localizations.dart';

/// Localized labels for the small fixed vocabularies used on both the
/// asset create form and the asset detail screen (condition, pickup
/// method) — kept in one place so the two screens can't drift on what a
/// given stored value displays as.
String conditionLabel(String? condition, AppLocalizations l10n) {
  return switch (condition) {
    'new' => l10n.conditionNew,
    'like_new' => l10n.conditionLikeNew,
    'good' => l10n.conditionGood,
    'fair' => l10n.conditionFair,
    _ => l10n.conditionGood,
  };
}

String pickupMethodLabel(String? pickupMethod, AppLocalizations l10n) {
  return switch (pickupMethod) {
    'pickup' => l10n.pickupMethodPickup,
    'delivery' => l10n.pickupMethodDelivery,
    'both' => l10n.pickupMethodBoth,
    _ => l10n.pickupMethodPickup,
  };
}
