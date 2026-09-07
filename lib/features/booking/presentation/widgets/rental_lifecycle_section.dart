import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../disputes/domain/entities/dispute.dart';
import '../../../disputes/presentation/controllers/dispute_providers.dart';
import '../../../disputes/presentation/widgets/dispute_status_label.dart';
import '../../../reviews/presentation/controllers/review_providers.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/booking_status.dart';
import '../../domain/entities/condition_report.dart';
import '../../domain/entities/condition_report_stage.dart';
import '../controllers/condition_report_providers.dart';

/// Pickup/return condition reports, the review CTA, and the dispute CTA —
/// everything on Booking Detail that depends on the booking's status
/// having reached `confirmed`/`active`/`completed` (spec sections 25, 26,
/// 27; the state machine itself lives in
/// `supabase/migrations/0010_condition_reports_reviews_disputes.sql`).
/// Kept as its own widget rather than inline in `BookingDetailScreen`
/// since it independently watches four more providers (two condition
/// report stages, the review, the dispute) that screen has no other
/// reason to know about.
class RentalLifecycleSection extends ConsumerWidget {
  const RentalLifecycleSection({
    required this.booking,
    required this.currentUserId,
    super.key,
  });

  final Booking booking;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isParticipant =
        booking.isOwner(currentUserId) || booking.isRenter(currentUserId);
    if (!isParticipant) return const SizedBox.shrink();

    final disputeAsync = ref.watch(latestDisputeForBookingProvider(booking.id));
    final bool isDisputed = booking.status == BookingStatus.disputed;

    final List<Widget> children = [];

    if (booking.status == BookingStatus.confirmed || booking.status == BookingStatus.active) {
      children.add(
        _ConditionReportTile(
          booking: booking,
          currentUserId: currentUserId,
          stage: ConditionReportStage.pickup,
        ),
      );
    }
    if (booking.status == BookingStatus.active) {
      children.add(const SizedBox(height: AppSpacing.sm));
      children.add(
        _ConditionReportTile(
          booking: booking,
          currentUserId: currentUserId,
          stage: ConditionReportStage.return_,
        ),
      );
    }
    if (booking.status == BookingStatus.completed) {
      children.add(_ConditionReportSummaryTile(bookingId: booking.id, stage: ConditionReportStage.pickup));
      children.add(const SizedBox(height: AppSpacing.sm));
      children.add(_ConditionReportSummaryTile(bookingId: booking.id, stage: ConditionReportStage.return_));
      children.add(const SizedBox(height: AppSpacing.sm));
      children.add(_ReviewTile(bookingId: booking.id));
    }

    // Dispute CTA/status — shown whenever a dispute could exist for this
    // booking (matches validate_dispute_insert's allowed statuses) or
    // already does.
    final bool disputeEligible = booking.status == BookingStatus.confirmed ||
        booking.status == BookingStatus.active ||
        booking.status == BookingStatus.completed ||
        isDisputed;
    if (disputeEligible) {
      children.add(const SizedBox(height: AppSpacing.sm));
      children.add(
        disputeAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (dispute) => _DisputeTile(bookingId: booking.id, dispute: dispute, l10n: l10n),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Text(l10n.rentalLifecycleSectionTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        ...children,
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData trailingIcon = Icons.chevron_right;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (onTap != null) Icon(trailingIcon, color: theme.disabledColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConditionReportTile extends ConsumerWidget {
  const _ConditionReportTile({
    required this.booking,
    required this.currentUserId,
    required this.stage,
  });

  final Booking booking;
  final String currentUserId;
  final ConditionReportStage stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final reportAsync =
        ref.watch(conditionReportProvider((bookingId: booking.id, stage: stage)));
    final String title = stage == ConditionReportStage.pickup
        ? l10n.conditionReportPickupTitle
        : l10n.conditionReportReturnTitle;

    return reportAsync.when(
      loading: () => _ActionTile(title: title, subtitle: l10n.commonLoading, onTap: null),
      error: (_, __) => const SizedBox.shrink(),
      data: (report) {
        String subtitle;
        if (report == null) {
          subtitle = l10n.conditionReportNotSubmittedYet;
        } else if (report.isFullyConfirmed) {
          subtitle = l10n.conditionReportFullyConfirmedNotice;
        } else if (report.needsConfirmationFrom(
          userId: currentUserId,
          renterId: booking.renterId,
          ownerId: booking.ownerId,
        )) {
          subtitle = l10n.conditionReportAwaitingYourConfirmation;
        } else {
          subtitle = l10n.conditionReportWaitingOnOtherPartyNotice;
        }
        return _ActionTile(
          title: title,
          subtitle: subtitle,
          onTap: () => context.pushNamed(
            RouteNames.bookingConditionReport,
            pathParameters: {'id': booking.id, 'stage': stage.id},
          ),
        );
      },
    );
  }
}

class _ConditionReportSummaryTile extends ConsumerWidget {
  const _ConditionReportSummaryTile({required this.bookingId, required this.stage});

  final String bookingId;
  final ConditionReportStage stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final reportAsync = ref.watch(conditionReportProvider((bookingId: bookingId, stage: stage)));
    final String title = stage == ConditionReportStage.pickup
        ? l10n.conditionReportPickupTitle
        : l10n.conditionReportReturnTitle;

    return reportAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (ConditionReport? report) {
        if (report == null) return const SizedBox.shrink();
        return _ActionTile(
          title: title,
          subtitle: l10n.conditionReportFullyConfirmedNotice,
          onTap: () => context.pushNamed(
            RouteNames.bookingConditionReport,
            pathParameters: {'id': bookingId, 'stage': stage.id},
          ),
        );
      },
    );
  }
}

class _ReviewTile extends ConsumerWidget {
  const _ReviewTile({required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final reviewAsync = ref.watch(myReviewForBookingProvider(bookingId));

    return reviewAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (review) {
        if (review == null) {
          return _ActionTile(
            title: l10n.reviewScreenTitle,
            subtitle: l10n.reviewNotLeftYetNotice,
            onTap: () => context.pushNamed(
              RouteNames.bookingReview,
              pathParameters: {'id': bookingId},
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(l10n.reviewAlreadyLeftNotice, style: Theme.of(context).textTheme.bodyMedium),
              ),
              StarRating(rating: review.rating, size: 16),
            ],
          ),
        );
      },
    );
  }
}

class _DisputeTile extends StatelessWidget {
  const _DisputeTile({required this.bookingId, required this.dispute, required this.l10n});

  final String bookingId;
  final Dispute? dispute;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // `dispute` is a public widget field, not a local variable, so Dart's
    // null-check promotion from `dispute == null` in the condition below
    // doesn't carry into the ':' branch — capture it locally first so the
    // analyzer can promote it there instead of unconditionally accessing
    // `.status` on a still-nullable receiver.
    final Dispute? currentDispute = dispute;
    final String subtitle = currentDispute == null
        ? l10n.disputeNotRaisedNotice
        : disputeStatusLabel(currentDispute.status, l10n);
    return _ActionTile(
      title: l10n.disputeScreenTitle,
      subtitle: subtitle,
      onTap: () => context.pushNamed(RouteNames.bookingDispute, pathParameters: {'id': bookingId}),
    );
  }
}
