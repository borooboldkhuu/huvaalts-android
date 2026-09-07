import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/asset_categories.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/storage_urls.dart';
import '../../../../shared/widgets/asset_option_labels.dart';
import '../../../../shared/widgets/category_label.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../admin/domain/entities/report_target_type.dart';
import '../../../reports/presentation/widgets/report_sheet.dart';
import '../../domain/entities/asset_detail.dart';
// Aliased: this entity's name collides with Flutter's own `AssetImage`
// (an ImageProvider, exported by `material.dart`) — see
// `domain/entities/asset_image.dart`'s doc comment for the entity itself.
import '../../domain/entities/asset_image.dart' as entities;
import '../../domain/entities/owner_summary.dart';
import '../controllers/asset_providers.dart';

/// Full asset detail (spec section 16): gallery, title/rating/price,
/// owner card, description, specs, rules, a static cancellation policy
/// blurb, and a sticky bottom CTA. The CTA is a stub — booking
/// itself (availability calendar, date range, price breakdown) is Phase 4,
/// so it currently just tells the user that plainly rather than pretending
/// to start a flow that doesn't exist yet.
class AssetDetailScreen extends ConsumerWidget {
  const AssetDetailScreen({required this.assetId, super.key});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final detailAsync = ref.watch(assetDetailByIdProvider(assetId));
    final String? currentUserId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    // AppBar actions live at this level (not inside the `data:` branch)
    // so the bar itself doesn't rebuild/flash between loading and loaded
    // states — `.value` (riverpod 3.x; the pre-3.0 API for this was named
    // `valueOrNull`, since removed) just means "report this listing" only
    // appears once the detail has actually loaded and isn't the
    // viewer's own.
    final AssetDetail? loadedDetail = detailAsync.value;
    final bool canReportListing = loadedDetail != null && currentUserId != loadedDetail.owner.userId;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (canReportListing)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: l10n.reportAction,
              onPressed: () => showReportSheet(
                context,
                targetType: ReportTargetType.asset,
                targetId: assetId,
              ),
            ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: SkeletonCard(),
        ),
        error: (error, stack) => ErrorStateView(
          failure: Failure.from(error),
          onRetry: () => ref.invalidate(assetDetailByIdProvider(assetId)),
        ),
        data: (detail) {
          if (detail == null) {
            return EmptyState(title: l10n.errorNotFound, icon: Icons.search_off);
          }
          final bool isOwnListing = currentUserId == detail.owner.userId;
          // Don't count an owner looking at their own listing as a view.
          // Side-effect only — the tracked AsyncValue is intentionally
          // never read; see `assetViewTrackerProvider`'s doc comment.
          if (!isOwnListing) {
            ref.watch(assetViewTrackerProvider(assetId));
          }
          return _AssetDetailContent(detail: detail, isOwnListing: isOwnListing);
        },
      ),
    );
  }
}

class _AssetDetailContent extends StatelessWidget {
  const _AssetDetailContent({required this.detail, required this.isOwnListing});

  final AssetDetail detail;

  /// Hides the booking CTA — an owner can't book their own listing
  /// (`create_booking` would reject it with `cannot_book_own_asset`
  /// anyway; this just avoids showing a button that's guaranteed to fail).
  final bool isOwnListing;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final String? displayPricePerUnit = detail.pricePerDay != null
        ? CurrencyFormatter.formatPerUnit(detail.pricePerDay!, l10n.unitDay)
        : detail.pricePerHour != null
            ? CurrencyFormatter.formatPerUnit(detail.pricePerHour!, l10n.unitHour)
            : detail.pricePerWeek != null
                ? CurrencyFormatter.formatPerUnit(detail.pricePerWeek!, l10n.unitWeek)
                : null;

