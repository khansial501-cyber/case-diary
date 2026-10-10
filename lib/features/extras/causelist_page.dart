import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../core/providers.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../services/pdf_service.dart';
import '../shared/widgets.dart';

class CauseListPage extends ConsumerStatefulWidget {
  const CauseListPage({super.key});
  @override
  ConsumerState<CauseListPage> createState() => _CauseListState();
}

class _CauseListState extends ConsumerState<CauseListPage> {
  late DateTime from = today().add(const Duration(days: 1)), to = today().add(const Duration(days: 1));
  List<CaseModel> cases = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await ref.read(repoProvider).casesBetween(ymd(from), ymd(to));
    if (mounted) setState(() => cases = c);
  }

  void _preset(int fromOff, int days) {
    from = today().add(Duration(days: fromOff));
    to = from.add(Duration(days: days));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l('causeList'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, children: [
          ActionChip(label: Text(l('today')), onPressed: () => _preset(0, 0)),
          ActionChip(label: Text(l('tomorrow')), onPressed: () => _preset(1, 0)),
          ActionChip(label: Text(l('next7')), onPressed: () => _preset(0, 6)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final d = await pickDate(context, from);
                if (d != null) {
                  from = d;
                  if (to.isBefore(from)) to = from;
                  _load();
                }
              },
              child: Text('${l('from')}: ${l.date(from, weekday: false)}'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final d = await pickDate(context, to);
                if (d != null) {
                  to = d.isBefore(from) ? from : d;
                  _load();
                }
              },
              child: Text('${l('to')}: ${l.date(to, weekday: false)}'),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.picture_as_pdf),
          label: Text('${l('exportPdf')} (${cases.length})'),
          onPressed: () async {
            final bytes = await buildCauseListPdf(
                s: ref.read(settingsProvider), l: l, lb: ref.read(labelsProvider), from: ymd(from), to: ymd(to), cases: cases);
            await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'Cause list ${ymd(from)}');
          },
        ),
        const SizedBox(height: 12),
        if (cases.isEmpty) SizedBox(height: 240, child: EmptyState(icon: Icons.event_busy, text: l('noHearings'))),
        for (final c in cases) Padding(padding: const EdgeInsets.only(bottom: 10), child: CaseCard(c, swipe: false)),
      ]),
    );
  }
}
