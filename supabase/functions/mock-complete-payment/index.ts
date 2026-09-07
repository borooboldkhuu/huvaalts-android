// ХУВААЛЦ — formerly completed a pending mock payment (simulated the
// callback a real payment gateway would deliver via a signed webhook).
//
// SUPERSEDED as of `0017_wire_topup_and_wallet_payments.sql`: booking
// payments now go exclusively through `pay_booking_from_wallet` (the
// renter's own wallet balance is debited synchronously — no external
// gateway, no separate "complete" callback step). This function and its
// sibling `initiate-payment` are kept in the repo only as a historical
// record of the Phase-7 mock-gateway design; they are now DISABLED
// unconditionally below and must never be re-enabled.
//
// Why disabling outright, not just leaving the old `PAYMENT_PROVIDER_MODE`
// gate in place: that gate defaulted to `'mock'` whenever the env var was
// unset, and this endpoint could be invoked directly by any authenticated
// user with just their own JWT (`functions.invoke`, no app UI required —
// nothing here checked that a matching `initiate-payment` call had ever
// happened through legitimate means beyond payer_id ownership). Calling
// `initiate-payment` then this function with `outcome: 'success'` marked
// an arbitrary booking's payment `'paid'` and credited the OWNER's wallet
// via `credit_wallet_for_payment` — with the renter never actually
// spending anything (no debit exists anywhere in the old body). That is a
// free-money exploit reachable in exactly the configuration this project
// ships/documents deploying, so leaving a mode-flag toggle here — however
// carefully guarded — was not an acceptable risk once a real
// money-conserving path (`pay_booking_from_wallet`) exists. Delete this
// file (and `initiate-payment`) entirely once it's undeployed from every
// environment.

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }
  return json(
    {
      error: 'endpoint_disabled',
      message:
        'Booking payments are wallet-balance-based now — see pay_booking_from_wallet. ' +
        'This mock-gateway endpoint is permanently disabled.',
    },
    410,
  );
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
