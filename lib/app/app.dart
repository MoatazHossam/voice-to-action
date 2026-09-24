import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'app_routes.dart';
import 'app_theme.dart';
import 'app_translations.dart';

/// Root widget. Arabic RTL is the default locale from first launch, as
/// required for this POC — the app is not English-first with Arabic bolted
/// on later.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'AI Intake POC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      translations: AppTranslations(),
      locale: const Locale('ar', 'AE'),
      fallbackLocale: const Locale('en', 'US'),
      supportedLocales: const [Locale('ar', 'AE'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: AppRoutes.home,
      getPages: AppRoutes.pages,
    );
  }
}
