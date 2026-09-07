import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/constants/app_constants.dart';

/// "✓ Баталгаатай хэрэглэгч" badge (spec section 10). Never displays the
/// underlying verification payload — only the coarse level.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({required this.level, this.compact = false, super.key});

  /// One of [AppConstants.verificationLevelPhone]..[verificationLevelBusiness].
  final int level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (level < AppConstants.verificationLevelDan) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final Color color = theme.colorScheme.primary;

    if (compact) {
      return Icon(Icons.verified_rounded, size: 16, color: color);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context).verifiedUser,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
