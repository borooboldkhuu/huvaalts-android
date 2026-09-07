import '../entities/payout.dart';
import '../entities/wallet.dart';
import '../entities/wallet_transaction.dart';

abstract interface class WalletRepository {
  Future<Wallet> getWallet(String userId);

  /// Most recent first. Not paginated — fine at the transaction volumes
  /// a single user accrues early on, worth revisiting (cursor-based, like
  /// `AssetRepository.search`) once that stops being true.
  Future<List<WalletTransaction>> getTransactions(String userId);

  Future<List<Payout>> getPayouts(String userId);

  /// Inserts a `pending` payout request for the *current* signed-in user
  /// (never takes a userId — RLS ties this to `auth.uid()`, and passing
  /// one in would just invite a caller to request someone else's payout).
  /// Throws a [ValidationException]-shaped error if [amount] exceeds what
  /// the backend's own `validate_payout_request` trigger considers
  /// actually available.
  Future<Payout> requestPayout({required double amount});
}
