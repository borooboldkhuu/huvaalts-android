// ХУВААЛЦ — formerly started a payment for a confirmed booking (MOCK
// gateway).
//
// SUPERSEDED as of `0017_wire_topup_and_wallet_payments.sql`, same as
// `mock-complete-payment` — see that function's header comment for the
// full reasoning. Booking payments now go exclusively through
// `pay_booking_from_wallet`, which debits the renter's own wallet balance
// directly and synchronously; there is no separate "initiate" step to
// replace. This function is DISABLED unconditionally below and must
// never be re-enabled — paired with `mock-complete-payment`, it was part
// of a free-money exploit path (create a pending mock payment, then mark
// it paid, crediting the owner's wallet with no renter debit anywhere).
// Delete this file entirely once it's undeployed from every environment.

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
