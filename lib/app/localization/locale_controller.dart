import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';

/// Tracks the user's chosen app language and persists it (spec section 38:
/// "Prepare architecture for Mongolian, English"). Defaults to Mongolian —
/// the app's primary market — regardless of device locale, rather than
/// silently falling back to English on a non-Mongolian phone; the user can
/// switch from Settings > Language at any time.
class LocaleController extends Notifier<Locale> {
  static const Locale _defaultLocale = Locale('mn');

  @override
  Locale build() {
    final String? saved = ref.watch(localCacheProvider).locale;
    if (saved == 'en') return const Locale('en');
    return _defaultLocale;
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await ref.read(localCacheProvider).setLocale(locale.languageCode);
  }
}

final NotifierProvider<LocaleController, Locale> localeControllerProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);
