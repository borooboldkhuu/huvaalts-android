import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../domain/entities/platform_settings.dart';
import '../controllers/admin_providers.dart';
import '../controllers/commission_settings_controller.dart';

/// The single platform-wide commission rate `create_booking` reads at
/// booking time (`0012_admin_dashboard.sql`), replacing the 10% every
/// earlier phase had hardcoded.
class AdminCommissionSettingsScreen extends ConsumerWidget {
  const AdminCommissionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final settingsAsync = ref.watch(platformSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminCommissionSettingsTitle)),
      body: settingsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: SkeletonCard(),
        ),
        error: (error, stack) => ErrorStateView(
          failure: Failure.from(error),
          onRetry: () => ref.invalidate(platformSettingsProvider),
        ),
        data: (settings) => _CommissionForm(settings: settings),
      ),
    );
  }
}

class _CommissionForm extends ConsumerStatefulWidget {
  const _CommissionForm({required this.settings});

  final PlatformSettings settings;

  @override
  ConsumerState<_CommissionForm> createState() => _CommissionFormState();
}

class _CommissionFormState extends ConsumerState<_CommissionForm> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.settings.commissionPercent.toString());
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double? percent = double.tryParse(_controller.text.trim());
    if (percent == null || percent < 0 || percent > 100) {
      setState(() => _errorText = l10n.adminInvalidCommissionError);
      return;
    }
    setState(() => _errorText = null);
    try {
      await ref.read(commissionSettingsControllerProvider.notifier).update(percent);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.adminCommissionUpdatedMessage)));
      }
    } catch (error) {
      if (mounted) {
        final (_, message) = failurePresentation(Failure.from(error), l10n);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isSubmitting = ref.watch(commissionSettingsControllerProvider).isSubmitting;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.adminCommissionCurrentLabel(widget.settings.commissionPercent.toString())),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _controller,
            label: l10n.adminCommissionPercentLabel,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffixText: '%',
            errorText: _errorText,
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: l10n.adminSaveAction,
            isLoading: isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
