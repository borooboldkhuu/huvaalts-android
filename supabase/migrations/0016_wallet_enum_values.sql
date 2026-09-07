-- ХУВААЛЦ — new wallet_transaction_type values for wallet-based payments.
--
-- Split into its own migration file/transaction deliberately: Postgres
-- refuses to let a newly-added enum value be *used* (e.g. in an INSERT or
-- a function body compiled in the same transaction) within the same
-- transaction block that ran `ALTER TYPE ... ADD VALUE` for it — see
-- https://www.postgresql.org/docs/current/sql-altertype.html. Supabase
-- runs each migration file as its own transaction, so keeping this file
-- to nothing but the two `ADD VALUE` statements guarantees
-- 0017_wire_topup_and_wallet_payments.sql (which references both values
-- in `insert`/function bodies) always runs in a later, separate
-- transaction where the values are already committed and usable.
--
-- 'wallet_topup'    — a credit to `wallets.available_balance` from a real
--                      top-up (wire.mn today; any future top-up provider
--                      would reuse this same type).
-- 'booking_payment'  — a debit from a renter's `wallets.available_balance`
--                      when a booking is paid for out of wallet balance
--                      instead of a direct provider charge (spec: booking
--                      payments are now wallet-balance-based end to end,
--                      see `pay_booking_from_wallet` in 0017).

alter type public.wallet_transaction_type add value 'wallet_topup';
alter type public.wallet_transaction_type add value 'booking_payment';
