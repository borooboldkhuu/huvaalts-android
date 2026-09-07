import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/app/localization/app_localizations.dart';
import 'package:huvalts/core/errors/app_exception.dart';
import 'package:huvalts/features/auth/domain/entities/app_user.dart';
import 'package:huvalts/features/auth/domain/repositories/auth_repository.dart';
import 'package:huvalts/features/auth/presentation/controllers/auth_providers.dart';
import 'package:huvalts/features/booking/domain/entities/booking.dart';
import 'package:huvalts/features/booking/domain/entities/booking_status.dart';
import 'package:huvalts/features/payments/domain/entities/payment.dart';
import 'package:huvalts/features/payments/domain/entities/payment_status.dart';
import 'package:huvalts/features/payments/domain/repositories/payment_repository.dart';
import 'package:huvalts/features/payments/presentation/controllers/payment_providers.dart';
import 'package:huvalts/features/payments/presentation/widgets/payment_section.dart';
import 'package:huvalts/features/wallet/domain/entities/wallet.dart';
import 'package:huvalts/features/wallet/presentation/controllers/wallet_providers.dart';

const String _renterId = 'renter-1';

Booking _booking({BookingStatus status = BookingStatus.confirmed}) {
  return Booking(
    id: 'booking-1',
    assetId: 'asset-1',
    renterId: _renterId,
    ownerId: 'owner-1',
    startDate: DateTime(2026, 8, 20),
    endDate: DateTime(2026, 8, 22),
    status: status,
    rentalAmount: 80000,
    platformFee: 8000,
    deliveryFee: 0,
    totalAmount: 88000,
    commissionPercent: 10,
    cancellationReason: null,
    createdAt: DateTime(2026, 8, 17),
    assetTitle: 'Canon EOS R5',
    assetImagePath: null,
    renterDisplayName: 'Renter',
    ownerDisplayName: 'Owner',
  );
}

Payment _payment({required String id, PaymentStatus status = PaymentStatus.paid}) {
  return Payment(
    id: id,
    bookingId: 'booking-1',
    payerId: _renterId,
    provider: 'wallet',
    providerReference: 'wallet_$id',
    amount: 88000,
    currency: 'MNT',
    status: status,
    createdAt: DateTime(2026, 8, 17),
  );
}

AppUser _renter() {
  return AppUser(
    id: _renterId,
    phone: '+97699112233',
    email: null,
    displayName: 'Renter',
    avatarUrl: null,
    verificationLevel: 0,
    createdAt: DateTime(2026, 1, 1),
  );
}

class _FakeAuthRepository implements AuthRepository {
  @override
  AppUser? get currentUser => _renter();

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(_renter());

  @override
  Future<void> sendPhoneOtp(String phoneE164) async {}

  @override
  Future<AppUser> verifyPhoneOtp({required String phoneE164, required String otp}) async => _renter();

  @override
  Future<AppUser> signInWithGoogle() async => _renter();

  @override
  Future<AppUser> signInWithApple() async => _renter();

  @override
  Future<void> signOut() async {}
}

/// Lets tests script the wallet-based "pay now" round trip without ever
/// touching Supabase: [payFromWallet] hands back a freshly-paid payment
/// (or throws `insufficientBalance` to simulate `pay_booking_from_wallet`'s
/// `insufficient_balance` exception), and [getForBooking] always reflects
/// the latest state — same shape the real `paymentForBookingProvider`
/// re-fetch would see after invalidation.
class _FakePaymentRepository implements PaymentRepository {
  Payment? current;
  bool insufficientBalance = false;

  @override
  Future<Payment> payFromWallet(String bookingId) async {
    if (insufficientBalance) {
      throw const ConflictException(message: 'insufficient_balance');
    }
    current = _payment(id: 'payment-1');
    return current!;
  }

  @override
  Future<Payment?> getForBooking(String bookingId) async => current;
}

void main() {
  Widget wrap(ProviderContainer container, Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('mn'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    );
  }

  ProviderContainer buildContainer({
    required _FakePaymentRepository paymentRepo,
    double walletBalance = 200000,
  }) {
    final container = ProviderContainer(
      overrides: [
        paymentRepositoryProvider.overrideWithValue(paymentRepo),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        walletProvider(_renterId).overrideWith(
          (ref) async => Wallet(
            userId: _renterId,
            availableBalance: walletBalance,
            pendingBalance: 0,
            totalEarned: 0,
            updatedAt: DateTime(2026, 8, 17),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('renter with no payment yet sees the Pay button', (tester) async {
    final container = buildContainer(paymentRepo: _FakePaymentRepository());

    final l10n = AppLocalizations(const Locale('mn'));
    await tester.pumpWidget(
      wrap(container, PaymentSection(booking: _booking(), isRenter: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.paymentPayNowAction), findsOneWidget);
  });

  testWidgets('owner with no payment yet sees the not-paid label and no button', (tester) async {
    final container = buildContainer(paymentRepo: _FakePaymentRepository());

    final l10n = AppLocalizations(const Locale('mn'));
    await tester.pumpWidget(
      wrap(container, PaymentSection(booking: _booking(), isRenter: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.paymentNotPaidYetLabel), findsOneWidget);
    expect(find.text(l10n.paymentPayNowAction), findsNothing);
  });

  testWidgets('booking not yet confirmed renders nothing', (tester) async {
    final container = buildContainer(paymentRepo: _FakePaymentRepository());

    await tester.pumpWidget(
      wrap(
        container,
        PaymentSection(booking: _booking(status: BookingStatus.pending), isRenter: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PaymentSection), findsOneWidget);
    final l10n = AppLocalizations(const Locale('mn'));
    expect(find.text(l10n.paymentPayNowAction), findsNothing);
    expect(find.text(l10n.paymentNotPaidYetLabel), findsNothing);
  });

  testWidgets('full pay-now flow: tap Pay -> wallet debited -> paid pill, button gone',
      (tester) async {
    final fake = _FakePaymentRepository();
    final container = buildContainer(paymentRepo: fake);

    final l10n = AppLocalizations(const Locale('mn'));
    await tester.pumpWidget(
      wrap(container, PaymentSection(booking: _booking(), isRenter: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.paymentPayNowAction), findsOneWidget);

    await tester.tap(find.text(l10n.paymentPayNowAction));
    await tester.pumpAndSettle();

    expect(fake.current?.status, PaymentStatus.paid);
    expect(find.text(l10n.paymentStatusPaid), findsOneWidget);
    expect(find.text(l10n.paymentPayNowAction), findsNothing);
    expect(find.text(l10n.paymentSuccessMessage), findsOneWidget);
  });

  testWidgets('insufficient wallet balance shows the top-up dialog instead of a generic error',
      (tester) async {
    final fake = _FakePaymentRepository()..insufficientBalance = true;
    final container = buildContainer(paymentRepo: fake, walletBalance: 5000);

    final l10n = AppLocalizations(const Locale('mn'));
    await tester.pumpWidget(
      wrap(container, PaymentSection(booking: _booking(), isRenter: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.paymentPayNowAction));
    await tester.pumpAndSettle();

    expect(fake.current, isNull); // never actually paid
    expect(find.text(l10n.paymentInsufficientBalanceTitle), findsOneWidget);
    expect(find.text(l10n.paymentTopUpAction), findsOneWidget);
  });
}
