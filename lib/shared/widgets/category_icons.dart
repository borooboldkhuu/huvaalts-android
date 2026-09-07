import 'package:flutter/material.dart';

import '../../core/constants/asset_categories.dart';

/// Glyph shown for each [AssetCategory] in the category chip row (see
/// `CategoryChipRow`) — the single source both Home/Search's chip row and
/// anywhere else a category needs an icon should pull from, so a
/// category's glyph can't drift between the two places it's shown.
IconData categoryIcon(AssetCategory category) {
  return switch (category) {
    AssetCategory.all => Icons.apps_rounded,
    AssetCategory.camera => Icons.camera_alt_rounded,
    AssetCategory.drone => Icons.airplanemode_active_rounded,
    AssetCategory.electronics => Icons.computer_rounded,
    AssetCategory.gaming => Icons.sports_esports_rounded,
    AssetCategory.audio => Icons.headphones_rounded,
    AssetCategory.projector => Icons.slideshow_rounded,
    AssetCategory.event => Icons.celebration_rounded,
    AssetCategory.tools => Icons.handyman_rounded,
    AssetCategory.travel => Icons.hiking_rounded,
    AssetCategory.sports => Icons.fitness_center_rounded,
    AssetCategory.vehicle => Icons.directions_car_filled_rounded,
    AssetCategory.household => Icons.chair_rounded,
    AssetCategory.office => Icons.business_center_rounded,
    AssetCategory.kids => Icons.child_care_rounded,
    AssetCategory.fashion => Icons.checkroom_rounded,
    AssetCategory.construction => Icons.construction_rounded,
    AssetCategory.other => Icons.category_rounded,
  };
}
