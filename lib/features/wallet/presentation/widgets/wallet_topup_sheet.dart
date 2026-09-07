import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../domain/repositories/wallet_topup_repository.dart';
import '../controllers/wallet_topup_controller.dart';

const double _minTopUpMnt = 1000;
const double _maxTopUpMnt = 5000000;

/// Opens the wallet top-up bottom sheet — amount entry, then the
/// wire.mn/mock progress steps, all driven by [WalletTopupController]
/// (mirrors `VerificationController`'s own start-then-poll shape). Resets
/// the controller both on open and on close so a half-finished attempt
/// never leaks into the next time the user opens this sheet.
Future<void> showWalletTopUpSheet(BuildContext context, WidgetRef ref) {
  ref.read(walletTopupControllerProvider.notifier).reset();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    builder: (context) => const _WalletTopUpSheetContent(),
  ).whenComplete(() => ref.read(walletTopupControllerProvider.notifier).reset());
}

class _WalletTopUpSheetContent extends ConsumerStatefulWidget {
  const _WalletTopUpSheetContent();

  @override
  ConsumerState<_WalletTopUpSheetContent> createState() => _WalletTopUpSheetContentState();
}

class _WalletTopUpSheetContentState extends ConsumerState<_WalletTopUpSheetContent> {
  final TextEditingController _amountController = TextEditingController();
  String? _amountError;
  bool _pollStarted = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submitAmount(AppLocalizations l10n) {
    final double? amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount < _minTopUpMnt || amount > _maxTopUpMnt) {
      setState(() {
        _amountError = l10n.walletTopUpAmountRange(
          CurrencyFormatter.format(_minTopUpMnt),
          CurrencyFormatter.format(_maxTopUpMnt),
        );
      });
      return;
    }
    setState(() => _amountError = null);
    ref.read(walletTopupControllerProvider.notifier).create(amount);
  }

  Future<void> _openCheckout(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final WalletTopupState state = ref.watch(walletTopupControllerProvider);

    // Kick off the bounded auto-poll exactly once per successful `create`
    // — `awaitingPayment` is also the state a manual "Шалгах" tap
    // re-enters via `checkOnce`, so this guard (rather than re-triggering
    // on every rebuild) keeps only one poll loop alive at a time.
    if (state.step == WalletTopupStep.awaitingPayment && !_pollStarted) {
      _pollStarted = true;
      ref.read(walletTopupControllerProvider.notifier).pollUntilSettled();
    }
    if (state.step == WalletTopupStep.idle || state.step == WalletTopupStep.creating) {
      _pollStarted = false;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.walletTopUpSheetTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            _buildStep(context, l10n, theme, state),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    WalletTopupState state,
  ) {
    // A `failed` step with no `start` yet means `create()` itself threw
    // (network/validation error before wire.mn was ever involved) — show
    // the amount form again with an inline error rather than the fuller
    // post-creation failure view below, so the user can just retry the
    // amount instead of starting the whole sheet over.
    final bool showAmountForm =
        state.step == WalletTopupStep.idle || (state.step == WalletTopupStep.failed && state.start == null);

    if (showAmountForm) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _amountController,
            label: l10n.walletTopUpAmountLabel,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffixText: '₮',
            errorText: _amountError,
            autofocus: true,
          ),
          if (state.step == WalletTopupStep.failed) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              failurePresentation(Failure.from(state.error ?? 'unknown'), l10n).$2,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: l10n.walletTopUpContinueAction,
            onPressed: () => _submitAmount(l10n),
          ),
        ],
      );
    }

    if (state.step == WalletTopupStep.creating) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.step == WalletTopupStep.succeeded) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 48, color: context.colors.success),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.walletTopUpSuccessMessage, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: l10n.verificationDoneAction,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    // `failed` with a `start` present (post-creation failure — mock
    // rejection, a `cancelled`/`failed` topup status) gets its own fuller
    // view rather than folding back into the amount form.
    if (state.step == WalletTopupStep.failed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.walletTopUpFailedMessage, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: l10n.commonRetry,
            onPressed: () => ref.read(walletTopupControllerProvider.notifier).reset(),
          ),
        ],
      );
    }

    // Remaining steps: awaitingPayment / checking — both need `start`.
    final WalletTopupStart start = state.start!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.walletTopUpWaitingTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.walletTopUpWaitingBody, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        if (start.mock)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.science_outlined, size: 18, color: theme.colorScheme.error),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.walletTopUpMockNotice,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          )
        else if (start.checkoutUrl != null)
          SecondaryButton(
            label: l10n.walletTopUpOpenCheckoutAction,
            onPressed: () => _openCheckout(start.checkoutUrl!),
          ),
        const SizedBox(height: AppSpacing.lg),
        if (start.mock)
          PrimaryButton(
            label: l10n.walletTopUpMockConfirmAction,
            isLoading: state.step == WalletTopupStep.checking,
            onPressed: () => ref.read(walletTopupControllerProvider.notifier).mockComplete(),
          )
        else
          PrimaryButton(
            label: l10n.walletTopUpCheckStatusAction,
            isLoading: state.step == WalletTopupStep.checking,
            onPressed: () => ref.read(walletTopupControllerProvider.notifier).checkOnce(),
          ),
      ],
    );
  }
}
