import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../services/notification_service.dart';
import '../shared/voice_button.dart';
import '../shared/widgets.dart';
import 'case_actions.dart';
import 'documents_section.dart';

final partiesProvider = FutureProvider.autoDispose.family<List<PartyEntry>, String>((ref, id) {
  ref.watch(dataVersionProvider);
  return ref.read(repoProvider).parties(id);
});

class CaseDetailsPage extends ConsumerWidget {
  final String caseId;
  const CaseDetailsPage({super.key, required this.caseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final lb = ref.watch(labelsProvider);
    final async = ref.watch(caseProvider(caseId));
    return async.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
      data: (c) {
        if (c == null) return Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.search_off, text: l('notFound')));
        final hearings = ref.watch(hearingsProvider(caseId)).valueOrNull ?? const [];
        final parties = ref.watch(partiesProvider(caseId)).valueOrNull ?? const [];
        final cs = Theme.of(context).colorScheme;
        final muted = cs.onSurface.withOpacity(0.6);

        Widget info(String label, String? value, {VoidCallback? onTap, IconData? icon}) {
          if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
          return InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 118, child: Text(label, style: TextStyle(color: muted, fontSize: 13))),
                Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
                if (icon != null) Icon(icon, size: 18, color: cs.primary),
              ]),
            ),
          );
        }

        String partyLine(String name, bool etc, String role) => '$name${etc ? ' etc' : ''} (${lb.role(role)})';

        return Scaffold(
          appBar: AppBar(
            title: Text(l('caseDetails')),
            actions: [
              IconButton(
                icon: Icon(c.isPriority ? Icons.star_rounded : Icons.star_border_rounded, color: c.isPriority ? kGold : null),
                onPressed: () {
                  if (requireWritable(context, ref)) ref.read(repoProvider).setPriority(c.id, !c.isPriority);
                },
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    if (requireWritable(context, ref)) context.push('/case/${c.id}/edit');
                  } else if (v == 'delete') {
                    if (!requireWritable(context, ref)) return;
                    if (await confirm(context, l('deleteCaseConfirm'))) {
                      await ref.read(notificationServiceProvider).cancelCaseReminders(c.id);
                      await ref.read(repoProvider).deleteCase(c.id);
                      if (context.mounted) context.pop();
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(l('edit'))),
                  PopupMenuItem(value: 'delete', child: Text(l('delete'))),
                ],
              ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
            // ---- header ----
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  Chip(
                    avatar: Icon(c.isDecided ? Icons.check_circle : Icons.timelapse, size: 18, color: c.isDecided ? kGold : cs.primary),
                    label: Text(c.isDecided ? l('decided') : l('ongoing')),
                  ),
                  Chip(label: Text(lb.cat(c.caseCategory))),
                  if (c.isPriority) Chip(avatar: const Icon(Icons.star_rounded, color: kGold, size: 18), label: Text(l('priority'))),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            // ---- info ----
            AppCard(
              child: Column(children: [
                info(l('firstParty'), partyLine(c.sideAName, c.sideAEtc, c.sideARole)),
                info(l('secondParty'), partyLine(c.sideBName, c.sideBEtc, c.sideBRole)),
                for (final p in parties) info(p.side == 'A' ? l('firstParty') : l('secondParty'), '${p.name} (${lb.role(p.role)})'),
                info(l('youRepresent'), lb.role(c.representedRole)),
                const Divider(),
                info(l('natureOfCase'), c.natureOfCase),
                info(l('court'), c.courtName),
                info(l('caseNumber'), c.fullCaseNo),
                info(l('judge'), c.judgeName),
                info(l('client'), c.clientName == null ? null : '${c.clientName}${(c.clientPhone ?? '').isEmpty ? '' : '\n${c.clientPhone}'}',
                    icon: (c.clientPhone ?? '').isEmpty ? null : Icons.call, onTap: (c.clientPhone ?? '').isEmpty ? null : () => showClientSheet(context, ref, c)),
                info(l('assignedLawyer'), c.lawyerName),
                info(l('currentDate'), c.filedDate == null ? null : l.ymdDate(c.filedDate)),
                if (!c.isDecided) info(l('nextHearing'), c.nextHearingDate == null ? null : l.ymdDate(c.nextHearingDate, weekday: true)),
                if (c.isDecided) info(l('decidedOn'), l.ymdDate(c.decidedDate)),
                if (c.isDecided) info(l('outcome'), c.outcomeNote),
                info(l('latestProceedings'), c.nextProceedings),
              ]),
            ),
            const SizedBox(height: 14),
            // ---- primary action ----
            if (!c.isDecided)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                icon: const Icon(Icons.edit_calendar),
                label: Text(l('setNextDate')),
                onPressed: () {
                  if (requireWritable(context, ref)) showSetNextDate(context, ref, c);
                },
              ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (!c.isDecided)
                OutlinedButton.icon(
                    icon: const Icon(Icons.gavel),
                    label: Text(l('markDecided')),
                    onPressed: () => markDecidedDialog(context, ref, c))
              else
                OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt),
                    label: Text(l('reopen')),
                    onPressed: () async {
                      if (requireWritable(context, ref)) await ref.read(repoProvider).reopen(c.id);
                    }),
              ...caseActionButtons(context, ref, c),
            ]),
            // ---- timeline ----
            SectionTitle(l('hearingHistory')),
            if (hearings.isEmpty)
              Padding(padding: const EdgeInsets.all(12), child: Text(l('noHistoryYet'), style: TextStyle(color: muted)))
            else
              ...hearings.asMap().entries.map((e) => _TimelineTile(h: e.value, last: e.key == hearings.length - 1)),
            // ---- documents + reminders + notes ----
            DocumentsSection(caseId: c.id),
            CaseRemindersSection(caseId: c.id),
            CaseNotesSection(c: c),
          ]),
        );
      },
    );
  }
}

