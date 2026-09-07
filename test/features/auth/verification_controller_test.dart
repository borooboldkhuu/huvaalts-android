import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/auth/domain/entities/app_user.dart';
import 'package:huvalts/features/auth/domain/repositories/auth_repository.dart';
import 'package:huvalts/features/auth/domain/repositories/identity_verification_repository.dart';
import 'package:huvalts/features/auth/presentation/controllers/auth_providers.dart';
import 'package:huvalts/features/auth/presentation/controllers/verification_controller.dart';

AppUser _user() {
  return AppUser(
    id: 'user-1',
    phone: '+97699112233',
    email: null,
    displayName: 'Test User',
    avatarUrl: null,
    verificationLevel: 0,
    createdAt: DateTime(2026, 1, 1),
  );
}

DanVerificationSession _session({String id = 'session-1'}) {
  return DanVerificationSession(
    sessionId: id,
    consentUrl: 'https://mock-dan.local/consent?session=$id',
    status: DanVerificationStatus.pending,
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.userOverride});

  final AppUser? userOverride;

  @override
  AppUser? get currentUser => userOverride;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(userOverride);

  @override
  Future<void> sendPhoneOtp(String phoneE164) async {}

  @override
  Future<AppUser> verifyPhoneOtp({required String phoneE164, required String otp}) async =>
      userOverride ?? _user();

  @override
  Future<AppUser> signInWithGoogle() async => userOverride ?? _user();

  @override
  Future<AppUser> signInWithApple() async => userOverride ?? _user();

  @override
  Future<void> signOut() async {}
}

class _FakeIdentityVerificationRepository implements IdentityVerificationRepository {
  int startCallCount = 0;
  List<DanVerificationStatus> statusSequence = const [DanVerificationStatus.verified];
  Object? errorOnStart;

  @override
  Future<DanVerificationSession> startVerification({required String userId}) async {
    startCallCount++;
    if (errorOnStart != null) throw errorOnStart!;
    return _session();
  }

  @override
  Future<DanVerificationStatus> checkStatus({required String sessionId}) async {
    if (statusSequence.isEmpty) return DanVerificationStatus.pending;
    if (statusSequence.length == 1) return statusSequence.first;
    final status = statusSequence.first;
    statusSequence = statusSequence.sublist(1);
    return status;
  }
}

void main() {
  ProviderContainer buildContainer({
    AppUser? user,
    _FakeIdentityVerificationRepository? repo,
  }) {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(userOverride: user ?? _user())),
        identityVerificationRepositoryProvider
            .overrideWithValue(repo ?? _FakeIdentityVerificationRepository()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('start() moves to awaitingConsent with the session on success', () async {
    final repo = _FakeIdentityVerificationRepository();
    final container = buildContainer(repo: repo);

    final controller = container.read(verificationControllerProvider.notifier);
    expect(controller.state.step, VerificationStep.idle);

    await controller.start();

    expect(controller.state.step, VerificationStep.awaitingConsent);
    expect(controller.state.session?.sessionId, 'session-1');
    expect(repo.startCallCount, 1);
  });

  test('start() fails with UnauthorizedException-shaped error when signed out', () async {
    final container = buildContainer(user: null);
    final controller = container.read(verificationControllerProvider.notifier);

    await controller.start();

    expect(controller.state.step, VerificationStep.failed);
    expect(controller.state.error, isNotNull);
  });

  test('start() surfaces a repository error as failed', () async {
    final repo = _FakeIdentityVerificationRepository()..errorOnStart = Exception('boom');
    final container = buildContainer(repo: repo);
    final controller = container.read(verificationControllerProvider.notifier);

    await controller.start();

    expect(controller.state.step, VerificationStep.failed);
    expect(controller.state.error, isNotNull);
  });

  test('confirmConsentAndPoll() reaches verified once the status settles', () async {
    final repo = _FakeIdentityVerificationRepository()
      ..statusSequence = [
        DanVerificationStatus.pending,
        DanVerificationStatus.pending,
        DanVerificationStatus.verified,
      ];
    final container = buildContainer(repo: repo);
    final controller = container.read(verificationControllerProvider.notifier);

    await controller.start();
    await controller.confirmConsentAndPoll();

    expect(controller.state.step, VerificationStep.verified);
  });

  test('confirmConsentAndPoll() times out after the max attempts stay pending', () async {
    final repo = _FakeIdentityVerificationRepository()..statusSequence = const [];
    // Empty sequence -> checkStatus always returns pending (see fake above).
    final container = buildContainer(repo: repo);
    final controller = container.read(verificationControllerProvider.notifier);

    await controller.start();
    await controller.confirmConsentAndPoll();

    expect(controller.state.step, VerificationStep.failed);
    expect(controller.state.error, isA<VerificationTimeoutException>());
  });

  test('confirmConsentAndPoll() fails cleanly when the backend reports failed', () async {
    final repo = _FakeIdentityVerificationRepository()
      ..statusSequence = [DanVerificationStatus.failed];
    final container = buildContainer(repo: repo);
    final controller = container.read(verificationControllerProvider.notifier);

    await controller.start();
    await controller.confirmConsentAndPoll();

    expect(controller.state.step, VerificationStep.failed);
    expect(controller.state.error, isA<VerificationNotCompletedException>());
  });

  test('reset() returns to idle with no session or error', () async {
    final repo = _FakeIdentityVerificationRepository()..errorOnStart = Exception('boom');
    final container = buildContainer(repo: repo);
    final controller = container.read(verificationControllerProvider.notifier);

    await controller.start();
    expect(controller.state.step, VerificationStep.failed);

    controller.reset();

    expect(controller.state.step, VerificationStep.idle);
    expect(controller.state.session, isNull);
    expect(controller.state.error, isNull);
  });
}
