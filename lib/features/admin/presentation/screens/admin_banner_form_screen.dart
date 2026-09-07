import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/entities/app_banner.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../controllers/admin_banner_form_controller.dart';

/// Create a new app-open banner, or edit an existing one when [existing]
/// is passed via `GoRouterState.extra` (see `AdminBannersScreen`'s
/// `_BannerCard.onTap`). One form for both, same reasoning as
/// `AdminPromotionFormScreen`.
class AdminBannerFormScreen extends ConsumerStatefulWidget {
  const AdminBannerFormScreen({this.existing, super.key});

  final AppBanner? existing;

  @override
  ConsumerState<AdminBannerFormScreen> createState() => _AdminBannerFormScreenState();
}

class _AdminBannerFormScreenState extends ConsumerState<AdminBannerFormScreen> {
  late final TextEditingController _sortOrderController =
      TextEditingController(text: (widget.existing?.sortOrder ?? 0).toString());
  late bool _isActive = widget.existing?.isActive ?? true;

  String? _imageError;

  @override
  void dispose() {
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    await ref.read(adminBannerFormControllerProvider.notifier).pickImage();
    if (mounted) setState(() => _imageError = null);
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isEditing = widget.existing != null;
    final Uint8List? pickedBytes = ref.read(adminBannerFormControllerProvider).pickedImageBytes;

    if (!isEditing && pickedBytes == null) {
      setState(() => _imageError = l10n.adminBannerImageRequiredError);
      return;
    }
    setState(() => _imageError = null);

    final int sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;

    try {
      await ref.read(adminBannerFormControllerProvider.notifier).submit(
            id: widget.existing?.id,
            existingStoragePath: widget.existing?.storagePath,
            sortOrder: sortOrder,
            isActive: _isActive,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        final (_, message) = failurePresentation(Failure.from(error), l10n);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AdminBannerFormState formState = ref.watch(adminBannerFormControllerProvider);
    final bool isEditing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.adminBannerEditTitle : l10n.adminBannerCreateTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(l10n.adminBannerImageLabel, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          _BannerImagePreview(
            pickedBytes: formState.pickedImageBytes,
            existingImageUrl: widget.existing?.imageUrl,
            onTap: _pickImage,
          ),
          if (_imageError != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(_imageError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.image_outlined),
            label: Text(
              formState.pickedImageBytes != null || widget.existing != null
                  ? l10n.adminBannerReplaceImageAction
                  : l10n.adminBannerPickImageAction,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _sortOrderController,
            label: l10n.adminBannerSortOrderLabel,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.lg),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.adminBannerActiveLabel),
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: l10n.adminSaveAction,
            isLoading: formState.isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _BannerImagePreview extends StatelessWidget {
  const _BannerImagePreview({
    required this.pickedBytes,
    required this.existingImageUrl,
    required this.onTap,
  });

  final Uint8List? pickedBytes;
  final String? existingImageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // 2:1 mirrors the popup's own aspect ratio (`app_banner_popup.dart`),
    // so what the admin previews here is what users actually see.
    return AspectRatio(
      aspectRatio: 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          child: InkWell(
            onTap: onTap,
            child: pickedBytes != null
                ? Image.memory(pickedBytes!, fit: BoxFit.cover, width: double.infinity)
                : existingImageUrl != null
                    ? Image.network(existingImageUrl!, fit: BoxFit.cover, width: double.infinity)
                    : Center(
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 40,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
          ),
        ),
      ),
    );
  }
}
