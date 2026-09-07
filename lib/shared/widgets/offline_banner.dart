import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/theme/app_spacing.dart';

/// Thin banner shown app-wide when connectivity drops. Never paired with a
/// false "success" state underneath — screens that depend on network state
/// (booking, payment) must independently disable their CTAs while offline
/// (spec section 42).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.error,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Text(
                AppLocalizations.of(context).errorNetwork,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
