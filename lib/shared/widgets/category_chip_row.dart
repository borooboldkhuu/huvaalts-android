import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/constants/asset_categories.dart';
import 'category_icons.dart';
import 'category_label.dart';

/// Horizontal category selector used on Home and Search (spec section 11's
/// "Бүгд / Камер / Дрон / Gaming / ..." row) — a scrollable strip of
/// pill-shaped chips (icon + label side by side, filled solid when
/// selected), matching the 2026 reference redesign. A single source for
/// the category list + localized labels so Home and Search can never
/// drift out of sync with each other.
class CategoryChipRow extends StatelessWidget {
  const CategoryChipRow({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// `null` means "Бүгд / All".
  final AssetCategory? selected;
  final ValueChanged<AssetCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: AssetCategory.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final AssetCategory category = AssetCategory.values[index];
          final bool isAll = category == AssetCategory.all;
          final bool isSelected = isAll ? selected == null : selected == category;

          return CategoryAvatar(
            icon: categoryIcon(category),
            label: categoryLabel(category, l10n),
            isSelected: isSelected,
            onTap: () => onSelected(isAll ? null : category),
          );
        },
      ),
    );
  }
}

/// A single icon + label pill. Public (not private to this file) so other
/// category pickers — e.g. the asset create form's category field — can
/// reuse the exact same look. Kept the `CategoryAvatar` name across the
/// 2026 pill-shape redesign (was a circular icon-over-caption avatar)
/// since nothing about its public API (icon/label/isSelected/onTap)
/// changed — only its internal layout.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = context.colors;
    final Color fg = isSelected ? const Color(0xFF171717) : colors.onSurface;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        color: isSelected ? colors.accent : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: BorderSide(color: isSelected ? colors.accent : colors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
