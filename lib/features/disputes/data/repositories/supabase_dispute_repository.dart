import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/dispute.dart';
import '../../domain/entities/dispute_category.dart';
import '../../domain/entities/dispute_status.dart';
import '../../domain/repositories/dispute_repository.dart';

class SupabaseDisputeRepository implements DisputeRepository {
  SupabaseDisputeRepository(this._client);

  final SupabaseClient _client;

  static const String _bucket = 'dispute-evidence';
  static const Uuid _uuid = Uuid();

  @override
  Future<Dispute?> getLatestDisputeForBooking(String bookingId) async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('disputes')
          .select()
          .eq('booking_id', bookingId)
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return _fromRow(rows.first);
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<Dispute> submitDispute({
    required String bookingId,
    required DisputeCategory category,
    required String description,
    required List<(Uint8List bytes, String fileExtension)> evidence,
  }) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const UnauthorizedException(message: 'auth_required');
    }

    final List<String> uploadedPaths = [];
    for (final (Uint8List bytes, String extension) in evidence) {
      final String path = '$bookingId/${_uuid.v4()}.$extension';
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
          .from('disputes')
          .insert({
            'booking_id': bookingId,
            'raised_by': userId,
            'category': category.id,
            'description': description,
            'evidence_paths': uploadedPaths,
          })
          .select()
          .single();
      return _fromRow(row);
    } on PostgrestException catch (e) {
      throw _mapInsertError(e);
    }
  }

  @override
  Future<String> signedEvidenceUrl(String path) async {
    try {
      return await _client.storage.from(_bucket).createSignedUrl(path, 600);
    } on StorageException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  AppException _mapInsertError(PostgrestException e) {
    return switch (e.message) {
      'booking_not_found' => const NotFoundException(message: 'not_found'),
      'dispute_already_open' => const ConflictException(message: 'dispute_already_open'),
      'booking_not_disputable' => const ValidationException(message: 'booking_not_disputable'),
      _ => UnknownException(message: e.message, cause: e),
    };
  }

  Dispute _fromRow(Map<String, dynamic> row) {
    return Dispute(
      id: row['id'] as String,
      bookingId: row['booking_id'] as String,
      raisedBy: row['raised_by'] as String,
      category: DisputeCategory.fromId(row['category'] as String),
      description: row['description'] as String,
      evidencePaths: (row['evidence_paths'] as List<dynamic>? ?? const []).cast<String>(),
      status: DisputeStatus.fromId(row['status'] as String),
      resolutionNotes: row['resolution_notes'] as String?,
      resolvedBy: row['resolved_by'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
