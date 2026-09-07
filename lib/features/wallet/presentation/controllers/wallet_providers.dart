import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/supabase_wallet_repository.dart';
import '../../data/repositories/supabase_wallet_topup_repository.dart';
import '../../domain/entities/payout.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../../domain/repositories/wallet_topup_repository.dart';

final Provider<WalletRepository> walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return SupabaseWalletRepository(ref.watch(supabaseClientProvider));
});

final Provider<WalletTopupRepository> walletTopupRepositoryProvider =
    Provider<WalletTopupRepository>((ref) {
  return SupabaseWalletTopupRepository(ref.watch(supabaseClientProvider));
});

final walletProvider =
    FutureProvider.family<Wallet, String>((ref, userId) {
  return ref.watch(walletRepositoryProvider).getWallet(userId);
});

final walletTransactionsProvider =
    FutureProvider.family<List<WalletTransaction>, String>((ref, userId) {
  return ref.watch(walletRepositoryProvider).getTransactions(userId);
});

final walletPayoutsProvider =
    FutureProvider.family<List<Payout>, String>((ref, userId) {
  return ref.watch(walletRepositoryProvider).getPayouts(userId);
});