    // categoryId is stored as the raw AssetCategory.id string (see
    // supabase/migrations/0001_init_schema.sql — `categories.id` is text,
    // not a surrogate key) — resolve it back to the enum for the shared
    // label helper so this can never drift from the create form or the
    // category chip row.
    final AssetCategory category = AssetCategory.fromId(detail.categoryId);

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              _ImageGallery(images: detail.images),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail.title, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(categoryLabel(category, l10n), style: theme.textTheme.bodyMedium),
                    if (detail.assetReviewCount > 0) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${detail.assetRating.toStringAsFixed(1)} (${detail.assetReviewCount})',
                          ),
                        ],
                      ),
                    ],
                    if (detail.locationLabel != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 18, color: theme.colorScheme.secondary),
                          const SizedBox(width: 4),
                          Expanded(child: Text(detail.locationLabel!)),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    _OwnerCard(owner: detail.owner, isOwnListing: isOwnListing),
                    const SizedBox(height: AppSpacing.xxl),
                    if (detail.description.isNotEmpty) ...[
                      _SectionTitle(l10n.assetDetailSectionDescription),
                      const SizedBox(height: AppSpacing.sm),
                      Text(detail.description, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                    _SectionTitle(l10n.assetDetailSectionLogistics),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      pickupMethodLabel(detail.pickupMethod, l10n),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (detail.deliveryAvailable) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.local_shipping_outlined,
                              size: 16, color: theme.colorScheme.secondary),
                          const SizedBox(width: 4),
                          Text(l10n.assetDetailDeliveryAvailable, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],
                    if (detail.brand != null || detail.model != null || detail.condition != null) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      _SectionTitle(l10n.assetDetailSectionSpecifications),
                      const SizedBox(height: AppSpacing.sm),
                      if (detail.brand != null) _SpecRow(l10n.assetCreateBrandLabel, detail.brand!),
                      if (detail.model != null) _SpecRow(l10n.assetCreateModelLabel, detail.model!),
                      if (detail.condition != null)
                        _SpecRow(
                          l10n.assetCreateConditionLabel,
                          conditionLabel(detail.condition, l10n),
                        ),
                      for (final entry in detail.specifications.entries)
                        _SpecRow(entry.key, '${entry.value}'),
                    ],
                    if (detail.rules.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      _SectionTitle(l10n.assetDetailSectionRules),
                      const SizedBox(height: AppSpacing.sm),
                      for (final rule in detail.rules)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Text('• $rule', style: theme.textTheme.bodyMedium),
                        ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: theme.dividerColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.assetDetailCancellationTitle, style: theme.textTheme.titleSmall),
                          const SizedBox(height: AppSpacing.xs),
                          Text(l10n.assetDetailCancellationBody, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isOwnListing) _BookingBar(assetId: detail.id, priceLabel: displayPricePerUnit),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.owner, required this.isOwnListing});

  final OwnerSummary owner;

  /// Hides the "report user" action on a viewer's own listing — there's
  /// no legitimate reason to report yourself, same reasoning
  /// `_AssetDetailContent.isOwnListing` already uses to hide the booking
  /// CTA.
  final bool isOwnListing;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: owner.avatarUrl != null ? NetworkImage(owner.avatarUrl!) : null,
            child: owner.avatarUrl == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.assetDetailSectionOwner, style: theme.textTheme.labelSmall),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        owner.displayName,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    VerifiedBadge(level: owner.verificationLevel, compact: true),
                  ],
                ),
                Text(
                  l10n.assetDetailMemberSince(_formatYear(owner.memberSince)),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (owner.reviewCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.star_rounded, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 2),
                  Text('${owner.rating.toStringAsFixed(1)}'),
                ],
              ),
            ),
          if (!isOwnListing)
            IconButton(
              icon: const Icon(Icons.flag_outlined, size: 20),
              tooltip: l10n.reportAction,
              visualDensity: VisualDensity.compact,
              onPressed: () => showReportSheet(
                context,
                targetType: ReportTargetType.user,
                targetId: owner.userId,
              ),
            ),
        ],
      ),
    );
  }

  String _formatYear(DateTime date) => '${date.year}.${date.month.toString().padLeft(2, '0')}';
}

class _ImageGallery extends StatefulWidget {
  const _ImageGallery({required this.images});

  final List<entities.AssetImage> images;

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.images.isEmpty) {
      return AspectRatio(
        aspectRatio: 1.3,
        child: Container(
          color: theme.colorScheme.surface,
          child: const Icon(Icons.inventory_2_outlined, size: 56),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1.3,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final String? url = StorageUrls.assetImage(widget.images[i].storagePath);
              return url != null
                  ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, width: double.infinity)
                  : Container(color: theme.colorScheme.surface);
            },
          ),
          if (widget.images.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.images.length; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: i == _index ? 8 : 6,
                      height: i == _index ? 8 : 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _index ? Colors.white : Colors.white.withOpacity(0.5),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BookingBar extends StatelessWidget {
  const _BookingBar({required this.assetId, required this.priceLabel});

  final String assetId;
  final String? priceLabel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          children: [
            if (priceLabel != null)
              Expanded(child: Text(priceLabel!, style: theme.textTheme.titleMedium)),
            SizedBox(
              width: 160,
              child: PrimaryButton(
                label: l10n.assetDetailBookCta,
                onPressed: () => context.pushNamed(
                  RouteNames.bookingRequest,
                  pathParameters: {'id': assetId},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
