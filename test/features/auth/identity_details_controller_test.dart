import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/core/errors/app_exception.dart';
import 'package:huvalts/core/errors/failure.dart';
import 'package:huvalts/features/auth/domain/entities/app_user.dart';
import 'package:huvalts/features/auth/domain/repositories/auth_repository.dart';
import 'package:huvalts/features/auth/domain/repositories/identity_details_repository.dart';
import 'package:huvalts/features/auth/presentation/controllers/auth_providers.dart';
import 'package:huvalts/features/auth/presentation/controllers/identity_details_controller.dart';
import 'package:huvalts/features/profile/domain/entities/profile.dart';
import 'package:huvalts/features/profile/domain/repositories/profile_repository.dart';
import 'package:huvalts/features/profile/presentation/controllers/profile_controller.dart';

AppUser _user({String displayName = ''}) {
  return AppUser(
    id: 'user-1',
    phone: '+97699112233',
    email: null,
    displayName: displayName,
    avatarUrl: null,
    verificationLevel: 0,
    createdAt: DateTime(2026, 1, 1),
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

class _FakeIdentityDetailsRepository implements IdentityDetailsRepository {
  String? lastUserId;
  String? lastSurname;
  String? lastGivenName;
  String? lastRegisterNumber;
  int submitCallCount = 0;
  Object? errorToThrow;

  @override
  Future<bool> exists(String userId) async => submitCallCount > 0;

  @override
  Future<void> submit({
    required String userId,
    required String surname,
    required String givenName,
    required String registerNumber,
  }) async {
    submitCallCount++;
    lastUserId = userId;
    lastSurname = surname;
    lastGivenName = givenName;
    lastRegisterNumber = registerNumber;
    if (errorToThrow != null) throw errorToThrow!;
  }
}

class _FakeProfileRepository implements ProfileRepository {
  String? lastUpdatedUserId;
  String? lastUpdatedDisplayName;
  int updateCallCount = 0;

  @override
  Future<Profile> getProfile(String userId) async => throw UnimplementedError();

  @override
  Future<Profile> updateDisplayName({required String userId, required String displayName}) async {
    updateCallCount++;
    lastUpdatedUserId = userId;
    lastUpdatedDisplayName = displayName;
    return Profile(
      userId: userId,
      displayName: displayName,
      avatarUrl: null,
      verificationLevel: 0,
      rating: 0,
      reviewCount: 0,
      completedRentalsCount: 0,
      assetsCount: 0,
      memberSince: DateTime(2026, 1, 1),
    );
  }
}

void main() {
  ProviderContainer buildContainer({
    AppUser? user,
    required _FakeIdentityDetailsRepository identityFake,
    ProfileRepository? profileFake,
  }) {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(userOverride: user)),
        identityDetailsRepositoryProvider.overrideWithValue(identityFake),
        profileRepositoryProvider.overrideWithValue(profileFake ?? _FakeProfileRepository()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('submit() with no signed-in user fails with unauthorized, never calls the repository', () async {
    final identityFake = _FakeIdentityDetailsRepository();
    final container = buildContainer(user: null, identityFake: identityFake);
    final controller = container.read(identityDetailsControllerProvider.notifier);

    await controller.submit(surname: 'Бат', givenName: 'Болд', registerNumber: 'АА12345678');

    expect(container.read(identityDetailsControllerProvider), isA<IdentityDetailsSubmitFailed>());
    final state = container.read(identityDetailsControllerProvider) as IdentityDetailsSubmitFailed;
    expect(state.failure, isA<AuthFailure>());
    expect(identityFake.submitCallCount, 0);
  });

  test('submit() success forwards exact fields and ends in Submitted', () async {
    final identityFake = _FakeIdentityDetailsRepository();
    final container = buildContainer(user: _user(displayName: 'Existing Name'), identityFake: identityFake);
    final controller = container.read(identityDetailsControllerProvider.notifier);

    await controller.submit(surname: 'Бат', givenName: 'Болд', registerNumber: 'АА12345678');

    expect(container.read(identityDetailsControllerProvider), isA<IdentityDetailsSubmitted>());
    expect(identityFake.lastUserId, 'user-1');
    expect(identityFake.lastSurname, 'Бат');
    expect(identityFake.lastGivenName, 'Болд');
    expect(identityFake.lastRegisterNumber, 'АА12345678');
  });

  test('submit() seeds display name from givenName when the user has none yet', () async {
    final identityFake = _FakeIdentityDetailsRepository();
    final profileFake = _FakeProfileRepository();
    final container = buildContainer(
      user: _user(displayName: ''),
      identityFake: identityFake,
      profileFake: profileFake,
    );
    final controller = container.read(identityDetailsControllerProvider.notifier);

    await controller.submit(surname: 'Бат', givenName: 'Болд', registerNumber: 'АА12345678');

    expect(profileFake.updateCallCount, 1);
    expect(profileFake.lastUpdatedDisplayName, 'Болд');
  });

  test('submit() never overwrites a display name the user already set', () async {
    final identityFake = _FakeIdentityDetailsRepository();
    final profileFake = _FakeProfileRepository();
    final container = buildContainer(
      user: _user(displayName: 'Already Set'),
      identityFake: identityFake,
      profileFake: profileFake,
    );
    final controller = container.read(identityDetailsControllerProvider.notifier);

    await controller.submit(surname: 'Бат', givenName: 'Болд', registerNumber: 'АА12345678');

    expect(profileFake.updateCallCount, 0);
  });

  test('submit() maps a duplicate register number to a ConflictFailure, not a crash', () async {
    final identityFake = _FakeIdentityDetailsRepository()
      ..errorToThrow = const ConflictException(message: 'register_number_already_used');
    final container = buildContainer(user: _user(), identityFake: identityFake);
    final controller = container.read(identityDetailsControllerProvider.notifier);

    await controller.submit(surname: 'Бат', givenName: 'Болд', registerNumber: 'АА12345678');

    final state = container.read(identityDetailsControllerProvider) as IdentityDetailsSubmitFailed;
    expect(state.failure, isA<ConflictFailure>());
    expect(state.failure.message, 'register_number_already_used');
  });

  test('a display-name seeding failure does not undo an already-successful submit', () async {
    final identityFake = _FakeIdentityDetailsRepository();
    final profileFake = _ThrowingProfileRepository();
    final container = buildContainer(
      user: _user(displayName: ''),
      identityFake: identityFake,
      profileFake: profileFake,
    );
    final controller = container.read(identityDetailsControllerProvider.notifier);

    await controller.submit(surname: 'Бат', givenName: 'Болд', registerNumber: 'АА12345678');

    expect(container.read(identityDetailsControllerProvider), isA<IdentityDetailsSubmitted>(),
        reason: 'the identity_details row was saved successfully — a best-effort display-name '
            'seeding failure afterward must not be reported as an overall failure');
  });

  test('reset() returns to Idle', () async {
    final identityFake = _FakeIdentityDetailsRepository();
    final container = buildContainer(user: _user(), identityFake: identityFake);
    final controller = container.read(identityDetailsControllerProvider.notifier);
    await controller.submit(surname: 'Бат', givenName: 'Болд', registerNumber: 'АА12345678');
    expect(container.read(identityDetailsControllerProvider), isA<IdentityDetailsSubmitted>());

    controller.reset();

    expect(container.read(identityDetailsControllerProvider), isA<IdentityDetailsIdle>());
  });
}

class _ThrowingProfileRepository implements ProfileRepository {
  @override
  Future<Profile> getProfile(String userId) async => throw UnimplementedError();

  @override
  Future<Profile> updateDisplayName({required String userId, required String displayName}) async {
    throw Exception('boom');
  }
}
