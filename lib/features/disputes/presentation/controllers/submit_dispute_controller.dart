import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/dispute.dart';
import '../../domain/entities/dispute_category.dart';
import 'dispute_providers.dart';

/// Same documented, deliberate cap as photos elsewhere
/// (`kMaxAssetPhotos`, `kMaxConditionReportPhotos`).
const int kMaxDisputeEvidencePhotos = 8;

class SubmitDisputeState {
  const SubmitDisputeState({
    this.evidence = const [],
    this.isSubmitting = false,
  });

  final List<(Uint8List bytes, String fileExtension)> evidence;
  final bool isSubmitting;

  SubmitDisputeState copyWith({
    List<(Uint8List, String)>? evidence,
    bool? isSubmitting,
  }) {
    return SubmitDisputeState(
      evidence: evidence ?? this.evidence,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class SubmitDisputeController extends Notifier<SubmitDisputeState> {
  @override
  SubmitDisputeState build() => const SubmitDisputeState();

  Future<void> addEvidence() async {
    final int remaining = kMaxDisputeEvidencePhotos - state.evidence.length;
    if (remaining <= 0) return;

    final ImagePicker picker = ImagePicker();
    final List<XFile> picked = await picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
    if (picked.isEmpty) return;

    final List<(Uint8List, String)> converted = [];
    for (final XFile file in picked.take(remaining)) {
      final bytes = await file.readAsBytes();
      converted.add((bytes, _extensionOf(file.name)));
    }
    state = state.copyWith(evidence: [...state.evidence, ...converted]);
  }

  void removeEvidenceAt(int index) {
    final List<(Uint8List, String)> updated = List.of(state.evidence)..removeAt(index);
    state = state.copyWith(evidence: updated);
  }

  Future<Dispute> submit({
    required String bookingId,
    required DisputeCategory category,
    required String description,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final Dispute dispute = await ref.read(disputeRepositoryProvider).submitDispute(
            bookingId: bookingId,
            category: category,
            description: description,
            evidence: state.evidence,
          );
      state = state.copyWith(isSubmitting: false);
      return dispute;
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

final NotifierProvider<SubmitDisputeController, SubmitDisputeState> submitDisputeControllerProvider =
    NotifierProvider<SubmitDisputeController, SubmitDisputeState>(SubmitDisputeController.new);
