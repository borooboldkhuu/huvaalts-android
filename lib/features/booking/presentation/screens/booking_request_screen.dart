import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_range_utils.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../assets/domain/entities/asset_detail.dart';
import '../../../assets/presentation/controllers/asset_providers.dart';
import '../../domain/entities/price_breakdown.dart';
import '../controllers/booking_providers.dart';
import '../controllers/booking_request_controller.dart';

/// The booking request flow (spec sections 17, 18): pick a date range,
/// see a price estimate, submit. Reachable from asset detail's
/// "Захиалах" button. Daily-priced assets only this phase — see
/// `create_booking`'s doc comment in
/// `supabase/migrations/0006_booking_rpc.sql` for why hourly/weekly
/// booking math isn't wired up yet.
class BookingRequestScreen extends ConsumerStatefulWidget {
  const BookingRequestScreen({required this.assetId, super.key});

  final String assetId;

  @override
  ConsumerState<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends ConsumerState<BookingRequestScreen> {
  DateTimeRange? _selectedRange;
  String? _dateError;

  Future<void> _pickDateRange(List<(DateTime, DateTime)> blocked) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: _selectedRange,
    );
    if (picked == null) return;

    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool overlaps = DateRangeUtils.overlapsAny(picked.start, picked.end, blocked);
    setState(() {
      _selectedRange = picked;
      _dateError = overlaps ? l10n.bookingDatesUnavailable : null;
    });
  }

  Future<void> _submit(AssetDetail detail) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTimeRange? range = _selectedRange;
    if (range == null || _dateError != null) return;

    try {
      final booking = await ref.read(bookingRequestControllerProvider.notifier).submit(
            assetId: widget.assetId,
            startDate: range.start,
            endDate: range.end,
          );
      if (!mounted) return;
      context.pushReplacementNamed(RouteNames.bookingDetail, pathParameters: {'id': booking.id});
    } catch (e) {
      if (!mounted) return;
      final Failure failure = Failure.from(e);
      // A conflict here means someone else's booking (or a fresh owner
      // blackout) landed on these dates between the client-side check and
      // submit — refresh the blocked ranges so the calendar reflects
      // reality instead of leaving a submit button the user would just
      // hit into the same wall again.
      if (failure is ConflictFailure) {
        ref.invalidate(assetBlockedRangesProvider(widget.assetId));
        setState(() {
          _dateError = l10n.bookingDatesUnavailable;
        });
        return;
      }
      final (_, message) = failurePresentation(failure, l10n);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final detailAsync = ref.watch(assetDetailByIdProvider(widget.assetId));
    final blockedAsync = ref.watch(assetBlockedRangesProvider(widget.assetId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookingRequestTitle)),
      body: detailAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: SkeletonCard(),
        ),
        error: (error, stack) => ErrorStateView(
          failure: Failure.from(error),
          onRetry: () => ref.invalidate(assetDetailByIdProvider(widget.assetId)),
        ),
        data: (detail) {
          if (detail == null) {
            return EmptyState(title: l10n.errorNotFound, icon: Icons.search_off);
          }
          if (detail.pricePerDay == null) {
            return EmptyState(
              title: l10n.bookingNotBookableTitle,
              subtitle: l10n.bookingNotBookableBody,
              icon: Icons.event_busy_outlined,
            );
          }
          return _BookingForm(
            detail: detail,
            selectedRange: _selectedRange,
            dateError: _dateError,
            blockedAsync: blockedAsync,
            onPickDates: (blocked) => _pickDateRange(blocked),
            onSubmit: () => _submit(detail),
          );
        },
      ),
    );
  }
}

class _BookingForm extends ConsumerWidget {
  const _BookingForm({
    required this.detail,
    required this.selectedRange,
    required this.dateError,
    required this.blockedAsync,
    required this.onPickDates,
    required this.onSubmit,
  });

  final AssetDetail detail;
  final DateTimeRange? selectedRange;
  final String? dateError;
  final AsyncValue<List<(DateTime, DateTime)>> blockedAsync;
  final void Function(List<(DateTime, DateTime)> blocked) onPickDates;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final List<(DateTime, DateTime)> blocked = blockedAsync.value ?? const [];
    final bool isSubmitting = ref.watch(bookingRequestControllerProvider).isSubmitting;

    final PriceBreakdown? breakdown = selectedRange != null
        ? PriceBreakdown.estimate(
            pricePerDay: detail.pricePerDay!,
            startDate: selectedRange!.start,
            endDate: selectedRange!.end,
            commissionPercent: AppConstants.defaultCommissionPercent,
          )
        : null;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(detail.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          CurrencyFormatter.formatPerUnit(detail.pricePerDay!, l10n.unitDay),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(l10n.bookingSelectDates, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(
            selectedRange != null
                ? AppDateUtils.formatDateRange(selectedRange!.start, selectedRange!.end)
                : l10n.bookingPickDates,
          ),
          onPressed: () => onPickDates(blocked),
        ),
        if (dateError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              dateError!,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        if (breakdown != null && dateError == null) ...[
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
                  label: l10n.bookingRentalAmountLabel(breakdown.nights),
                  value: CurrencyFormatter.format(breakdown.rentalAmount),
                ),
                _BreakdownRow(
                  label: l10n.bookingPlatformFeeLabel,
                  value: CurrencyFormatter.format(breakdown.platformFee),
                ),
                const Divider(height: AppSpacing.xl),
                _BreakdownRow(
                  label: l10n.bookingTotalLabel,
                  value: CurrencyFormatter.format(breakdown.totalAmount),
                  emphasized: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.bookingEstimateDisclaimer, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: AppSpacing.xxxl),
        PrimaryButton(
          label: l10n.bookingSubmit,
          isLoading: isSubmitting,
          onPressed: (selectedRange != null && dateError == null) ? onSubmit : null,
        ),
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
