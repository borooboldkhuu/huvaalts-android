import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Shared reason-prompt sheet for admin actions that require one
/// (reject/suspend an asset, resolution notes on a dispute) — same shape
/// as `showRequestPayoutSheet`, kept as one reusable widget rather than
/// four near-identical bottom sheets. Returns the trimmed text, or `null`
/// if dismissed without submitting. When [required] is false, submitting
/// with an empty field returns an empty string rather than blocking
/// (used for dispute resolution notes, which the backend treats as
/// optional — see `admin_resolve_dispute`'s `p_resolution_notes default
/// null`).
Future<String?> showAdminReasonSheet(
  BuildContext context, {
  required String title,
  required String label,
  required String hint,
  bool required = true,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AdminReasonSheet(title: title, label: label, hint: hint, required: required),
  );
}

class _AdminReasonSheet extends StatefulWidget {
  const _AdminReasonSheet({
    required this.title,
    required this.label,
    required this.hint,
    required this.required,
  });

  final String title;
  final String label;
  final String hint;
  final bool required;

  @override
  State<_AdminReasonSheet> createState() => _AdminReasonSheetState();
}

class _AdminReasonSheetState extends State<_AdminReasonSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(AppLocalizations l10n) {
    final String text = _controller.text.trim();
    if (widget.required && text.isEmpty) {
      setState(() => _errorText = l10n.adminReasonRequiredError);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _controller,
            label: widget.label,
            hintText: widget.hint,
            maxLines: 3,
            errorText: _errorText,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: l10n.adminConfirmAction,
            onPressed: () => _submit(l10n),
          ),
        ],
      ),
    );
  }
}
