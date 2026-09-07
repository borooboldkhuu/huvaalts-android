import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/storage_urls.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../domain/entities/booking.dart';
import '../controllers/booking_providers.dart';
import '../widgets/booking_status_label.dart';

/// "Миний захиалгууд" (spec section 15): the signed-in user's bookings,
/// as renter and as owner, in separate tabs since the two roles show
/// different counterparty info and different actions once a booking is
/// opened.
class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.myBookingsTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.myBookingsAsRenterTab),
              Tab(text: l10n.myBookingsAsOwnerTab),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BookingList(asRenter: true),
            _BookingList(asRenter: false),
          ],
        ),
      ),
    );
  }
}

class _BookingList extends ConsumerWidget {
  const _BookingList({required this.asRenter});

  final bool asRenter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final provider = asRenter ? myBookingsAsRenterProvider : myBookingsAsOwnerProvider;
    final bookingsAsync = ref.watch(provider);

    return bookingsAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 3,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: SkeletonCard(),
        ),
      ),
      error: (error, stack) => ErrorStateView(
        failure: Failure.from(error),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (bookings) {
        if (bookings.isEmpty) {
          return EmptyState(title: l10n.myBookingsEmptyTitle, icon: Icons.event_note_outlined);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: bookings.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) => _BookingListTile(booking: bookings[index]),
        );
      },
    );
  }
}

class _BookingListTile extends StatelessWidget {
  const _BookingListTile({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final String? imageUrl = StorageUrls.assetImage(booking.assetImagePath);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => context.pushNamed(RouteNames.bookingDetail, pathParameters: {'id': booking.id}),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: theme.dividerColor),
          // Same soft lift as Home's cards/search bar (design spec: very
          // little shadow, not a heavy Material card elevation).
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
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 56,
                height: 56,
                child: imageUrl != null
                    ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                    : Container(
                        color: theme.scaffoldBackgroundColor,
                        child: const Icon(Icons.inventory_2_outlined, size: 20),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.assetTitle ?? '',
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppDateUtils.formatDateRange(booking.startDate, booking.endDate),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bookingStatusLabel(booking.status, l10n),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: bookingStatusColor(booking.status, context.colors)),
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.format(booking.totalAmount),
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
