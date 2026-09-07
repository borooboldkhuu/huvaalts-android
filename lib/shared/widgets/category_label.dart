import '../../app/localization/app_localizations.dart';
import '../../core/constants/asset_categories.dart';

/// Localized label for an [AssetCategory] — the single source both
/// [CategoryChipRow] (`category_chip_row.dart`) and the asset create form
/// use, so a category's display name can never drift between the two
/// places it's shown.
String categoryLabel(AssetCategory category, AppLocalizations l10n) {
  return switch (category) {
    AssetCategory.all => l10n.categoryAll,
    AssetCategory.camera => l10n.categoryCamera,
    AssetCategory.drone => l10n.categoryDrone,
    AssetCategory.electronics => l10n.categoryElectronics,
    AssetCategory.gaming => l10n.categoryGaming,
    AssetCategory.audio => l10n.categoryAudio,
    AssetCategory.projector => l10n.categoryProjector,
    AssetCategory.event => l10n.categoryEvent,
    AssetCategory.tools => l10n.categoryTools,
    AssetCategory.travel => l10n.categoryTravel,
    AssetCategory.sports => l10n.categorySports,
    AssetCategory.vehicle => l10n.categoryVehicle,
    AssetCategory.household => l10n.categoryHousehold,
    AssetCategory.office => l10n.categoryOffice,
    AssetCategory.kids => l10n.categoryKids,
    AssetCategory.fashion => l10n.categoryFashion,
    AssetCategory.construction => l10n.categoryConstruction,
    AssetCategory.other => l10n.categoryOther,
  };
}
