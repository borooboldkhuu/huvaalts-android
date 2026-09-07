import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../domain/entities/wallet_transaction_type.dart';

String walletTransactionTypeLabel(WalletTransactionType type, AppLocalizations l10n) {
  return switch (type) {
    WalletTransactionType.bookingIncome => l10n.walletTransactionBookingIncome,
    WalletTransactionType.platformFee => l10n.walletTransactionPlatformFee,
    WalletTransactionType.refund => l10n.walletTransactionRefund,
    WalletTransactionType.payout => l10n.walletTransactionPayout,
    WalletTransactionType.walletTopup => l10n.walletTransactionWalletTopup,
    WalletTransactionType.bookingPayment => l10n.walletTransactionBookingPayment,
    WalletTransactionType.adjustment => l10n.walletTransactionAdjustment,
  };
}

/// Icon reflects the transaction's *usual* direction for the type (e.g.
/// `payout` almost always debits) — the actual sign always comes from
/// `WalletTransaction.amount` itself, this is purely decorative.
IconData walletTransactionTypeIcon(WalletTransactionType type) {
  return switch (type) {
    WalletTransactionType.bookingIncome => Icons.arrow_downward_rounded,
    WalletTransactionType.platformFee => Icons.percent_rounded,
    WalletTransactionType.refund => Icons.replay_rounded,
    WalletTransactionType.payout => Icons.arrow_upward_rounded,
    WalletTransactionType.walletTopup => Icons.add_card_rounded,
    WalletTransactionType.bookingPayment => Icons.shopping_bag_outlined,
    WalletTransactionType.adjustment => Icons.tune_rounded,
  };
}
