import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../shared/widgets.dart';

final feeLedgerProvider = FutureProvider.autoDispose<List<Map<String, Object?>>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.read(repoProvider).feeLedger();
});

class FeesPage extends ConsumerWidget {
  const FeesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    if (ref.watch(settingsProvider).readOnlyRole) {
      return Scaffold(appBar: AppBar(title: Text(l('fees'))), body: EmptyState(icon: Icons.lock_outline, text: l('ownerOnly')));
    }
    final rows = ref.watch(feeLedgerProvider).valueOrNull ?? const [];
    num agreed = 0, paid = 0;
    for (final r in rows) {
      agreed += (r['agreed'] as num?) ?? 0;
      paid += (r['paid'] as num?) ?? 0;
    }
    Widget stat(String k, num v, Color c) => Expanded(
          child: AppCard(
            child: Column(children: [
              Text(k, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              FittedBox(child: Text(money(v), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c))),
            ]),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l('fees'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [stat(l('agreed'), agreed, kGold), const SizedBox(width: 8), stat(l('collected'), paid, Colors.green), const SizedBox(width: 8), stat(l('pending'), agreed - paid, Colors.redAccent)]),
        const SizedBox(height: 12),
        if (rows.isEmpty) SizedBox(height: 300, child: EmptyState(icon: Icons.payments_outlined, text: l('noFees'))),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () => context.push('/case/${r['id']}'),
              child: Row(children: [
                Expanded(child: Text('${r['title']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${l('agreed')}: ${money((r['agreed'] as num?) ?? 0)}', style: const TextStyle(fontSize: 12)),
                  Text('${l('collected')}: ${money((r['paid'] as num?) ?? 0)}', style: const TextStyle(fontSize: 12, color: Colors.green)),
                  Text('${l('pending')}: ${money(((r['agreed'] as num?) ?? 0) - ((r['paid'] as num?) ?? 0))}', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                ]),
              ]),
            ),
          ),
      ]),
    );
  }
}

Future<void> showCaseFeesSheet(BuildContext context, WidgetRef ref, CaseModel c) async {
  final l = ref.read(l10nProvider);
  final repo = ref.read(repoProvider);
  final fee = TextEditingController();
  final agreed = await repo.agreedFee(c.id);
  fee.text = agreed == 0 ? '' : agreed.round().toString();
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Consumer(builder: (ctx, ref, _) {
      ref.watch(dataVersionProvider);
      return FutureBuilder<List<PaymentModel>>(
        future: repo.payments(c.id),
        builder: (ctx, snap) {
          final pays = snap.data ?? const [];
          final total = pays.fold<double>(0, (a, b) => a + b.amount);
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(l('fees'), style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text(c.title),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: fee, keyboardType: TextInputType.number, decoration: dec(ctx, l('agreedFee')))),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      if (!requireWritable(ctx, ref)) return;
                      await repo.setAgreedFee(c.id, double.tryParse(fee.text.trim()) ?? 0);
                      if (ctx.mounted) snack(ctx, l('saved'));
                    },
                    child: Text(l('save')),
                  ),
                ]),
                const SizedBox(height: 10),
                Text('${l('collected')}: ${money(total)}   |   ${l('pending')}: ${money((double.tryParse(fee.text.trim()) ?? 0) - total)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const Divider(height: 24),
                Row(children: [
                  Expanded(child: Text(l('payments'), style: const TextStyle(fontWeight: FontWeight.w700))),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l('addPayment')),
                    onPressed: () async {
                      if (!requireWritable(ctx, ref)) return;
                      final amt = TextEditingController(), note = TextEditingController();
                      DateTime d = today();
                      final ok = await showDialog<bool>(
                        context: ctx,
                        builder: (dc) => StatefulBuilder(
                          builder: (dc, setM) => AlertDialog(
                            title: Text(l('addPayment')),
                            content: Column(mainAxisSize: MainAxisSize.min, children: [
                              TextField(controller: amt, autofocus: true, keyboardType: TextInputType.number, decoration: dec(dc, l('amount'))),
                              const SizedBox(height: 10),
                              InkWell(
                                onTap: () async {
                                  final x = await pickDate(dc, d);
                                  if (x != null) setM(() => d = x);
                                },
                                child: InputDecorator(decoration: dec(dc, l('date'), suffix: const Icon(Icons.event)), child: Text(l.date(d))),
                              ),
                              const SizedBox(height: 10),
                              TextField(controller: note, decoration: dec(dc, l('note'))),
                            ]),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dc, false), child: Text(l('cancel'))),
                              FilledButton(onPressed: () => Navigator.pop(dc, true), child: Text(l('save'))),
                            ],
                          ),
                        ),
                      );
                      final v = double.tryParse(amt.text.trim());
                      if (ok == true && v != null && v > 0) await repo.addPayment(c.id, v, ymd(d), note.text);
                    },
                  ),
                ]),
                for (final p in pays)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(money(p.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${l.ymdDate(p.date)}${p.note.isEmpty ? '' : '  -  ${p.note}'}'),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
                      if (await confirm(ctx, l('deleteConfirm'))) await repo.deletePayment(p.id);
                    }),
                  ),
              ]),
            ),
          );
        },
      );
    }),
  );
}
