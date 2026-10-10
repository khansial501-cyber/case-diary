import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../license/license_state.dart';
import '../shared/widgets.dart';

class HomeShell extends ConsumerWidget {
  final Widget child;
  final String location;
  const HomeShell({super.key, required this.child, required this.location});

  static const _tabs = ['/hearings', '/cases', '/priority', '/history'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final s = ref.watch(settingsProvider);
    final lic = ref.watch(licenseProvider);
    final idx = _tabs.indexWhere((t) => location.startsWith(t));
    final firm = s.firmName.isEmpty ? kAppName : s.firmName;
    final logo = s.logoPath.isNotEmpty && File(s.logoPath).existsSync() ? File(s.logoPath) : null;

    Widget navItem(int i, IconData icon, IconData iconOn, String label) {
      final sel = idx == i;
      final color = sel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.55);
      return Expanded(
        child: InkWell(
          onTap: () => context.go(_tabs[i]),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(sel ? iconOn : icon, color: color),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11.5, color: color, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          if (logo != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: CircleAvatar(radius: 16, backgroundImage: FileImage(logo)),
            ),
          Expanded(child: Text(firm, overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          const LawyerFilterButton(),
          IconButton(icon: const Icon(Icons.calendar_month), tooltip: l('calendar'), onPressed: () => context.push('/calendar')),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(children: [
        if (lic.expired)
          Material(
            color: Colors.red.shade700,
            child: InkWell(
              onTap: () => context.push('/renew'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.lock_clock, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l('licenceExpiredBanner'), style: const TextStyle(color: Colors.white, fontSize: 13))),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ]),
              ),
            ),
          ),
        Expanded(child: child),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (requireWritable(context, ref)) context.push('/case/new');
        },
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        padding: EdgeInsets.zero,
        height: 64,
        shape: const CircularNotchedRectangle(),
        notchMargin: 7,
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111C2B) : Colors.white,
        child: Row(children: [
          navItem(0, Icons.gavel_outlined, Icons.gavel, l('hearings')),
          navItem(1, Icons.folder_open_outlined, Icons.folder_open, l('cases')),
          const SizedBox(width: 64),
          navItem(2, Icons.star_border_rounded, Icons.star_rounded, l('priority')),
          navItem(3, Icons.history, Icons.history_toggle_off, l('history')),
        ]),
      ),
    );
  }
}

class LawyerFilterButton extends ConsumerWidget {
  const LawyerFilterButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lawyers = ref.watch(lawyersProvider).valueOrNull ?? const [];
    if (lawyers.length < 2) return const SizedBox.shrink();
    final l = ref.watch(l10nProvider);
    final sel = ref.watch(lawyerFilterProvider);
    return PopupMenuButton<String>(
      icon: Icon(Icons.person_search, color: sel.isEmpty ? null : kGold),
      tooltip: l('filterByLawyer'),
      onSelected: (v) => ref.read(lawyerFilterProvider.notifier).state = v,
      itemBuilder: (_) => [
        PopupMenuItem(value: '', child: Text(l('allLawyers'))),
        ...lawyers.map((x) => PopupMenuItem(value: x.id, child: Text(x.name))),
      ],
    );
  }
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final s = ref.watch(settingsProvider);
    final assistant = s.readOnlyRole;
    Widget item(IconData i, String t, String route) => ListTile(
          leading: Icon(i),
          title: Text(t),
          onTap: () {
            Navigator.pop(context);
            context.push(route);
          },
        );
    return Drawer(
      child: SafeArea(
        child: ListView(children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: kNavy),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
              const Icon(Icons.balance, color: kGold, size: 38),
              const SizedBox(height: 10),
              Text(s.firmName.isEmpty ? kAppName : s.firmName,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              if (s.lawyerName.isNotEmpty) Text(s.lawyerName, style: const TextStyle(color: Colors.white70)),
            ]),
          ),
          item(Icons.calendar_month, l('calendar'), '/calendar'),
          item(Icons.alarm, l('reminders'), '/reminders'),
          item(Icons.people_alt_outlined, l('clients'), '/clients'),
          item(Icons.picture_as_pdf_outlined, l('causeList'), '/causelist'),
          if (!assistant) item(Icons.payments_outlined, l('fees'), '/fees'),
          item(Icons.bar_chart, l('reports'), '/reports'),
          const Divider(),
          item(Icons.badge_outlined, l('lawyers'), '/lawyers'),
          item(Icons.backup_outlined, l('backupRestore'), '/backup'),
          item(Icons.print_outlined, l('printerSettings'), '/printer'),
          item(Icons.settings_outlined, l('settings'), '/settings'),
        ]),
      ),
    );
  }
}
