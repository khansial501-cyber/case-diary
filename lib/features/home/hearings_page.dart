import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../shared/widgets.dart';

class HearingsPage extends ConsumerWidget {
  const HearingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final sel = ref.watch(selectedDateProvider);
    final cases = ref.watch(dayCasesProvider);
    final counts = ref.watch(countsProvider).valueOrNull ?? const {'ONGOING': 0, 'DECIDED': 0};
    final overdue = ref.watch(overdueProvider).valueOrNull ?? const [];
    final todayD = today();
    final tomorrow = todayD.add(const Duration(days: 1));
    final cTodayN = ref.watch(dayCountProvider(ymd(todayD))).valueOrNull ?? 0;
    final cTomN = ref.watch(dayCountProvider(ymd(tomorrow))).valueOrNull ?? 0;
    final isToday = ymd(sel) == ymd(todayD);
    final isTomorrow = ymd(sel) == ymd(tomorrow);

    void setDate(DateTime d) {
      HapticFeedback.selectionClick();
      ref.read(selectedDateProvider.notifier).state = dateOnly(d);
    }

    return Column(children: [
      // ---- date bar ----
      Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setDate(sel.subtract(const Duration(days: 1)))),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final d = await pickDate(context, sel);
                if (d != null) setDate(d);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(children: [
                  Text(isToday ? l('today') : (isTomorrow ? l('tomorrow') : ''),
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Flexible(
                      child: Text(l.date(sel),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_drop_down),
                  ]),
                ]),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setDate(sel.add(const Duration(days: 1)))),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          CountChip(l('today'), cTodayN, selected: isToday, onTap: () => setDate(todayD)),
          CountChip(l('tomorrow'), cTomN, highlight: cTomN > 0, selected: isTomorrow, onTap: () => setDate(tomorrow)),
          CountChip(l('ongoing'), counts['ONGOING'] ?? 0),
          CountChip(l('decided'), counts['DECIDED'] ?? 0),
        ]),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: cases.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              if (overdue.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    color: Colors.orange.withOpacity(0.15),
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => DraggableScrollableSheet(
                        expand: false,
                        initialChildSize: 0.7,
                        builder: (ctx, sc) => ListView(controller: sc, padding: const EdgeInsets.all(16), children: [
                          Text(l('dateNotUpdated'), style: Theme.of(ctx).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          ...overdue.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: CaseCard(c, swipe: false))),
                        ]),
                      ),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${l('dateNotUpdated')}: ${overdue.length}', style: const TextStyle(fontWeight: FontWeight.w600))),
                      const Icon(Icons.chevron_right),
                    ]),
                  ),
                ),
              if (list.isEmpty)
                SizedBox(height: 320, child: EmptyState(icon: Icons.event_available, text: l('noHearings')))
              else
                ...list.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: CaseCard(c, showDate: true))),
            ],
          ),
        ),
      ),
    ]);
  }
}