class _TimelineTile extends ConsumerWidget {
  final HearingModel h;
  final bool last;
  const _TimelineTile({required this.h, required this.last});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final cs = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 26,
          child: Column(children: [
            const SizedBox(height: 6),
            Container(width: 12, height: 12, decoration: const BoxDecoration(color: kGold, shape: BoxShape.circle)),
            if (!last) Expanded(child: Container(width: 2, color: cs.onSurface.withOpacity(0.15))),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.ymdDate(h.hearingDate, weekday: true), style: const TextStyle(fontWeight: FontWeight.w700)),
                if ((h.judgeName ?? '').isNotEmpty)
                  Text('${l('judge')}: ${h.judgeName}', style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12.5)),
                if ((h.proceedings ?? '').trim().isNotEmpty) ...[const SizedBox(height: 6), Text(h.proceedings!.trim())],
                if ((h.nextDateSet ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.arrow_forward, size: 14, color: cs.primary),
                    const SizedBox(width: 4),
                    Text('${l('nextDate')}: ${l.ymdDate(h.nextDateSet)}', style: TextStyle(color: cs.primary, fontSize: 13)),
                  ]),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Set next date
// ---------------------------------------------------------------------------
Future<void> showSetNextDate(BuildContext context, WidgetRef ref, CaseModel c) async {
  final l = ref.read(l10nProvider);
  final repo = ref.read(repoProvider);
  final judges = await repo.judgeNames();
  final judge = TextEditingController(text: c.judgeName ?? '');
  final done = TextEditingController();
  final planned = TextEditingController();
  DateTime held = parseYmd(c.nextHearingDate) ?? today();
  DateTime? newDate;
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setM) {
      Widget dateBox(String label, DateTime? v, ValueChanged<DateTime> on) => InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final d = await pickDate(ctx, v ?? today());
              if (d != null) setM(() => on(d));
            },
            child: InputDecorator(
              decoration: dec(ctx, label, suffix: const Icon(Icons.event)),
              child: Text(v == null ? '—' : l.date(v)),
            ),
          );
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l('setNextDate'), style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(c.title, style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6))),
            const SizedBox(height: 14),
            dateBox(l('hearingHeldOn'), held, (d) => held = d),
            const SizedBox(height: 12),
            AutoField(controller: judge, label: l('judge'), suggestions: judges),
            const SizedBox(height: 12),
            TextField(
                controller: done,
                minLines: 2,
                maxLines: 5,
                decoration: dec(ctx, l('proceedingsToday'), suffix: VoiceButton(controller: done))),
            const SizedBox(height: 12),
            dateBox(l('newNextDate'), newDate, (d) => newDate = d),
            const SizedBox(height: 12),
            TextField(
                controller: planned,
                minLines: 2,
                maxLines: 5,
                decoration: dec(ctx, l('proceedingsNext'), suffix: VoiceButton(controller: planned))),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              icon: const Icon(Icons.check),
              label: Text(l('save')),
              onPressed: () async {
                if (newDate == null) {
                  snack(ctx, l('pickNewDate'));
                  return;
                }
                await repo.setNextDate(
                  caseId: c.id,
                  hearingDate: ymd(held),
                  judgeName: judge.text,
                  proceedingsDone: done.text,
                  newDate: ymd(newDate!),
                  proceedingsNext: planned.text,
                );
                HapticFeedback.mediumImpact();
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ]),
        ),
      );
    }),
  );
}

Future<void> markDecidedDialog(BuildContext context, WidgetRef ref, CaseModel c) async {
  if (!requireWritable(context, ref)) return;
  final l = ref.read(l10nProvider);
  final note = TextEditingController();
  DateTime date = today();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setM) => AlertDialog(
        title: Text(l('markDecided')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          InkWell(
            onTap: () async {
              final d = await pickDate(ctx, date);
              if (d != null) setM(() => date = d);
            },
            child: InputDecorator(decoration: dec(ctx, l('decidedOn'), suffix: const Icon(Icons.event)), child: Text(l.date(date))),
          ),
          const SizedBox(height: 12),
          TextField(controller: note, minLines: 2, maxLines: 4, decoration: dec(ctx, l('outcomeNote'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l('save'))),
        ],
      ),
    ),
  );
  if (ok == true) {
    await ref.read(notificationServiceProvider).cancelCaseReminders(c.id);
    await ref.read(repoProvider).markDecided(c.id, ymd(date), note.text);
  }
}
