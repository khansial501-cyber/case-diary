import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../services/messaging_service.dart';
import '../../services/notification_service.dart';
import '../../services/pdf_service.dart';
import '../../services/print_service.dart';
import '../extras/fees_page.dart';
import '../shared/widgets.dart';
import 'documents_section.dart';

List<Widget> caseActionButtons(BuildContext context, WidgetRef ref, CaseModel c) {
  final l = ref.read(l10nProvider);
  final assistant = ref.read(settingsProvider).readOnlyRole;
  return [
    OutlinedButton.icon(
      icon: const Icon(Icons.alarm_add),
      label: Text(l('setReminder')),
      onPressed: () async {
        if (!requireWritable(context, ref)) return;
        final d = await pickDateTime(context, parseYmd(c.nextHearingDate)?.subtract(const Duration(days: 1)).add(const Duration(hours: 18)));
        if (d == null) return;
        await ref.read(notificationServiceProvider).scheduleCaseReminder(
            caseId: c.id, when: d, message: '${l('reminderPrefix')}: ${c.title}');
        if (context.mounted) snack(context, l('reminderSet'));
      },
    ),
    OutlinedButton.icon(
      icon: const Icon(Icons.send),
      label: Text(l('notifyClient')),
      onPressed: (c.clientPhone ?? '').isEmpty ? () => snack(context, l('noPhone')) : () => showNotifyClientSheet(context, ref, c),
    ),
    OutlinedButton.icon(icon: const Icon(Icons.print), label: Text(l('printReceipt')), onPressed: () => printReceipt(context, ref, c)),
    OutlinedButton.icon(
      icon: const Icon(Icons.picture_as_pdf),
      label: Text(l('exportPdf')),
      onPressed: () async {
        final repo = ref.read(repoProvider);
        final bytes = await buildCaseFilePdf(
          s: ref.read(settingsProvider),
          l: l,
          lb: ref.read(labelsProvider),
          c: c,
          parties: await repo.parties(c.id),
          hearings: (await repo.hearings(c.id)).reversed.toList(),
          docs: await repo.documents(c.id),
        );
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'Case - ${c.title}');
      },
    ),
    if (!assistant)
      OutlinedButton.icon(icon: const Icon(Icons.payments_outlined), label: Text(l('fees')), onPressed: () => showCaseFeesSheet(context, ref, c)),
  ];
}

final caseRemindersProvider = FutureProvider.autoDispose.family<List<ReminderModel>, String>((ref, id) {
  ref.watch(dataVersionProvider);
  return ref.read(repoProvider).reminders(caseId: id);
});

class CaseRemindersSection extends ConsumerWidget {
  final String caseId;
  const CaseRemindersSection({super.key, required this.caseId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final list = (ref.watch(caseRemindersProvider(caseId)).valueOrNull ?? const []).where((r) => !r.isDone).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle(l('reminders')),
      for (final r in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              const Icon(Icons.alarm, color: kGold),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(fmtDateTime(r.when, l.lang), style: const TextStyle(fontWeight: FontWeight.w700)), Text(r.message, style: const TextStyle(fontSize: 13))])),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () async {
                  await ref.read(notificationServiceProvider).cancelReminder(r.notificationId);
                  await ref.read(repoProvider).deleteReminder(r.id);
                },
              ),
            ]),
          ),
        ),
    ]);
  }
}

class CaseNotesSection extends ConsumerWidget {
  final CaseModel c;
  const CaseNotesSection({super.key, required this.c});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle(l('notes'),
          trailing: IconButton(
            icon: const Icon(Icons.edit_note),
            onPressed: () async {
              if (!requireWritable(context, ref)) return;
              final ctrl = TextEditingController(text: c.notes ?? '');
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l('notes')),
                  content: TextField(controller: ctrl, minLines: 4, maxLines: 10, autofocus: true, decoration: dec(ctx, l('notes'))),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l('cancel'))),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l('save'))),
                  ],
                ),
              );
              if (ok == true) await ref.read(repoProvider).setCaseNotes(c.id, ctrl.text.trim());
            },
          )),
      AppCard(child: SizedBox(width: double.infinity, child: Text((c.notes ?? '').trim().isEmpty ? '—' : c.notes!.trim()))),
    ]);
  }
}
