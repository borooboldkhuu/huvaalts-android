import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/condition_report.dart';
import '../../domain/entities/condition_report_stage.dart';
import '../../domain/repositories/condition_report_repository.dart';

class SupabaseConditionReportRepository implements ConditionReportRepository {
  SupabaseConditionReportRepository(this._client);

  final SupabaseClient _client;

  static const String _bucket = 'condition-reports';
  static const Uuid _uuid = Uuid();

  @override
  Future<ConditionReport?> getReport(String bookingId, ConditionReportStage stage) async {
    try {
      final Map<String, dynamic>? row = await _client
          .from('condition_reports')
          .select()
          .eq('booking_id', bookingId)
          .eq('stage', stage.id)
          .maybeSingle();
      if (row == null) return null;
      return _fromRow(row);
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<ConditionReport> submitReport({
    required String bookingId,
    required ConditionReportStage stage,
    required List<(Uint8List bytes, String fileExtension)> photos,
    String? notes,
  }) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const UnauthorizedException(message: 'auth_required');
    }

    // Best-effort upload, one at a time — same reasoning as
    // SupabaseAssetRepository.createAsset's photo loop: a report that
    // documents *something* is more useful than no report at all just
    // because one photo failed to upload.
    final List<String> uploadedPaths = [];
    for (final (Uint8List bytes, String extension) in photos) {
      final String path = '$bookingId/${stage.id}/${_uuid.v4()}.$extension';
      try {
        await _client.storage
            .from(_bucket)
            .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: false));
        uploadedPaths.add(path);
      } catch (_) {
        continue;
      }
    }

    try {
      final Map<String, dynamic> row = await _client
          .from('condition_reports')
          .insert({
            'booking_id': bookingId,
            'stage': stage.id,
            'submitted_by': userId,
            'photo_paths': uploadedPaths,
            'notes': notes,
          })
          .select()
          .single();
      return _fromRow(row);
    } on PostgrestException catch (e) {
      throw _mapInsertError(e);
    }
  }

  @override
  Future<ConditionReport> confirmReport(String reportId) async {
    try {
      final dynamic response = await _client.rpc<dynamic>(
        'confirm_condition_report',
        params: {'p_report_id': reportId},
      );
      return _fromRow(response as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw _mapRpcError(e);
    }
  }

  @override
  Future<String> signedPhotoUrl(String path) async {
    try {
      return await _client.storage.from(_bucket).createSignedUrl(path, 600);
    } on StorageException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  AppException _mapInsertError(PostgrestException e) {
    return switch (e.message) {
      'booking_not_found' => const NotFoundException(message: 'not_found'),
      'not_authorized' => const ForbiddenException(message: 'not_authorized'),
      'booking_disputed' => const ConflictException(message: 'booking_disputed'),
      'invalid_status_for_pickup_report' ||
      'invalid_status_for_return_report' =>
        const ConflictException(message: 'invalid_status_transition'),
      'payment_required_before_pickup' =>
        const ValidationException(message: 'payment_required_before_pickup'),
      _ => UnknownException(message: e.message, cause: e),
    };
  }

  AppException _mapRpcError(PostgrestException e) {
    return switch (e.message) {
      'auth_required' => const UnauthorizedException(message: 'auth_required'),
      'not_authorized' => const ForbiddenException(message: 'not_authorized'),
      'report_not_found' || 'booking_not_found' => const NotFoundException(message: 'not_found'),
      'booking_disputed' => const ConflictException(message: 'booking_disputed'),
      _ => UnknownException(message: e.message, cause: e),
    };
  }

  ConditionReport _fromRow(Map<String, dynamic> row) {
    return ConditionReport(
      id: row['id'] as String,
      bookingId: row['booking_id'] as String,
      stage: ConditionReportStage.fromId(row['stage'] as String),
      submittedBy: row['submitted_by'] as String,
      photoPaths: (row['photo_paths'] as List<dynamic>? ?? const []).cast<String>(),
      notes: row['notes'] as String?,
      confirmedByRenterAt: row['confirmed_by_renter_at'] == null
          ? null
          : DateTime.parse(row['confirmed_by_renter_at'] as String),
      confirmedByOwnerAt: row['confirmed_by_owner_at'] == null
          ? null
          : DateTime.parse(row['confirmed_by_owner_at'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
