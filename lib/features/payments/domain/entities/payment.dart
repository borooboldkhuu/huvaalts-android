import 'package:freezed_annotation/freezed_annotation.dart';

import 'payment_status.dart';

part 'payment.freezed.dart';
part 'payment.g.dart';

/// A `public.payments` row — created and transitioned exclusively by the
/// `initiate-payment` / `mock-complete-payment` Edge Functions (see
/// `supabase/functions/`), never written by the client directly (spec
/// section 19/34; `payments` has no client insert/update RLS policy at
/// all — see `supabase/migrations/0002_rls_policies.sql`). The Flutter
/// side only ever reads this shape back.
@freezed
abstract class Payment with _$Payment {
  const factory Payment({
    required String id,
    required String bookingId,
    required String payerId,
    required String provider,
    required String? providerReference,
    required double amount,
    required String currency,
    required PaymentStatus status,
    required DateTime createdAt,
  }) = _Payment;

  factory Payment.fromJson(Map<String, dynamic> json) => _$PaymentFromJson(json);
}
