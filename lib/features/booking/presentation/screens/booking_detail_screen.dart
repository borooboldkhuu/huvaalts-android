import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/storage_urls.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../payments/presentation/widgets/payment_section.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/booking_status.dart';
import '../controllers/booking_providers.dart';
import '../widgets/booking_status_label.dart';
import '../widgets/rental_lifecycle_section.dart';

/// Booking detail (spec sections 17, 18): status, dates, price breakdown
/// (the *authoritative* stored amounts from `public.bookings` — not the
/// pre-submit estimate `BookingRequestScreen` shows), the asset and
/// counterparty, and role-appropriate actions. Every action here is a
/// thin wrapper around one of the RPCs in
/// `supabase/migrations/0006_booking_rpc.sql` — this screen never writes
/// to `bookings` directly.
class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bookingAsync = ref.watch(bookingByIdProvider(bookingId));
    final String? currentUserId = ref.watch(supabaseClientProvider).auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookingDetailTitle)),
      body: bookingAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: SkeletonCard(),
        ),
        error: (error, stack) => ErrorStateView(
          failure: Failure.from(error),
          onRetry: () => ref.invalidate(bookingByIdProvider(bookingId)),
        ),
        data: (booking) {
          if (booking == null || currentUserId == null) {
            return EmptyState(title: l10n.errorNotFound, icon: Icons.search_off);
          }
          return _BookingDetailContent(booking: booking, currentUserId: currentUserId);
        },
      ),
    );
  }
}

class _BookingDetailContent extends ConsumerStatefulWidget {
  const _BookingDetailContent({required this.booking, required this.currentUserId});

  final Booking booking;
  final String currentUserId;

  @override
  ConsumerState<_BookingDetailContent> createState() => _BookingDetailContentState();
}

class _BookingDetailContentState extends ConsumerState<_BookingDetailContent> {
  bool _isProcessing = false;

  Future<String?> _promptForReason({required String title, required String hint}) {
    final TextEditingController controller = TextEditingController();
    final AppLocalizations l10n = AppLocalizations.of(context);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.commonContinue),
          ),
        ],
      ),
    );
  }

  Future<void> _runAction(Future<Booking> Function() action, String successMessage) async {
    setState(() => _isProcessing = true);
    final AppLocalizations l10n = AppLocalizations.of(context);
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(bookingByIdProvider(widget.booking.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      final (_, message) = failurePresentation(Failure.from(e), l10n);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirm() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.bookingConfirmDialogTitle),
        content: Text(l10n.bookingConfirmDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.bookingConfirmAction),
          ),
        ],
      ),
    );
    if (proceed != true) return;
    await _runAction(
      () => ref.read(bookingRepositoryProvider).confirmBooking(widget.booking.id),
      l10n.bookingConfirmedMessage,
    );
  }

  Future<void> _reject() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? reason = await _promptForReason(
      title: l10n.bookingRejectReasonPromptTitle,
      hint: l10n.bookingCancelReasonHint,
    );
    if (reason == null) return;
    await _runAction(
      () => ref
          .read(bookingRepositoryProvider)
          .rejectBooking(widget.booking.id, reason: reason.isEmpty ? null : reason),
      l10n.bookingRejectedMessage,
    );
  }

  Future<void> _cancel() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? reason = await _promptForReason(
      title: l10n.bookingCancelReasonPromptTitle,
      hint: l10n.bookingCancelReasonHint,
    );
    if (reason == null) return;
    await _runAction(
      () => ref
          .read(bookingRepositoryProvider)
          .cancelBooking(widget.booking.id, reason: reason.isEmpty ? null : reason),
      l10n.bookingCancelledMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final Booking booking = widget.booking;
    final bool isOwner = booking.isOwner(widget.currentUserId);
    final bool isRenter = booking.isRenter(widget.currentUserId);
    final String? imageUrl = StorageUrls.assetImage(booking.assetImagePath);

    final bool canConfirmOrReject = isOwner && booking.status == BookingStatus.pending;
    final bool canCancel =
        (isOwner || isRenter) && (booking.status == BookingStatus.pending || booking.status == BookingStatus.confirmed);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 64,
                height: 64,
                child: imageUrl != null
                    ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                    : Container(
                        color: theme.colorScheme.surface,
                        child: const Icon(Icons.inventory_2_outlined),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                booking.assetTitle ?? '',
                style: theme.textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          decoration: BoxDecoration(
            color: bookingStatusColor(booking.status, context.colors).withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bookingStatusColor(booking.status, context.colors),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                bookingStatusLabel(booking.status, l10n),
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: bookingStatusColor(booking.status, context.colors)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(l10n.bookingDetailDatesLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          AppDateUtils.formatDateRange(booking.startDate, booking.endDate),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          isOwner ? l10n.bookingDetailWithRenterLabel : l10n.bookingDetailWithOwnerLabel,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          (isOwner ? booking.renterDisplayName : booking.ownerDisplayName) ?? '',
          style: theme.textTheme.bodyMedium,
        ),
        if (booking.cancellationReason != null && booking.cancellationReason!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.bookingDetailCancellationReasonLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(booking.cancellationReason!, style: theme.textTheme.bodyMedium),
        ],
        if (isOwner || isRenter) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => context.pushNamed(
              RouteNames.bookingChat,
              pathParameters: {'id': booking.id},
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: Text(l10n.bookingMessageAction),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        Text(l10n.bookingPriceBreakdown, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              _BreakdownRow(
                label: l10n.bookingRentalAmountLabel(booking.nights),
                value: CurrencyFormatter.format(booking.rentalAmount),
              ),
              _BreakdownRow(
                label: l10n.bookingPlatformFeeLabel,
                value: CurrencyFormatter.format(booking.platformFee),
              ),
              const Divider(height: AppSpacing.xl),
              _BreakdownRow(
                label: l10n.bookingTotalLabel,
                value: CurrencyFormatter.format(booking.totalAmount),
                emphasized: true,
              ),
            ],
          ),
        ),
        PaymentSection(booking: booking, isRenter: isRenter),
        RentalLifecycleSection(booking: booking, currentUserId: widget.currentUserId),
        if (canConfirmOrReject || canCancel) ...[
          const SizedBox(height: AppSpacing.xxxl),
          if (canConfirmOrReject) ...[
            PrimaryButton(
              label: l10n.bookingConfirmAction,
              isLoading: _isProcessing,
              onPressed: _confirm,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: _isProcessing ? null : _reject,
              child: Text(l10n.bookingRejectAction),
            ),
          ],
          if (canCancel) ...[
            if (canConfirmOrReject) const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: _isProcessing ? null : _cancel,
              child: Text(l10n.bookingCancelAction),
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.label, required this.value, this.emphasized = false});

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final TextStyle? style = emphasized
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
