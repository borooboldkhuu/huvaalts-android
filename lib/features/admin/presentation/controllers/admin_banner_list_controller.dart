import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_providers.dart';

class AdminBannerListState {
  const AdminBannerListState({this.isSubmitting = false});

  final bool isSubmitting;
}

/// The banner list screen's one action — delete — separate from
/// `AdminBannerFormController` (which owns the form's picked-image state)
/// the same way `PromotionManagementController`'s `deactivate` sits
/// alongside its `upsert`, just split into two files here since deleting
/// a banner has nothing to do with the form's image-upload state.
class AdminBannerListController extends Notifier<AdminBannerListState> {
  @override
  AdminBannerListState build() => const AdminBannerListState();

  Future<void> delete(String id) async {
    state = const AdminBannerListState(isSubmitting: true);
    try {
      await ref.read(adminRepositoryProvider).deleteAppBanner(id);
      ref.invalidate(adminAppBannersProvider);
    } finally {
      state = const AdminBannerListState(isSubmitting: false);
    }
  }
}

final NotifierProvider<AdminBannerListController, AdminBannerListState> adminBannerListControllerProvider =
    NotifierProvider<AdminBannerListController, AdminBannerListState>(AdminBannerListController.new);
