import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../admin/presentation/controllers/admin_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/profile.dart';
import '../controllers/profile_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        // Left-aligned, per the reference design — not the platform's
        // default centered title.
        centerTitle: false,
        title: Text(l10n.profileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.language_rounded),
            tooltip: l10n.settingsLanguage,
            onPressed: () => context.pushNamed(RouteNames.settingsLanguage),
          ),
        ],
      ),
      body: authState.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: SkeletonCard(),
        ),
        error: (error, stack) => Center(
          child: Text('$error', style: theme.textTheme.bodyMedium),
        ),
        data: (user) {
          if (user == null) {
            return EmptyState(
              title: l10n.authSignedOut,
              icon: Icons.person_outline,
            );
          }
          return Consumer(
            builder: (context, ref, _) {
              final profileAsync = ref.watch(profileProvider(user.id));
              return profileAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: SkeletonCard(),
                ),
                error: (error, stack) => ErrorStateView(
                  failure: Failure.from(error),
                  onRetry: () => ref.invalidate(profileProvider(user.id)),
                ),
                data: (profile) => _ProfileContent(profile: profile),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppColors colors = context.colors;
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            // Reference design's tinted-circle avatar (a light accent wash
            // behind a filled person glyph) rather than a bare grey
            // placeholder — only shown when there's no real photo.
            // `accentSoft` (the design spec's pale-yellow tint), not a raw
            // opacity wash — same token Wallet's balance panel now uses,
            // so every "soft yellow surface" in the app reads as one
            // deliberate color rather than several ad-hoc tints.
            backgroundColor: profile.avatarUrl == null ? colors.accentSoft : null,
            backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
            child: profile.avatarUrl == null
                ? Icon(Icons.person_rounded, size: 40, color: colors.accent)
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(profile.displayName, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Center(child: VerifiedBadge(level: profile.verificationLevel)),
        const SizedBox(height: AppSpacing.xxl),
        // Soft card, matching Wallet's balance panel and the rest of the
        // redesign's "component sits in a lightly-lifted surface" motif —
        // was a bare `Row` floating directly on the scaffold background.
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatColumn(label: l10n.profileCompletedRentals, value: '${profile.completedRentalsCount}'),
              GestureDetector(
                onTap: () => context.pushNamed(RouteNames.myAssets),
                child: _StatColumn(label: l10n.profileAssets, value: '${profile.assetsCount}'),
              ),
              GestureDetector(
                onTap: () => context.pushNamed(RouteNames.myReviews),
                child: _StatColumn(label: l10n.profileReviews, value: '${profile.reviewCount}'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        // `goNamed`, not `pushNamed` — Захиалга/Хэтэвч are bottom tabs
        // (AppShell) now, so tapping these switches to that tab (and
        // highlights it in the nav bar) instead of pushing a duplicate
        // screen with no nav bar on top of Профайл.
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_note_outlined),
          title: Text(l10n.myBookingsTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.goNamed(RouteNames.myBookings),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: Text(l10n.profileWalletAction),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.goNamed(RouteNames.wallet),
        ),
        if (profile.verificationLevel < AppConstants.verificationLevelDan)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.verified_user_outlined),
            title: Text(l10n.profileGetVerifiedAction),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed(RouteNames.verification),
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.verified_user_outlined, color: theme.colorScheme.primary),
            title: Text(l10n.profileAlreadyVerifiedLabel),
          ),
        // Admin dashboard entry point (Phase 11) — only shown once
        // `isAdminProvider` actually resolves true. This is a UX
        // convenience only; every admin RPC re-checks `is_admin` itself
        // regardless of whether this tile is visible (spec section 34:
        // never trust the client as the authorization boundary).
        Consumer(
          builder: (context, ref, _) {
            final isAdminAsync = ref.watch(isAdminProvider);
            final bool isAdmin = isAdminAsync.value ?? false;
            if (!isAdmin) return const SizedBox.shrink();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: Text(l10n.profileAdminAction),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed(RouteNames.adminDashboard),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xxl),
        const Divider(),
        // Account-level action, not a browse-feed one — belongs here, not
        // floating at the bottom of the Нүүр discovery feed.
        Consumer(
          builder: (context, ref, _) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout, color: theme.colorScheme.error),
              title: Text(
                l10n.profileSignOut,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
              ),
              onTap: () => ref.read(authControllerProvider.notifier).signOut(),
            );
          },
        ),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
