import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'services/app_guard.dart';

class CaseDiaryApp extends ConsumerWidget {
  const CaseDiaryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Case Diary',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: buildTheme(Brightness.light, s.lang),
      darkTheme: buildTheme(Brightness.dark, s.lang),
      themeMode: s.themeMode,
      locale: Locale(s.lang),
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => AppGuard(child: child ?? const SizedBox.shrink()),
    );
  }
}
