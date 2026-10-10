import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../shared/widgets.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  Widget _bars(BuildContext context, List<Map<String, Object?>> rows, {bool isMoney = false}) {
    if (rows.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text('—'));
    final maxV = rows.map((e) => (e['n'] as num?) ?? 0).fold<num>(1, (a, b) => b > a ? b : a);
    return Column(children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(children: [
            Row(children: [
              Expanded(child: Text('${r['k']}', overflow: TextOverflow.ellipsis)),
              Text(isMoney ? money((r['n'] as num?) ?? 0) : '${r['n']}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: (((r['n'] as num?) ?? 0) / maxV).toDouble().clamp(0.02, 1.0), minHeight: 8, color: kGold, backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
            ),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    ref.watch(dataVersionProvider);
    final repo = ref.read(repoProvider);
    final assistant = ref.watch(settingsProvider).readOnlyRole;
    Widget section(String title, Future<List<Map<String, Object?>>> f, {bool isMoney = false}) => FutureBuilder<List<Map<String, Object?>>>(
          future: f,
          builder: (ctx, snap) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionTitle(title),
            AppCard(child: _bars(ctx, snap.data ?? const [], isMoney: isMoney)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l('reports'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        section(l('casesByCourt'), repo.reportByCourt()),
        section(l('casesFiledByMonth'), repo.reportByMonth()),
        section(l('outcomes'), repo.reportByOutcome()),
        if (!assistant) section(l('feesByMonth'), repo.reportFeesByMonth(), isMoney: true),
      ]),
    );
  }
}
