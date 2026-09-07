import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/category_chip_row.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../../core/constants/asset_categories.dart';
import '../../../assets/domain/entities/asset_search_filters.dart';

/// Filter/sort bottom sheet (spec sections 5 "dynamic bottom sheets", 12).
/// Returns the edited [AssetSearchFilters] via `Navigator.pop`, or `null`
/// if dismissed without applying — the caller (SearchScreen) only acts on
/// a non-null result.
Future<AssetSearchFilters?> showSearchFilterSheet(
  BuildContext context, {
  required AssetSearchFilters current,
}) {
  return showModalBottomSheet<AssetSearchFilters>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SearchFilterSheet(initial: current),
  );
}

class _SearchFilterSheet extends StatefulWidget {
  const _SearchFilterSheet({required this.initial});

  final AssetSearchFilters initial;

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  late AssetCategory? _category;
  late bool _verifiedOnly;
  late AssetSortOption _sort;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;

  @override
  void initState() {
    super.initState();
    _category = widget.initial.categoryId == null
        ? null
        : AssetCategory.fromId(widget.initial.categoryId!);
    _verifiedOnly = widget.initial.verifiedOwnersOnly;
    _sort = widget.initial.sort;
    _minPriceController = TextEditingController(
      text: widget.initial.minPrice?.toStringAsFixed(0) ?? '',
    );
    _maxPriceController = TextEditingController(
      text: widget.initial.maxPrice?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.searchFilters, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),
              CategoryChipRow(
                selected: _category,
                onSelected: (category) => setState(() => _category = category),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(l10n.filterPriceRange, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minPriceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(hintText: l10n.filterMinPrice),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _maxPriceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(hintText: l10n.filterMaxPrice),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.filterVerifiedOwnersOnly),
                value: _verifiedOnly,
                onChanged: (value) => setState(() => _verifiedOnly = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.searchSortLabel, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final option in const [
                    AssetSortOption.recommended,
                    AssetSortOption.newest,
                    AssetSortOption.cheapest,
                    AssetSortOption.mostExpensive,
                    AssetSortOption.highestRated,
                    AssetSortOption.closest,
                  ])
                    ChoiceChip(
                      label: Text(_sortLabel(option, l10n)),
                      selected: _sort == option,
                      onSelected: (_) => setState(() => _sort = option),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: l10n.filterClear,
                      onPressed: () => Navigator.of(context).pop(const AssetSearchFilters()),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: PrimaryButton(
                      label: l10n.filterApply,
                      onPressed: () => Navigator.of(context).pop(_buildFilters()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  AssetSearchFilters _buildFilters() {
    final double? min = double.tryParse(_minPriceController.text);
    final double? max = double.tryParse(_maxPriceController.text);
    return widget.initial.copyWith(
      categoryId: _category?.id,
      clearCategory: _category == null,
      minPrice: min,
      clearMinPrice: min == null,
      maxPrice: max,
      clearMaxPrice: max == null,
      verifiedOwnersOnly: _verifiedOnly,
      sort: _sort,
    );
  }

  String _sortLabel(AssetSortOption option, AppLocalizations l10n) {
    return switch (option) {
      AssetSortOption.recommended => l10n.sortRecommended,
      AssetSortOption.cheapest => l10n.sortCheapest,
      AssetSortOption.mostExpensive => l10n.sortMostExpensive,
      AssetSortOption.closest => l10n.sortClosest,
      AssetSortOption.highestRated => l10n.sortHighestRated,
      AssetSortOption.newest => l10n.sortNewest,
      AssetSortOption.mostViewed => l10n.sortRecommended,
      AssetSortOption.mostFavorited => l10n.sortRecommended,
    };
  }
}
