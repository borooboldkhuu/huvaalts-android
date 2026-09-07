import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../admin/domain/entities/report_target_type.dart';
import '../../domain/repositories/report_repository.dart';

class SupabaseReportRepository implements ReportRepository {
  SupabaseReportRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> submit({
    required ReportTargetType targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const UnauthorizedException(message: 'auth_required');
    }
    try {
      await _client.from('reports').insert({
        'reporter_id': userId,
        'target_type': targetType.id,
        'target_id': targetId,
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      });
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }
}
