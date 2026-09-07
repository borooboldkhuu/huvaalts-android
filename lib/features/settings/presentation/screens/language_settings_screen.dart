import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/localization/locale_controller.dart';
import '../../../../app/theme/app_spacing.dart';

/// Language selector (spec section 38: Mongolian primary, English
/// secondary; spec section 28: "Language" is one of the Profile > Settings
/// entries). Selecting a language updates the whole app immediately —
/// [LocaleController] is watched at the `MaterialApp.router` level — and
/// persists across restarts via `LocalCacheService`.
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Locale current = ref.watch(localeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsLanguage)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          _LanguageTile(
            label: l10n.languageMongolian,
            selected: current.languageCode == 'mn',
            onTap: () => ref.read(localeControllerProvider.notifier).setLocale(const Locale('mn')),
          ),
          _LanguageTile(
            label: l10n.languageEnglish,
            selected: current.languageCode == 'en',
            onTap: () => ref.read(localeControllerProvider.notifier).setLocale(const Locale('en')),
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(label, style: theme.textTheme.bodyLarge),
      trailing: selected ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
      onTap: onTap,
    );
  }
}
