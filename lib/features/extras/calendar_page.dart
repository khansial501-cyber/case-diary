import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../shared/widgets.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});
  @override
  ConsumerState<CalendarPage> createState() => _CalendarState();
}

class _CalendarState extends ConsumerState<CalendarPage> {
  DateTime focused = today(), selected = today();
  Map<String, int> dots = {};
  List<CaseModel> dayCases = [];

  @override
  void initState() {
    super.initState();
    _loadMonth();
    _loadDay();
  }

  Future<void> _loadMonth() async {
    final from = DateTime(focused.year, focused.month - 1, 20), to = DateTime(focused.year, focused.month + 1, 12);
    final m = await ref.read(repoProvider).hearingDots(ymd(from), ymd(to));
    if (mounted) setState(() => dots = m);
  }

  Future<void> _loadDay() async {
    final c = await ref.read(repoProvider).casesOnDay(ymd(selected));
    if (mounted) setState(() => dayCases = c);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(dataVersionProvider, (_, __) {
      _loadMonth();
      _loadDay();
    });
    final l = ref.watch(l10nProvider);
    final courts = dayCases.where((c) => !c.isDecided && (c.courtName ?? '').isNotEmpty).map((c) => c.courtName).toSet();
    final clash = courts.length > 1;
    return Scaffold(
      appBar: AppBar(title: Text(l('calendar'))),
      body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        TableCalendar<int>(
          locale: l.lang,
          firstDay: DateTime(2000),
          lastDay: DateTime(2100),
          focusedDay: focused,
          startingDayOfWeek: StartingDayOfWeek.monday,
          selectedDayPredicate: (d) => isSameDay(d, selected),
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: ''},
          headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(color: kGold.withOpacity(0.35), shape: BoxShape.circle),
            todayTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w800),
            selectedDecoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
          ),
          onDaySelected: (s, f) {
            setState(() {
              selected = dateOnly(s);
              focused = f;
            });
            _loadDay();
          },
          onPageChanged: (f) {
            focused = f;
            _loadMonth();
          },
          calendarBuilders: CalendarBuilders(markerBuilder: (ctx, day, _) {
            final n = dots[ymd(day)] ?? 0;
            if (n == 0) return null;
            return Positioned(
              bottom: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: n > 3 ? Colors.redAccent : kGold, borderRadius: BorderRadius.circular(8)),
                child: Text('$n', style: const TextStyle(fontSize: 9.5, color: Colors.black, fontWeight: FontWeight.w800)),
              ),
            );
          }),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Expanded(child: Text(l.date(selected), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            TextButton(
              onPressed: () {
                ref.read(selectedDateProvider.notifier).state = selected;
                context.go('/hearings');
              },
              child: Text(l('openInHearings')),
            ),
          ]),
        ),
        if (clash)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: AppCard(
              color: Colors.orange.withOpacity(0.15),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(child: Text(l.f('clashWarning', {'n': '${courts.length}'}))),
              ]),
            ),
          ),
        if (dayCases.isEmpty)
          Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(l('noHearings'))))
        else
          for (final c in dayCases) Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 6), child: CaseCard(c, swipe: false)),
      ]),
    );
  }
}
