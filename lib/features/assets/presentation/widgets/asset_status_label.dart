import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/asset_status.dart';

/// Shared by both `MyAssetsScreen`'s owner-facing status badge and the
/// admin feature's moderation queue — one status vocabulary, not two.
/// The l10n getters keep their `admin`-prefixed names (`adminAssetStatus*`)
/// from when this lived under `features/admin` only; renaming them now
/// would touch every admin screen for a purely cosmetic identifier change,
/// so this file just re-documents that they're shared rather than
/// admin-only.
String assetStatusLabel(AssetStatus status, AppLocalizations l10n) {
  return switch (status) {
    AssetStatus.draft => l10n.adminAssetStatusDraft,
    AssetStatus.pendingReview => l10n.adminAssetStatusPendingReview,
    AssetStatus.published => l10n.adminAssetStatusPublished,
    AssetStatus.suspended => l10n.adminAssetStatusSuspended,
    AssetStatus.archived => l10n.adminAssetStatusArchived,
  };
}

Color assetStatusColor(AssetStatus status, AppColors colors) {
  return switch (status) {
    AssetStatus.draft => colors.secondary,
    AssetStatus.pendingReview => colors.warning,
    AssetStatus.published => colors.success,
    AssetStatus.suspended => colors.danger,
    AssetStatus.archived => colors.secondary,
  };
}
