import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/condition_report.dart';
import '../../domain/entities/condition_report_stage.dart';
import 'condition_report_providers.dart';

/// Hard cap on photos per condition report — same reasoning and same
/// number as `kMaxAssetPhotos` (`AssetCreateController`): a documented,
/// deliberate limit rather than an unbounded upload.
const int kMaxConditionReportPhotos = 8;

class SubmitConditionReportState {
  const SubmitConditionReportState({
    this.photos = const [],
    this.isSubmitting = false,
  });

  final List<(Uint8List bytes, String fileExtension)> photos;
  final bool isSubmitting;

  SubmitConditionReportState copyWith({
    List<(Uint8List, String)>? photos,
    bool? isSubmitting,
  }) {
    return SubmitConditionReportState(
      photos: photos ?? this.photos,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

/// Owns a condition report form's photo-picking state plus the submit
/// action — the same split `AssetCreateController` uses (photos are the
/// only genuinely async/stateful field; notes lives in a plain
/// `TextEditingController` on the screen).
class SubmitConditionReportController extends Notifier<SubmitConditionReportState> {
  @override
  SubmitConditionReportState build() => const SubmitConditionReportState();

  Future<void> addPhotos() async {
    final int remaining = kMaxConditionReportPhotos - state.photos.length;
    if (remaining <= 0) return;

    final ImagePicker picker = ImagePicker();
    final List<XFile> picked = await picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
    if (picked.isEmpty) return;

    final List<(Uint8List, String)> converted = [];
    for (final XFile file in picked.take(remaining)) {
      final bytes = await file.readAsBytes();
      converted.add((bytes, _extensionOf(file.name)));
    }
    state = state.copyWith(photos: [...state.photos, ...converted]);
  }

  void removePhotoAt(int index) {
    final List<(Uint8List, String)> updated = List.of(state.photos)..removeAt(index);
    state = state.copyWith(photos: updated);
  }

  Future<ConditionReport> submit({
    required String bookingId,
    required ConditionReportStage stage,
    String? notes,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final ConditionReport report =
          await ref.read(conditionReportRepositoryProvider).submitReport(
                bookingId: bookingId,
                stage: stage,
                photos: state.photos,
                notes: notes,
              );
      state = state.copyWith(isSubmitting: false);
      return report;
    } catch (_) {
      state = state.copyWith(isSubmitting: false);
      rethrow;
    }
  }

  String _extensionOf(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return 'jpg';
    return fileName.substring(dot + 1).toLowerCase();
  }
}

final NotifierProvider<SubmitConditionReportController, SubmitConditionReportState>
    submitConditionReportControllerProvider =
    NotifierProvider<SubmitConditionReportController, SubmitConditionReportState>(
  SubmitConditionReportController.new,
);

/// Separate, tiny controller for the *other* participant's confirmation —
/// kept apart from [SubmitConditionReportController] since confirming has
/// no photo/notes state of its own, just an in-flight flag.
class ConfirmConditionReportState {
  const ConfirmConditionReportState({this.isSubmitting = false});

  final bool isSubmitting;
}

class ConfirmConditionReportController extends Notifier<ConfirmConditionReportState> {
  @override
  ConfirmConditionReportState build() => const ConfirmConditionReportState();

  Future<ConditionReport> confirm(String reportId) async {
    state = const ConfirmConditionReportState(isSubmitting: true);
    try {
      final ConditionReport report =
          await ref.read(conditionReportRepositoryProvider).confirmReport(reportId);
      state = const ConfirmConditionReportState();
      return report;
    } catch (_) {
      state = const ConfirmConditionReportState();
      rethrow;
    }
  }
}

final NotifierProvider<ConfirmConditionReportController, ConfirmConditionReportState>
    confirmConditionReportControllerProvider =
    NotifierProvider<ConfirmConditionReportController, ConfirmConditionReportState>(
  ConfirmConditionReportController.new,
);
