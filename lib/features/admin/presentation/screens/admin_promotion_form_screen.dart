import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/entities/promotion.dart';
import '../controllers/promotion_management_controller.dart';

/// Create a new promotion, or edit an existing one when [existing] is
/// passed via `GoRouterState.extra` (see `admin_promotions_screen.dart`'s
/// `_PromotionCard.onTap`). One form for both, same reasoning as
/// `admin_upsert_promotion` being one RPC — there's no meaningful
/// difference in what's being validated either way.
class AdminPromotionFormScreen extends ConsumerStatefulWidget {
  const AdminPromotionFormScreen({this.existing, super.key});

  final Promotion? existing;

  @override
  ConsumerState<AdminPromotionFormScreen> createState() => _AdminPromotionFormScreenState();
}

class _AdminPromotionFormScreenState extends ConsumerState<AdminPromotionFormScreen> {
  late final TextEditingController _codeController =
      TextEditingController(text: widget.existing?.code ?? '');
  late final TextEditingController _titleController =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.existing?.description ?? '');
  late final TextEditingController _discountController = TextEditingController(
    text: widget.existing?.discountPercent != null ? widget.existing!.discountPercent.toString() : '',
  );

  late DateTimeRange _range = widget.existing != null
      ? DateTimeRange(start: widget.existing!.startsAt, end: widget.existing!.endsAt)
      : DateTimeRange(start: DateTime.now(), end: DateTime.now().add(const Duration(days: 7)));
  late bool _isActive = widget.existing?.isActive ?? true;

  String? _titleError;
  String? _dateError;

  @override
  void dispose() {
    _codeController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final DateTime today = DateTime.now();
    // `showDateRangePicker` asserts `initialDateRange` falls inside
    // `[firstDate, lastDate]` — widen the bounds around whatever
    // `_range` already holds (e.g. an existing promotion that started
    // more than a year ago) instead of a fixed window that could clash
    // with it and crash the picker.
    final DateTime firstDate =
        _range.start.isBefore(today) ? _range.start.subtract(const Duration(days: 1)) : today.subtract(const Duration(days: 365));
    final DateTime lastDate =
        _range.end.isAfter(today.add(const Duration(days: 730)))
            ? _range.end.add(const Duration(days: 1))
            : today.add(const Duration(days: 730));
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() {
      _range = picked;
      _dateError = null;
    });
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = l10n.adminPromotionTitleRequiredError);
      return;
    }
    if (!_range.end.isAfter(_range.start)) {
      setState(() => _dateError = l10n.adminPromotionInvalidDateRangeError);
      return;
    }
    setState(() {
      _titleError = null;
      _dateError = null;
    });

    final double? discount = _discountController.text.trim().isEmpty
        ? null
        : double.tryParse(_discountController.text.trim());

    try {
      await ref.read(promotionManagementControllerProvider.notifier).upsert(
            id: widget.existing?.id,
            code: _codeController.text.trim().isEmpty ? null : _codeController.text.trim(),
            title: title,
            description:
                _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            discountPercent: discount,
            startsAt: _range.start,
            endsAt: _range.end,
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
    final bool isSubmitting = ref.watch(promotionManagementControllerProvider).isSubmitting;
    final bool isEditing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.adminPromotionEditTitle : l10n.adminPromotionCreateTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          AppTextField(
            controller: _titleController,
            label: l10n.adminPromotionTitleLabel,
            errorText: _titleError,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _codeController, label: l10n.adminPromotionCodeLabel),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _descriptionController,
            label: l10n.adminPromotionDescriptionLabel,
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _discountController,
            label: l10n.adminPromotionDiscountLabel,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffixText: '%',
          ),
          const SizedBox(height: AppSpacing.lg),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.adminPromotionDateRangeLabel),
            subtitle: Text(
              '${AppDateUtils.formatShortDate(_range.start)} – ${AppDateUtils.formatShortDate(_range.end)}',
            ),
            trailing: TextButton(onPressed: _pickRange, child: Text(l10n.adminPromotionPickDatesAction)),
          ),
          if (_dateError != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(_dateError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.adminPromotionActiveLabel),
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: l10n.adminSaveAction,
            isLoading: isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
