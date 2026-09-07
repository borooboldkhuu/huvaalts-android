import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../shared/entities/app_banner.dart';
import 'admin_providers.dart';

class AdminBannerFormState {
  const AdminBannerFormState({
    this.pickedImageBytes,
    this.isSubmitting = false,
  });

  final Uint8List? pickedImageBytes;
  final bool isSubmitting;

  AdminBannerFormState copyWith({Uint8List? pickedImageBytes, bool? isSubmitting}) {
    return AdminBannerFormState(
      pickedImageBytes: pickedImageBytes ?? this.pickedImageBytes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

/// Owns the create/edit banner form's one genuinely async piece — a
/// newly-picked replacement image, if any — plus the submit action.
/// Mirrors `AssetCreateController`'s split between plain
/// `TextEditingController`s (sort order, on the screen itself) and this
/// controller for the image (see that class's own doc comment for why).
class AdminBannerFormController extends Notifier<AdminBannerFormState> {
  @override
  AdminBannerFormState build() => const AdminBannerFormState();

  /// Opens the system photo picker. `imageQuality`/`maxWidth` do the
  /// compression work, same as `AssetCreateController.addImages` —
  /// this project doesn't wire up `image_cropper` for the same reason
  /// that class documents (no Flutter SDK in this sandbox to run and
  /// check its native crop UI against).
  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
    if (picked == null) return;
    final Uint8List bytes = await picked.readAsBytes();
    state = state.copyWith(pickedImageBytes: bytes);
  }

  /// Resets picked-image state — called after a successful save so
  /// navigating back to a fresh "add banner" form doesn't show the
  /// previous banner's image still attached.
  void reset() {
    state = const AdminBannerFormState();
  }

  /// Uploads [pickedImageBytes] to the `app-banners` bucket (if the admin
  /// picked a new/replacement image this session) and upserts the row.
  /// [existingStoragePath] is reused unchanged when editing without
  /// replacing the image — a banner can never end up with no image at
  /// all, matching `admin_upsert_app_banner`'s own `image_required`
  /// check (0023_app_banners.sql). The screen itself validates that a
  /// *new* banner has a picked image before ever calling this (see
  /// `AdminBannerFormScreen._submit`) — the `StateError` here is a
  /// last-resort guard, not the primary validation path.
  Future<AppBanner> submit({
    String? id,
    String? existingStoragePath,
    required int sortOrder,
    required bool isActive,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final String storagePath;
      final Uint8List? bytes = state.pickedImageBytes;
      if (bytes != null) {
        const Uuid uuid = Uuid();
        final String path = '${uuid.v4()}.jpg';
        await ref
            .read(supabaseClientProvider)
            .storage
            .from(AppBanner.storageBucket)
            .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: false));
        storagePath = path;
      } else if (existingStoragePath != null) {
        storagePath = existingStoragePath;
      } else {
        throw StateError('no image picked and no existing banner image to keep');
      }

      final AppBanner result = await ref.read(adminRepositoryProvider).upsertAppBanner(
            id: id,
            storagePath: storagePath,
            sortOrder: sortOrder,
            isActive: isActive,
          );
      ref.invalidate(adminAppBannersProvider);
      return result;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}

final NotifierProvider<AdminBannerFormController, AdminBannerFormState>
    adminBannerFormControllerProvider =
    NotifierProvider<AdminBannerFormController, AdminBannerFormState>(AdminBannerFormController.new);
