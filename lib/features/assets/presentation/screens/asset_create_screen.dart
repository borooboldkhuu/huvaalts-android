import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/asset_categories.dart';
import '../../../../core/errors/failure.dart';
import '../../../../features/ai/domain/entities/listing_suggestion.dart';
import '../../../../features/ai/presentation/controllers/suggest_listing_controller.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/category_label.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/entities/new_asset_input.dart';
import '../controllers/asset_create_controller.dart';

/// Manual create-listing form (spec section 14), plus the Phase 10 AI
/// listing assistant on top of it — a "Get AI suggestion" action once at
/// least one photo is picked. That assistant is honestly mock (see
/// `SupabaseListingAssistantRepository`'s header comment): it prefills a
/// fill-in-the-blanks description and suggests spec *field names* to add,
/// it never invents a title/brand/model/category from a photo it never
/// actually looked at. This form works fully without it either way.
class AssetCreateScreen extends ConsumerStatefulWidget {
  const AssetCreateScreen({super.key});

  @override
  ConsumerState<AssetCreateScreen> createState() => _AssetCreateScreenState();
}

class _AssetCreateScreenState extends ConsumerState<AssetCreateScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _pricePerHourController = TextEditingController();
  final _pricePerDayController = TextEditingController();
  final _pricePerWeekController = TextEditingController();
  final _locationController = TextEditingController();
  final _newRuleController = TextEditingController();
  final _newSpecKeyController = TextEditingController();
  final _newSpecValueController = TextEditingController();

  AssetCategory? _category;
  String _condition = 'good';
  String _pickupMethod = 'pickup';
  bool _deliveryAvailable = false;
  final List<String> _rules = [];
  final Map<String, String> _specifications = {};
  List<String> _suggestedSpecFields = [];

  String? _titleError;
  String? _categoryError;
  String? _priceError;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _pricePerHourController.dispose();
    _pricePerDayController.dispose();
    _pricePerWeekController.dispose();
    _locationController.dispose();
    _newRuleController.dispose();
    _newSpecKeyController.dispose();
    _newSpecValueController.dispose();
    super.dispose();
  }

  double? _parsePrice(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed.replaceAll(',', ''));
  }

  Future<void> _handleAddPhotos() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    try {
      await ref.read(assetCreateControllerProvider.notifier).addImages();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.assetCreateImagePickError)));
    }
  }

  Future<void> _handleAiSuggest() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final images = ref.read(assetCreateControllerProvider).images;
    if (images.isEmpty) return;
    try {
      final ListingSuggestion suggestion =
          await ref.read(suggestListingControllerProvider.notifier).suggest(
                [for (final image in images) (image.bytes, image.fileExtension)],
              );
      if (!mounted) return;
      setState(() {
        if (_descriptionController.text.trim().isEmpty) {
          _descriptionController.text = suggestion.descriptionSuggestion;
        }
        _condition = suggestion.conditionSuggestion;
        _suggestedSpecFields = suggestion.suggestedSpecFields;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.assetCreateAiSuggestionAppliedMessage)));
    } catch (e) {
      if (!mounted) return;
      final (_, message) = failurePresentation(Failure.from(e), l10n);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _addRule() {
    final String value = _newRuleController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _rules.add(value);
      _newRuleController.clear();
    });
  }

  void _addSpec() {
    final String key = _newSpecKeyController.text.trim();
    final String value = _newSpecValueController.text.trim();
    if (key.isEmpty || value.isEmpty) return;
    setState(() {
      _specifications[key] = value;
      _newSpecKeyController.clear();
      _newSpecValueController.clear();
    });
  }

  Future<void> _handleSubmit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double? pricePerHour = _parsePrice(_pricePerHourController.text);
    final double? pricePerDay = _parsePrice(_pricePerDayController.text);
    final double? pricePerWeek = _parsePrice(_pricePerWeekController.text);
    // The database's own CHECK constraints (`price_per_hour >= 0`, etc.,
    // 0001_init_schema.sql) are the actual authority, but catching a
    // negative value here avoids a wasted round trip that would otherwise
    // surface as a generic "something went wrong" instead of a clear,
    // in-place field error.
    final bool hasNegativePrice = <double?>[pricePerHour, pricePerDay, pricePerWeek]
        .any((value) => value != null && value < 0);

    setState(() {
      _titleError = _titleController.text.trim().isEmpty ? l10n.assetCreateErrorTitleRequired : null;
      _categoryError = _category == null ? l10n.assetCreateErrorCategoryRequired : null;
      _priceError = (pricePerHour == null && pricePerDay == null && pricePerWeek == null)
          ? l10n.assetCreateErrorPriceRequired
          : hasNegativePrice
              ? l10n.assetCreateErrorPriceInvalid
              : null;
    });
    if (_titleError != null || _categoryError != null || _priceError != null) return;

    final NewAssetInput input = NewAssetInput(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      categoryId: _category!.id,
      brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
      model: _modelController.text.trim().isEmpty ? null : _modelController.text.trim(),
      condition: _condition,
      specifications: _specifications,
      pricePerHour: pricePerHour,
      pricePerDay: pricePerDay,
      pricePerWeek: pricePerWeek,
      pickupMethod: _pickupMethod,
      deliveryAvailable: _deliveryAvailable,
      locationLabel: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      rules: _rules,
    );

    try {
      final String id = await ref.read(assetCreateControllerProvider.notifier).submit(input);
      if (!mounted) return;
      ref.read(assetCreateControllerProvider.notifier).reset();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.assetCreateSuccess)));
      context.pushReplacementNamed(RouteNames.assetDetail, pathParameters: {'id': id});
    } catch (e) {
      if (!mounted) return;
      final (_, message) = failurePresentation(Failure.from(e), l10n);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final AssetCreateState createState = ref.watch(assetCreateControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addAssetAction)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _SectionLabel(l10n.assetCreateSectionPhotos, theme),
            const SizedBox(height: AppSpacing.sm),
            _PhotosPicker(
              images: createState.images,
              onAdd: _handleAddPhotos,
              onRemove: (i) => ref.read(assetCreateControllerProvider.notifier).removeImageAt(i),
              onReorder: (o, n) =>
                  ref.read(assetCreateControllerProvider.notifier).reorderImage(o, n),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                l10n.assetCreatePhotosHint(kMaxAssetPhotos),
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (createState.images.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _AiSuggestButton(onPressed: _handleAiSuggest),
              const SizedBox(height: 4),
              Text(
                l10n.assetCreateAiSuggestionMockDisclaimer,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            _SectionLabel(l10n.assetCreateSectionBasics, theme),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _titleController,
              label: l10n.assetCreateTitleLabel,
              hintText: l10n.assetCreateTitleHint,
              errorText: _titleError,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _descriptionController,
              label: l10n.assetCreateDescriptionLabel,
              hintText: l10n.assetCreateDescriptionHint,
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.assetCreateCategoryLabel, style: theme.textTheme.labelMedium),
            if (_categoryError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _categoryError!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final category in AssetCategory.values.where((c) => c != AssetCategory.all))
                  ChoiceChip(
                    label: Text(categoryLabel(category, l10n)),
                    selected: _category == category,
                    onSelected: (_) => setState(() {
                      _category = category;
                      _categoryError = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppTextField(controller: _brandController, label: l10n.assetCreateBrandLabel),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(controller: _modelController, label: l10n.assetCreateModelLabel),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.assetCreateConditionLabel, style: theme.textTheme.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              value: _condition,
              items: [
                DropdownMenuItem(value: 'new', child: Text(l10n.conditionNew)),
                DropdownMenuItem(value: 'like_new', child: Text(l10n.conditionLikeNew)),
                DropdownMenuItem(value: 'good', child: Text(l10n.conditionGood)),
                DropdownMenuItem(value: 'fair', child: Text(l10n.conditionFair)),
              ],
              onChanged: (value) => setState(() => _condition = value ?? _condition),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SectionLabel(l10n.assetCreateSectionSpecs, theme),
            const SizedBox(height: AppSpacing.sm),
            if (_suggestedSpecFields.isNotEmpty) ...[
              Text(l10n.assetCreateSuggestedSpecFieldsLabel, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final field in _suggestedSpecFields)
                    if (!_specifications.containsKey(field))
                      ActionChip(
                        label: Text(field),
                        onPressed: () => setState(() {
                          _newSpecKeyController.text = field;
                        }),
                      ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            for (final entry in _specifications.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(child: Text('${entry.key}: ${entry.value}')),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _specifications.remove(entry.key)),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _newSpecKeyController,
                    hintText: l10n.assetCreateSpecKeyHint,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    controller: _newSpecValueController,
                    hintText: l10n.assetCreateSpecValueHint,
                  ),
                ),
                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _addSpec),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SectionLabel(l10n.assetCreateSectionPricing, theme),
            const SizedBox(height: AppSpacing.sm),
            if (_priceError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  _priceError!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            AppTextField(
              controller: _pricePerHourController,
              label: l10n.assetCreatePricePerHourLabel,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              suffixText: '₮',
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _pricePerDayController,
              label: l10n.assetCreatePricePerDayLabel,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              suffixText: '₮',
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _pricePerWeekController,
              label: l10n.assetCreatePricePerWeekLabel,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              suffixText: '₮',
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SectionLabel(l10n.assetCreateSectionLogistics, theme),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.assetCreatePickupMethodLabel, style: theme.textTheme.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              value: _pickupMethod,
              items: [
                DropdownMenuItem(value: 'pickup', child: Text(l10n.pickupMethodPickup)),
                DropdownMenuItem(value: 'delivery', child: Text(l10n.pickupMethodDelivery)),
                DropdownMenuItem(value: 'both', child: Text(l10n.pickupMethodBoth)),
              ],
              onChanged: (value) => setState(() => _pickupMethod = value ?? _pickupMethod),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.assetCreateDeliveryAvailableLabel),
              value: _deliveryAvailable,
              onChanged: (value) => setState(() => _deliveryAvailable = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _locationController,
              label: l10n.assetCreateLocationLabel,
              hintText: l10n.assetCreateLocationHint,
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SectionLabel(l10n.assetCreateSectionRules, theme),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < _rules.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(child: Text('• ${_rules[i]}')),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _rules.removeAt(i)),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _newRuleController,
                    hintText: l10n.assetCreateRuleHint,
                  ),
                ),
                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _addRule),
              ],
            ),
            const SizedBox(height: AppSpacing.xxxl),
            PrimaryButton(
              label: l10n.assetCreateSubmit,
              isLoading: createState.isSubmitting,
              onPressed: _handleSubmit,
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _AiSuggestButton extends ConsumerWidget {
  const _AiSuggestButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isSubmitting = ref.watch(suggestListingControllerProvider).isSubmitting;

    return OutlinedButton.icon(
      onPressed: isSubmitting ? null : onPressed,
      icon: isSubmitting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_awesome_outlined, size: 18),
      label: Text(l10n.assetCreateAiSuggestAction),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.theme);

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: theme.textTheme.titleMedium);
  }
}

class _PhotosPicker extends StatelessWidget {
  const _PhotosPicker({
    required this.images,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
  });

  final List<PickedAssetImage> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool atLimit = images.length >= kMaxAssetPhotos;

    return SizedBox(
      height: 96,
      child: Row(
        children: [
          GestureDetector(
            onTap: atLimit ? null : onAdd,
            child: Opacity(
              opacity: atLimit ? 0.4 : 1,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: const Icon(Icons.add_photo_alternate_outlined),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (images.isNotEmpty)
            Expanded(
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                itemCount: images.length,
                onReorder: onReorder,
                itemBuilder: (context, index) {
                  // Keyed by the image object itself (not its index) so
                  // Flutter can track each thumbnail's identity correctly
                  // across reorders — an index-based key would make
                  // Flutter think the *content* at a position changed
                  // rather than the position of a given photo changing.
                  return ReorderableDragStartListener(
                    key: ObjectKey(images[index]),
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Image.memory(
                              images[index].bytes,
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => onRemove(index),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
