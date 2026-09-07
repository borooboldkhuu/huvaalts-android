import 'dart:math';

import '../../domain/repositories/identity_verification_repository.dart';
import 'dan_auth_service.dart';

/// Fully functional mock of the DAN verification flow, isolated behind the
/// [DanAuthService] interface so production credentials can be dropped in
/// later (a new adapter class + one line in [DanAuthServiceFactory]) with
/// zero changes to controllers or screens.
///
/// Behavior: `startSession` returns a fake consent URL immediately.
/// `pollStatus` simulates backend processing — the first couple of polls
/// return `pending`, then settles to `verified` deterministically per
/// session so UI/tests are stable and don't flake.
class MockDanAuthAdapter implements DanAuthService {
  final Map<String, int> _pollCounts = {};

  @override
  Future<DanVerificationSession> startSession({required String userId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final String sessionId = 'mock-dan-${userId}-${Random().nextInt(1 << 32)}';
    return DanVerificationSession(
      sessionId: sessionId,
      // Placeholder — a production adapter returns the real DAN consent
      // URL as returned by the backend `/auth/dan/start` endpoint.
      consentUrl: 'https://mock-dan.local/consent?session=$sessionId',
      status: DanVerificationStatus.pending,
    );
  }

  @override
  Future<DanVerificationStatus> pollStatus({required String sessionId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final int count = (_pollCounts[sessionId] ?? 0) + 1;
    _pollCounts[sessionId] = count;
    if (count < 2) return DanVerificationStatus.pending;
    return DanVerificationStatus.verified;
  }
}
