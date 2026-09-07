import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/auth/domain/entities/app_user.dart';
import 'package:huvalts/features/auth/domain/repositories/auth_repository.dart';
import 'package:huvalts/features/auth/presentation/controllers/auth_providers.dart';
import 'package:huvalts/features/wallet/domain/entities/wallet_topup.dart';
import 'package:huvalts/features/wallet/domain/entities/wallet_topup_status.dart';
import 'package:huvalts/features/wallet/domain/repositories/wallet_topup_repository.dart';
import 'package:huvalts/features/wallet/presentation/controllers/wallet_providers.dart';
import 'package:huvalts/features/wallet/presentation/controllers/wallet_topup_controller.dart';

const String _userId = 'user-1';

WalletTopup _topup({WalletTopupStatus status = WalletTopupStatus.pending, String id = 'topup-1'}) {
  return WalletTopup(
    id: id,
    userId: _userId,
    provider: 'wire',
    providerReference: 'pi_abc',
    amount: 10000,
    currency: 'MNT',
    status: status,
    createdAt: DateTime(2026, 8, 17),
  );
}

class _FakeAuthRepository implements AuthRepository {
  @override
  AppUser? get currentUser => AppUser(
        id: _userId,
        phone: '+97699112233',
        email: null,
        displayName: 'Renter',
        avatarUrl: null,
        verificationLevel: 0,
        createdAt: DateTime(2026, 1, 1),
      );

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(currentUser);

  @override
  Future<void> sendPhoneOtp(String phoneE164) async {}

  @override
  Future<AppUser> verifyPhoneOtp({required String phoneE164, required String otp}) async => currentUser!;

  @override
  Future<AppUser> signInWithGoogle() async => currentUser!;

  @override
  Future<AppUser> signInWithApple() async => currentUser!;

  @override
  Future<void> signOut() async {}
}

/// Scriptable fake covering every branch `WalletTopupController` drives:
/// creation failure, terminal statuses (`paid`/`failed`/`cancelled`),
/// non-terminal `pending` (which the controller must keep polling on
/// rather than treat as done), a transient lookup error mid-poll (which
/// must NOT end the flow), and `mockComplete`'s own outcome branches.
class _FakeWalletTopupRepository implements WalletTopupRepository {
  double? lastCreateAmount;
  Object? createError;
  WalletTopupStart? createResult;

  WalletTopup? getByIdResult;
  Object? getByIdError;
  int getByIdCallCount = 0;

  WalletTopup? mockCompleteResult;
  Object? mockCompleteError;

  @override
  Future<WalletTopupStart> create({required double amountMnt}) async {
    lastCreateAmount = amountMnt;
    if (createError != null) throw createError!;
    return createResult!;
  }

  @override
  Future<WalletTopup?> getById(String topupId) async {
    getByIdCallCount++;
    if (getByIdError != null) throw getByIdError!;
    return getByIdResult;
  }

  @override
  Future<WalletTopup> mockComplete(String topupId) async {
    if (mockCompleteError != null) throw mockCompleteError!;
    return mockCompleteResult!;
  }
}

