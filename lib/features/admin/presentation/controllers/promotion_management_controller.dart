import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/promotion.dart';
import 'admin_providers.dart';

class PromotionManagementState {
  const PromotionManagementState({this.isSubmitting = false});

  final bool isSubmitting;
}

class PromotionManagementController extends Notifier<PromotionManagementState> {
  @override
  PromotionManagementState build() => const PromotionManagementState();

  Future<Promotion> upsert({
    String? id,
    String? code,
    required String title,
    String? description,
    double? discountPercent,
    required DateTime startsAt,
    required DateTime endsAt,
    required bool isActive,
  }) async {
    state = const PromotionManagementState(isSubmitting: true);
    try {
      final Promotion result = await ref.read(adminRepositoryProvider).upsertPromotion(
            id: id,
            code: code,
            title: title,
            description: description,
            discountPercent: discountPercent,
            startsAt: startsAt,
            endsAt: endsAt,
            isActive: isActive,
          );
      ref.invalidate(adminPromotionsProvider);
      return result;
    } finally {
      state = const PromotionManagementState(isSubmitting: false);
    }
  }

  Future<Promotion> deactivate(String id) async {
    state = const PromotionManagementState(isSubmitting: true);
    try {
      final Promotion result = await ref.read(adminRepositoryProvider).deactivatePromotion(id);
      ref.invalidate(adminPromotionsProvider);
      return result;
    } finally {
      state = const PromotionManagementState(isSubmitting: false);
    }
  }
}

final NotifierProvider<PromotionManagementController, PromotionManagementState>
    promotionManagementControllerProvider =
    NotifierProvider<PromotionManagementController, PromotionManagementState>(
        PromotionManagementController.new);
