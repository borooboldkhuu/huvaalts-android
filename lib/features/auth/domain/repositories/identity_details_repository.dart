/// Abstraction over `public.identity_details` (see
/// `supabase/migrations/0017_wire_topup_and_wallet_payments.sql`'s header
/// comment for why this is a private table, never `public.profiles`) —
/// the self-reported овог/нэр/регистрийн дугаар collected right after
/// phone/OTP sign-up, ahead of DAN verification.
abstract interface class IdentityDetailsRepository {
  /// Whether the current user has already completed this step. Drives the
  /// router's post-registration gate (`app_router.dart`) — a user who
  /// already has a row here skips straight past `CompleteProfileScreen`.
  Future<bool> exists(String userId);

  /// Upserts the caller's own row (RLS ties both insert and update to
  /// `auth.uid()`, so `userId` here is who this repository is being
  /// called *for*, not a trust boundary by itself). Throws a
  /// [ConflictException]-shaped error (message `register_number_already_used`)
  /// if the register number is already claimed by another account —
  /// `register_number` is `unique` at the database level.
  Future<void> submit({
    required String userId,
    required String surname,
    required String givenName,
    required String registerNumber,
  });
}
