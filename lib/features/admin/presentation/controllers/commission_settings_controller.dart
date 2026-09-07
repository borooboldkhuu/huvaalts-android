import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/platform_settings.dart';
import 'admin_providers.dart';

class CommissionSettingsState {
  const CommissionSettingsState({this.isSubmitting = false});

  final bool isSubmitting;
}

class CommissionSettingsController extends Notifier<CommissionSettingsState> {
  @override
  CommissionSettingsState build() => const CommissionSettingsState();

  Future<PlatformSettings> update(double percent) async {
    state = const CommissionSettingsState(isSubmitting: true);
    try {
      final PlatformSettings result =
          await ref.read(adminRepositoryProvider).updateCommissionPercent(percent);
      ref.invalidate(platformSettingsProvider);
      return result;
    } finally {
      state = const CommissionSettingsState(isSubmitting: false);
    }
  }
}

final NotifierProvider<CommissionSettingsController, CommissionSettingsState>
    commissionSettingsControllerProvider =
    NotifierProvider<CommissionSettingsController, CommissionSettingsState>(
        CommissionSettingsController.new);
