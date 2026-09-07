import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/new_asset_input.dart';
import 'asset_providers.dart';

/// Hard cap on photos per listing. The spec doesn't pin an exact number for
/// this MVP slice, so this is a deliberately chosen, documented limit
/// (typical marketplace apps sit in the 6-10 range) rather than an
/// unbounded upload.
const int kMaxAssetPhotos = 8;

class AssetCreateState {
  const AssetCreateState({
    this.images = const [],
    this.isSubmitting = false,
  });

  final List<PickedAssetImage> images;
  final bool isSubmitting;

  AssetCreateState copyWith({List<PickedAssetImage>? images, bool? isSubmitting}) {
    return AssetCreateState(
      images: images ?? this.images,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

/// Owns the one piece of create-listing form state that's genuinely async
/// and stateful — the selected photos (picking from the device, reordering,
/// removing) — plus the submit action. Every other field (title,
/// description, prices, etc.) lives in plain `TextEditingController`s on
/// the screen itself and is only assembled into a [NewAssetInput] at
/// submit time, per that class's own doc comment: it's a one-shot transfer
/// object, not ongoing app state.
class AssetCreateController extends Notifier<AssetCreateState> {
  @override
  AssetCreateState build() => const AssetCreateState();

  /// Opens the system photo picker and appends whatever the user picks, up
  /// to [kMaxAssetPhotos] total. `imageQuality`/`maxWidth` do the
  /// compression work here — this project doesn't wire up `image_cropper`
  /// for this MVP slice (its native full-screen crop UI is a bigger surface
  /// to get right without a Flutter SDK to actually run and check it
  /// against), so photos go in uncropped but resized.
  Future<void> addImages() async {
    final int remaining = kMaxAssetPhotos - state.images.length;
    if (remaining <= 0) return;

    final ImagePicker picker = ImagePicker();
    final List<XFile> picked = await picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
    if (picked.isEmpty) return;

    final List<PickedAssetImage> converted = [];
    for (final XFile file in picked.take(remaining)) {
      final bytes = await file.readAsBytes();
      converted.add(PickedAssetImage(bytes: bytes, fileExtension: _extensionOf(file.name)));
    }
    state = state.copyWith(images: [...state.images, ...converted]);
  }

  void removeImageAt(int index) {
    final List<PickedAssetImage> updated = List.of(state.images)..removeAt(index);
    state = state.copyWith(images: updated);
  }

  void reorderImage(int oldIndex, int newIndex) {
    final List<PickedAssetImage> updated = List.of(state.images);
    if (newIndex > oldIndex) newIndex -= 1;
    final PickedAssetImage moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    state = state.copyWith(images: updated);
  }

  /// Resets photo state — called after a successful publish so navigating
  /// back to a fresh create form doesn't show the previous listing's
  /// photos still attached.
  void reset() {
    state = const AssetCreateState();
  }

  /// Creates the asset with whatever photos are currently attached.
  /// Rethrows on failure so the screen can show the error — this
  /// controller doesn't hold an error field itself since the caller needs
  /// the exception synchronously to decide what to show.
  Future<String> submit(NewAssetInput input) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final String id = await ref.read(assetRepositoryProvider).createAsset(input, state.images);
      return id;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  String _extensionOf(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return 'jpg';
    return fileName.substring(dot + 1).toLowerCase();
  }
}

final NotifierProvider<AssetCreateController, AssetCreateState> assetCreateControllerProvider =
    NotifierProvider<AssetCreateController, AssetCreateState>(AssetCreateController.new);
