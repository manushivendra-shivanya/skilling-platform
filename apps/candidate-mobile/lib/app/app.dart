import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import 'localization/app_locale.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class SkillingApp extends ConsumerWidget {
  const SkillingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      title: 'Saksham',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Watches appLocaleProvider (not a one-time read): switching language
      // from Home's picker rebuilds the whole app under the new Locale
      // immediately, the same run, no restart.
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
