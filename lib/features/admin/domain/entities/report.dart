import 'package:freezed_annotation/freezed_annotation.dart';

import 'report_status.dart';
import 'report_target_type.dart';

part 'report.freezed.dart';
part 'report.g.dart';

/// A `public.reports` row (spec section 30) — abuse/content reports a
/// user files against another user, asset, message, or review. Existed
/// since Phase 0/1's schema with an insert-only client policy; resolving
/// one is new in Phase 11 (`admin_resolve_report`).
@freezed
abstract class Report with _$Report {
  const factory Report({
    required String id,
    required String reporterId,
    required ReportTargetType targetType,
    required String targetId,
    required String reason,
    required String? details,
    required ReportStatus status,
    required DateTime createdAt,
    required DateTime? resolvedAt,
  }) = _Report;

  factory Report.fromJson(Map<String, dynamic> json) => _$ReportFromJson(json);
}
