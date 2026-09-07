import 'package:freezed_annotation/freezed_annotation.dart';

part 'platform_settings.freezed.dart';
part 'platform_settings.g.dart';

/// The single-row `public.platform_settings` table (`id` fixed at `1` by
/// a check constraint — `0012_admin_dashboard.sql`). Currently just the
/// commission rate `create_booking` reads at booking time (replacing the
/// hardcoded 10% every earlier phase used); a natural place to grow other
/// platform-wide knobs later.
@freezed
abstract class PlatformSettings with _$PlatformSettings {
  const factory PlatformSettings({
    required double commissionPercent,
    required DateTime updatedAt,
    required String? updatedBy,
  }) = _PlatformSettings;

  factory PlatformSettings.fromJson(Map<String, dynamic> json) => _$PlatformSettingsFromJson(json);
}