void main() {
  ProviderContainer buildContainer(_FakeWalletTopupRepository fake) {
    final container = ProviderContainer(
      overrides: [
        walletTopupRepositoryProvider.overrideWithValue(fake),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('create() success moves to awaitingPayment and stores the start payload', () async {
    final fake = _FakeWalletTopupRepository()
      ..createResult =
          WalletTopupStart(topup: _topup(), checkoutUrl: 'https://pay.wire.mn/c/tok', mock: false);
    final container = buildContainer(fake);
    final controller = container.read(walletTopupControllerProvider.notifier);

    await controller.create(10000);

    expect(fake.lastCreateAmount, 10000);
    expect(controller.state.step, WalletTopupStep.awaitingPayment);
    expect(controller.state.start?.checkoutUrl, 'https://pay.wire.mn/c/tok');
  });

  test('create() failure moves to failed and records the error', () async {
    final fake = _FakeWalletTopupRepository()..createError = Exception('invalid_topup_request');
    final container = buildContainer(fake);
    final controller = container.read(walletTopupControllerProvider.notifier);

    await controller.create(10000);

    expect(controller.state.step, WalletTopupStep.failed);
    expect(controller.state.error, isNotNull);
  });

  test('checkOnce() with no start in state is a no-op', () async {
    final fake = _FakeWalletTopupRepository();
    final container = buildContainer(fake);
    final controller = container.read(walletTopupControllerProvider.notifier);

    await controller.checkOnce();

    expect(controller.state.step, WalletTopupStep.idle);
    expect(fake.getByIdCallCount, 0);
  });

  test('checkOnce() paid -> succeeded', () async {
    final fake = _FakeWalletTopupRepository()
      ..createResult = WalletTopupStart(topup: _topup(), checkoutUrl: 'https://x', mock: false)
      ..getByIdResult = _topup(status: WalletTopupStatus.paid);
    final container = buildContainer(fake);
    final controller = container.read(walletTopupControllerProvider.notifier);
    await controller.create(10000);

    await controller.checkOnce();

    expect(controller.state.step, WalletTopupStep.succeeded);
  });

  test('checkOnce() failed -> failed', () async {
    final fake = _FakeWalletTopupRepository()
      ..createResult = WalletTopupStart(topup: _topup(), checkoutUrl: 'https://x', mock: false)
      ..getByIdResult = _topup(status: WalletTopupStatus.failed);
    final container = buildContainer(fake);
    final controller = container.read(walletTopupControllerProvider.notifier);
    await controller.create(10000);

    await controller.checkOnce();

    expect(controller.state.step, WalletTopupStep.failed);
  });

  test('checkOnce() cancelled -> failed', () async {
    final fake = _FakeWalletTopupRepository()
      ..createResult = WalletTopupStart(topup: _topup(), checkoutUrl: 'https://x', mock: false)
      ..getByIdResult = _topup(status: WalletTopupStatus.cancelled);
    final container = buildContainer(fake);
    final controller = container.read(walletTopupControllerProvider.notifier);
    await controller.create(10000);

    await controller.checkOnce();

    expect(controller.state.step, WalletTopupStep.failed);
  });

  test('checkOnce() still pending -> stays awaitingPayment (not terminal)', () async {
    final fake = _FakeWalletTopupRepository()
      ..createResult = WalletTopupStart(topup: _topup(), checkoutUrl: 'https://x', mock: false)
      ..getByIdResult = _topup(status: WalletTopupStatus.pending);
    final container = buildContainer(fake);
    final controller = container.read(walletTopupControllerProvider.notifier);
    await controller.create(10000);

    await controller.checkOnce();

    expect(controller.state.step, WalletTopupStep.awaitingPayment);
  });

  test('checkOnce() null row (not found yet) -> stays awaitingPayment', () async {
    final fake = _FakeWalletTopupRepository()
      ..createResult = WalletTopupStart(topup: _topup(), checkoutUrl: 'https://x', mock: false)
      ..getByIdResult = null;
    final container = buildContainer(fake);
    final controller = container.read(walletTopupControllerProvider.notifier);
    await controller.create(10000);

    await controller.checkOnce();

    expect(controller.state.step, WalletTopupStep.awaitingPayment);
  });

  test('checkOnce() transient lookup error does not end the flow', () async {
    final fake = _FakeWalletTopupRepository()
      ..createResult = WalletTopupStart(topup: _topup(), checkoutUrl: 'https://x', mock: false)
      ..getByIdError = Exception('network_error');
    final container = buildContainer(fake);
    final controller = container.read(walletTopupControllerProvider.notifier);
    await controller.create(10000);

    await controller.checkOnce();

    expect(controller.state.step, WalletTopupStep.awaitingPayment,
        reason: 'a single failed poll must not surface as a terminal failure');
  });

  test('pollUntilSettled() stops immediately once a poll comes back paid', () async {
    final fake = _FakeWalletTopupRepository()
      ..createResult = WalletTopupStart(topup: _topup(), checkoutUrl: 'https://x', mock: false)
      ..getByIdResult = _topup(status: WalletTopupStatus.paid);
    final container = buildContainer(fake);
    final controller = container.read(walletTopupControllerProvider.notifier);
    await controller.create(10000);

    await controller.pollUntilSettled();

    expect(controller.state.step, WalletTopupStep.succeeded);
    expect(fake.getByIdCallCount, 1, reason: 'must not keep polling once settled');
  });

  testWidgets('pollUntilSettled() gives up after the bounded number of pending polls', (tester) async {
    final fake = _FakeWalletTopupRepository()
      ..createResult = WalletTopupStart(topup: _topup(), checkoutUrl: 'https://x', mock: false)
      ..getByIdResult = _topup(status: WalletTopupStatus.pending);
    final container = buildContainer(fake);
    final controller = container.read(walletTopupControllerProvider.notifier);
    await controller.create(10000);

    final polling = controller.pollUntilSettled();
    await tester.pump();
    for (int attempt = 1; attempt < 20; attempt++) {
      await tester.pump(const Duration(seconds: 3));
    }
    await polling;

    // Never settles (always pending) — must give up rather than spin
    // forever, leaving the user on awaitingPayment with the manual
    // "Шалгах" action still available.
    expect(controller.state.step, WalletTopupStep.awaitingPayment);
    expect(fake.getByIdCallCount, 20);
  });

  test('mockComplete() paid -> succeeded', () async {
    final fake = _FakeWalletTopupRepository()
      ..createResult = WalletTopupStart(topup: _topup(), checkoutUrl: null, mock: true)
      ..mockCompleteResult = _topup(status: WalletTopupStatus.paid);
    final container = buildContainer(fake);
    final controller = container.read(walletTopupControllerProvider.notifier);
    await controller.create(10000);

    await controller.mockComplete();

    expect(controller.state.step, WalletTopupStep.succeeded);
  });

  test('mockComplete() non-paid result -> failed', () async {
    final fake = _FakeWalletTopupRepository()
      ..createResult = WalletTopupStart(topup: _topup(), checkoutUrl: null, mock: true)
      ..mockCompleteResult = _topup(status: WalletTopupStatus.failed);
    final container = buildContainer(fake);
    final controller = container.read(walletTopupControllerProvider.notifier);
    await controller.create(10000);

    await controller.mockComplete();

    expect(controller.state.step, WalletTopupStep.failed);
  });

  test('mockComplete() server error -> failed with error recorded', () async {
    final fake = _FakeWalletTopupRepository()
      ..createResult = WalletTopupStart(topup: _topup(), checkoutUrl: null, mock: true)
      ..mockCompleteError = Exception('not_in_mock_mode');
    final container = buildContainer(fake);
    final controller = container.read(walletTopupControllerProvider.notifier);
    await controller.create(10000);

    await controller.mockComplete();

    expect(controller.state.step, WalletTopupStep.failed);
    expect(controller.state.error, isNotNull);
  });

  test('mockComplete() with no start in state is a no-op', () async {
    final fake = _FakeWalletTopupRepository();
    final container = buildContainer(fake);
    final controller = container.read(walletTopupControllerProvider.notifier);

    await controller.mockComplete();

    expect(controller.state.step, WalletTopupStep.idle);
  });

  test('reset() returns to the idle state', () async {
    final fake = _FakeWalletTopupRepository()
      ..createResult = WalletTopupStart(topup: _topup(), checkoutUrl: 'https://x', mock: false);
    final container = buildContainer(fake);
    final controller = container.read(walletTopupControllerProvider.notifier);
    await controller.create(10000);
    expect(controller.state.step, WalletTopupStep.awaitingPayment);

    controller.reset();

    expect(controller.state.step, WalletTopupStep.idle);
    expect(controller.state.start, isNull);
  });
}
