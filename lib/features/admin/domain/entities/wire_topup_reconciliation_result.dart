/// Summary returned by the `reconcile-wire-topups` Edge Function — see
/// its header comment for the two ways a real `wallet_topups` row can
/// get stuck `pending` forever without this (an orphaned row from a
/// failed checkout-session creation, or a missed webhook delivery).
class WireTopupReconciliationResult {
  const WireTopupReconciliationResult({
    required this.checked,
    required this.credited,
    required this.markedFailed,
  });

  /// How many stale-pending top-ups this run looked at.
  final int checked;

  /// How many of those wire.mn confirmed were actually paid — the
  /// wallet was credited for each one.
  final int credited;

  /// How many of those wire.mn confirmed will never be paid (not found,
  /// cancelled, or failed on wire.mn's side) — marked `failed` so they
  /// stop looking like live pending top-ups.
  final int markedFailed;
}
