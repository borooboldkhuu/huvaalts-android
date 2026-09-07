import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Prompts for a payout amount, capped client-side at [availableBalance]
/// purely for immediate feedback — the real guard is the backend's
/// `validate_payout_request` trigger (`0008_wallet_credit_rpc.sql`),
/// which this client-side check can never substitute for (spec section
/// 34: never trust the client for wallet balance). Returns the chosen
/// amount, or `null` if dismissed without submitting.
Future<double?> showRequestPayoutSheet(
  BuildContext context, {
  required double availableBalance,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _RequestPayoutSheet(availableBalance: availableBalance),
  );
}

class _RequestPayoutSheet extends StatefulWidget {
  const _RequestPayoutSheet({required this.availableBalance});

  final double availableBalance;

  @override
  State<_RequestPayoutSheet> createState() => _RequestPayoutSheetState();
}

class _RequestPayoutSheetState extends State<_RequestPayoutSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(AppLocalizations l10n) {
    final double? amount = double.tryParse(_controller.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _errorText = l10n.walletPayoutInvalidAmount);
      return;
    }
    if (amount > widget.availableBalance) {
      setState(() => _errorText = l10n.walletPayoutExceedsAvailable);
      return;
    }
    Navigator.of(context).pop(amount);
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
          Text(l10n.walletRequestPayoutAction, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.walletPayoutAvailableLabel(CurrencyFormatter.format(widget.availableBalance)),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _controller,
            label: l10n.walletPayoutAmountLabel,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffixText: '₮',
            errorText: _errorText,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: l10n.walletRequestPayoutAction,
            onPressed: () => _submit(l10n),
          ),
        ],
      ),
    );
  }
}
