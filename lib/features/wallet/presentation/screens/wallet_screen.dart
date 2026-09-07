import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/payout.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../controllers/request_payout_controller.dart';
import '../controllers/wallet_providers.dart';
import '../widgets/payout_status_label.dart';
import '../widgets/request_payout_sheet.dart';
import '../widgets/wallet_topup_sheet.dart';
import '../widgets/wallet_transaction_type_label.dart';

/// "Хэтэвч" (Wallet, spec sections 20, 33): the signed-in user's own
/// balance, transaction ledger, and payout requests. Read-only except for
/// requesting a payout — every balance figure here comes straight from
/// `public.wallets`/`wallet_transactions`, never computed client-side
/// (spec section 34).
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? userId = ref.watch(authControllerProvider).value?.id;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.walletTitle)),
        body: EmptyState(title: l10n.authSignedOut, icon: Icons.account_balance_wallet_outlined),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.walletTitle)),
        body: Column(
          children: [
            _BalanceSummary(userId: userId),
            TabBar(
              tabs: [
                Tab(text: l10n.walletTransactionsTab),
                Tab(text: l10n.walletPayoutsTab),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _TransactionsList(userId: userId),
                  _PayoutsList(userId: userId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceSummary extends ConsumerStatefulWidget {
  const _BalanceSummary({required this.userId});

  final String userId;

  @override
  ConsumerState<_BalanceSummary> createState() => _BalanceSummaryState();
}

class _BalanceSummaryState extends ConsumerState<_BalanceSummary> {
  bool _isRequesting = false;

  Future<void> _requestPayout(Wallet wallet) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double? amount =
        await showRequestPayoutSheet(context, availableBalance: wallet.availableBalance);
    if (amount == null) return;

    setState(() => _isRequesting = true);
    try {
      await ref.read(requestPayoutControllerProvider.notifier).submit(amount: amount);
      if (!mounted) return;
      ref.invalidate(walletProvider(widget.userId));
      ref.invalidate(walletPayoutsProvider(widget.userId));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.walletPayoutRequestedMessage)));
    } catch (e) {
      if (!mounted) return;
      final (_, message) = failurePresentation(Failure.from(e), l10n);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final walletAsync = ref.watch(walletProvider(widget.userId));

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: walletAsync.when(
        loading: () => const SkeletonCard(),
        error: (error, stack) => ErrorStateView(
          failure: Failure.from(error),
          onRetry: () => ref.invalidate(walletProvider(widget.userId)),
        ),
        data: (wallet) => Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            // The design spec's soft-yellow tint (`accentSoft`), not a
            // generic 6%-opacity wash — matches Home's "yellow = active
            // state" rule while giving this the same warm panel color the
            // rest of the redesign uses for emphasis.
            color: context.colors.accentSoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.walletAvailableBalanceLabel, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                CurrencyFormatter.format(wallet.availableBalance),
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: l10n.walletPendingBalanceLabel,
                      value: CurrencyFormatter.format(wallet.pendingBalance),
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      label: l10n.walletTotalEarnedLabel,
                      value: CurrencyFormatter.format(wallet.totalEarned),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    // Wallet-based booking payments (see `PaymentSection`)
                    // make this the primary way money gets into a wallet
                    // at all now — placed first/emphasized over payout.
                    child: OutlinedButton(
                      onPressed: () => showWalletTopUpSheet(context, ref),
                      child: Text(l10n.walletTopUpAction),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: PrimaryButton(
                      label: l10n.walletRequestPayoutAction,
                      isLoading: _isRequesting,
                      onPressed: wallet.availableBalance > 0 ? () => _requestPayout(wallet) : null,
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
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

class _TransactionsList extends ConsumerWidget {
  const _TransactionsList({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final transactionsAsync = ref.watch(walletTransactionsProvider(userId));

    return transactionsAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 3,
        itemBuilder: (context, index) =>
            const Padding(padding: EdgeInsets.only(bottom: AppSpacing.md), child: SkeletonCard()),
      ),
      error: (error, stack) => ErrorStateView(
        failure: Failure.from(error),
        onRetry: () => ref.invalidate(walletTransactionsProvider(userId)),
      ),
      data: (transactions) {
        if (transactions.isEmpty) {
          return EmptyState(
            title: l10n.walletEmptyTransactionsTitle,
            icon: Icons.receipt_long_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: transactions.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) => _TransactionTile(transaction: transactions[index]),
        );
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bool isCredit = transaction.amount >= 0;
    final Color amountColor = isCredit ? context.colors.success : theme.colorScheme.error;
    final String sign = isCredit ? '+' : '';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(walletTransactionTypeIcon(transaction.type), size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  walletTransactionTypeLabel(transaction.type, l10n),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  AppDateUtils.formatDateTime(transaction.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '$sign${CurrencyFormatter.format(transaction.amount.abs())}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutsList extends ConsumerWidget {
  const _PayoutsList({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final payoutsAsync = ref.watch(walletPayoutsProvider(userId));

    return payoutsAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 3,
        itemBuilder: (context, index) =>
            const Padding(padding: EdgeInsets.only(bottom: AppSpacing.md), child: SkeletonCard()),
      ),
      error: (error, stack) => ErrorStateView(
        failure: Failure.from(error),
        onRetry: () => ref.invalidate(walletPayoutsProvider(userId)),
      ),
      data: (payouts) {
        if (payouts.isEmpty) {
          return EmptyState(title: l10n.walletEmptyPayoutsTitle, icon: Icons.outbox_outlined);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: payouts.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) => _PayoutTile(payout: payouts[index]),
        );
      },
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.payout});

  final Payout payout;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CurrencyFormatter.format(payout.amount),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  AppDateUtils.formatDateTime(payout.requestedAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            payoutStatusLabel(payout.status, l10n),
            style: theme.textTheme.labelMedium
                ?.copyWith(color: payoutStatusColor(payout.status, context.colors)),
          ),
        ],
      ),
    );
  }
}
