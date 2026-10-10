import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_pages.dart';
import '../features/cases/case_details.dart';
import '../features/cases/case_form.dart';
import '../features/extras/calendar_page.dart';
import '../features/extras/causelist_page.dart';
import '../features/extras/clients_page.dart';
import '../features/extras/fees_page.dart';
import '../features/extras/reminders_page.dart';
import '../features/extras/reports_page.dart';
import '../features/home/hearings_page.dart';
import '../features/home/home_shell.dart';
import '../features/home/list_pages.dart';
import '../features/license/activation_page.dart';
import '../features/license/setup_page.dart';
import '../features/settings/backup_page.dart';
import '../features/settings/lawyers_page.dart';
import '../features/settings/printer_page.dart';
import '../features/settings/settings_page.dart';
import 'gate.dart';

const _gatePages = ['/splash', '/activate', '/setup', '/login', '/register', '/forgot', '/lock'];

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<Stage>(gateProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  CustomTransitionPage<void> fade(GoRouterState s, Widget child) => CustomTransitionPage<void>(
        key: s.pageKey,
        child: child,
        transitionsBuilder: (c, a, sa, w) => FadeTransition(opacity: a, child: w),
      );

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final st = ref.read(gateProvider);
      final loc = state.matchedLocation;
      String? want;
      switch (st) {
        case Stage.loading:
          want = '/splash';
          break;
        case Stage.activate:
          want = '/activate';
          break;
        case Stage.setup:
          want = '/setup';
          break;
        case Stage.login:
          if (!['/login', '/register', '/forgot'].contains(loc)) want = '/login';
          break;
        case Stage.locked:
          want = '/lock';
          break;
        case Stage.ready:
          if (_gatePages.contains(loc)) want = '/hearings';
          break;
      }
      return (want != null && want != loc) ? want : null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/activate', builder: (_, __) => const ActivationPage()),
      GoRoute(path: '/renew', builder: (_, __) => const ActivationPage(renew: true)),
      GoRoute(path: '/setup', builder: (_, __) => const SetupPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotPage()),
      GoRoute(path: '/lock', builder: (_, __) => const LockPage()),
      ShellRoute(
        builder: (c, s, child) => HomeShell(location: s.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/hearings', pageBuilder: (c, s) => fade(s, const HearingsPage())),
          GoRoute(path: '/cases', pageBuilder: (c, s) => fade(s, const CasesPage())),
          GoRoute(path: '/priority', pageBuilder: (c, s) => fade(s, const PriorityPage())),
          GoRoute(path: '/history', pageBuilder: (c, s) => fade(s, const HistoryPage())),
        ],
      ),
      GoRoute(path: '/case/new', builder: (_, __) => const CaseFormPage()),
      GoRoute(path: '/case/:id', builder: (_, s) => CaseDetailsPage(caseId: s.pathParameters['id']!)),
      GoRoute(path: '/case/:id/edit', builder: (_, s) => CaseFormPage(caseId: s.pathParameters['id'])),
      GoRoute(path: '/calendar', builder: (_, __) => const CalendarPage()),
      GoRoute(path: '/reminders', builder: (_, __) => const RemindersPage()),
      GoRoute(path: '/clients', builder: (_, __) => const ClientsPage()),
      GoRoute(path: '/causelist', builder: (_, __) => const CauseListPage()),
      GoRoute(path: '/fees', builder: (_, __) => const FeesPage()),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsPage()),
      GoRoute(path: '/lawyers', builder: (_, __) => const LawyersPage()),
      GoRoute(path: '/backup', builder: (_, __) => const BackupPage()),
      GoRoute(path: '/printer', builder: (_, __) => const PrinterPage()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
    ],
  );
});
