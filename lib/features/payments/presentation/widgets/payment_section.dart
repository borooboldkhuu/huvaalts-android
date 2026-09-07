import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../booking/domain/entities/booking.dart';
import '../../../booking/domain/entities/booking_status.dart';
import '../../../wallet/presentation/controllers/wallet_providers.dart';
import '../../../wallet/presentation/widgets/wallet_topup_sheet.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/payment_status.dart';
import '../controllers/payment_providers.dart';
import 'payment_status_label.dart';

/// The payment block on booking detail (spec section 19). Only rendered
/// once a booking has moved past `confirmed` — paying for a booking the
/// owner hasn't accepted yet doesn't make sense. The renter gets a
/// "Pay from wallet" / "Retry" action; the owner sees the same status
/// read-only, since only the renter is `payments.payer_id`.
///
/// Booking payments are wallet-balance-based end to end now (see
/// `pay_booking_from_wallet`,
/// `supabase/migrations/0017_wire_topup_and_wallet_payments.sql`) — this
/// no longer shows a mock/QPay payment sheet. Tapping "Pay" debits the
/// renter's own wallet directly and settles synchronously; the only
/// branch that needs its own UI is running out of balance, which offers
/// the wallet top-up sheet instead of a generic error.
class PaymentSection extends ConsumerStatefulWidget {
  const PaymentSection({required this.booking, required this.isRenter, super.key});

  final Booking booking;
  final bool isRenter;

  @override
  ConsumerState<PaymentSection> createState() => _PaymentSectionState();
}

class _PaymentSectionState extends ConsumerState<PaymentSection> {
  bool _isProcessing = false;

  Future<void> _payNow() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => _isProcessing = true);
    try {
      await ref.read(paymentRepositoryProvider).payFromWallet(widget.booking.id);
      if (!mounted) return;
      ref.invalidate(paymentForBookingProvider(widget.booking.id));
      final String? userId = ref.read(authControllerProvider).value?.id;
      if (userId != null) ref.invalidate(walletProvider(userId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.paymentSuccessMessage)));
    } catch (e) {
      if (!mounted) return;
      final Failure failure = Failure.from(e);
      if (failure is ConflictFailure && failure.message == 'insufficient_balance') {
        _showInsufficientBalanceDialog(l10n);
      } else {
        final (_, message) = failurePresentation(failure, l10n);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showInsufficientBalanceDialog(AppLocalizations l10n) {
    final String? userId = ref.read(authControllerProvider).value?.id;
    final double available = userId != null ? (ref.read(walletProvider(userId)).value?.availableBalance ?? 0) : 0;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.paymentInsufficientBalanceTitle),
        content: Text(
          l10n.paymentInsufficientBalanceBody(
            CurrencyFormatter.format(widget.booking.totalAmount),
            CurrencyFormatter.format(available),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              showWalletTopUpSheet(context, ref);
            },
            child: Text(l10n.paymentTopUpAction),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool relevant = widget.booking.status == BookingStatus.confirmed ||
        widget.booking.status == BookingStatus.active ||
        widget.booking.status == BookingStatus.completed;
    if (!relevant) return const SizedBox.shrink();

    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final paymentAsync = ref.watch(paymentForBookingProvider(widget.booking.id));

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.paymentSectionTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          paymentAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
            // Non-fatal: a failed payment-status fetch shouldn't block the
            // rest of the booking detail screen — just offer a retry
            // affordance inline instead of a full-screen error.
            error: (error, stack) => ErrorStateView(
              failure: Failure.from(error),
              onRetry: () => ref.invalidate(paymentForBookingProvider(widget.booking.id)),
            ),
            data: (payment) => _buildContent(context, l10n, theme, payment),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    Payment? payment,
  ) {
    final bool isPaid = payment?.status == PaymentStatus.paid;
    final bool canPay = widget.isRenter &&
        widget.booking.status == BookingStatus.confirmed &&
        !isPaid;

    final String? userId = ref.watch(authControllerProvider).value?.id;
    final double? walletBalance =
        (canPay && userId != null) ? ref.watch(walletProvider(userId)).value?.availableBalance : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (payment != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
            decoration: BoxDecoration(
              color: paymentStatusColor(payment.status, context.colors).withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPaid ? Icons.check_circle_outline : Icons.hourglass_bottom,
                  size: 14,
                  color: paymentStatusColor(payment.status, context.colors),
                ),
                const SizedBox(width: 6),
                Text(
                  paymentStatusLabel(payment.status, l10n),
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: paymentStatusColor(payment.status, context.colors)),
                ),
              ],
            ),
          )
        else if (!widget.isRenter)
          Text(l10n.paymentNotPaidYetLabel, style: theme.textTheme.bodyMedium),
        if (canPay) ...[
          if (walletBalance != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.paymentWalletBalanceLabel(CurrencyFormatter.format(walletBalance)),
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: payment?.status == PaymentStatus.failed
                  ? l10n.paymentRetryAction
                  : l10n.paymentPayNowAction,
              isLoading: _isProcessing,
              onPressed: _payNow,
            ),
          ),
        ],
      ],
    );
  }
}
