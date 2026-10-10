import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../services/notification_service.dart';
import '../shared/voice_button.dart';
import '../shared/widgets.dart';

class CaseFormPage extends ConsumerStatefulWidget {
  final String? caseId;
  const CaseFormPage({super.key, this.caseId});
  @override
  ConsumerState<CaseFormPage> createState() => _CaseFormState();
}

class _CaseFormState extends ConsumerState<CaseFormPage> {
  final _key = GlobalKey<FormState>();
  final aName = TextEditingController(), bName = TextEditingController();
  final nature = TextEditingController(), court = TextEditingController();
  final caseNo = TextEditingController(), caseYear = TextEditingController();
  final clientName = TextEditingController(), clientPhone = TextEditingController();
  final judge = TextEditingController(), proceedings = TextEditingController();
  bool aEtc = false, bEtc = false, priority = false, loading = true, saving = false;
  String category = 'Civil Suit', roleA = 'Plaintiff', roleB = 'Defendant', representing = 'SIDE_A';
  String? lawyerId;
  DateTime filed = today();
  DateTime? next, remindAt;
  List<PartyEntry> extraA = [], extraB = [];
  List<String> courts = [], judges = [], natures = [];
  List<ClientModel> clients = [];
  List<LawyerModel> lawyers = [];
  CaseModel? existing;

  bool get editing => widget.caseId != null;

  @override
  void initState() {
    super.initState();
    for (final c in [aName, bName]) {
      c.addListener(() => setState(() {}));
    }
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(repoProvider);
    courts = await repo.courtNames();
    judges = await repo.judgeNames();
    natures = await repo.natureNames();
    clients = await repo.clients();
    lawyers = await repo.lawyers();
    if (lawyers.isNotEmpty) lawyerId = lawyers.first.id;
    if (editing) {
      final c = await repo.getCase(widget.caseId!);
      if (c != null) {
        existing = c;
        aName.text = c.sideAName;
        bName.text = c.sideBName;
        aEtc = c.sideAEtc;
        bEtc = c.sideBEtc;
        category = c.caseCategory;
        roleA = c.sideARole;
        roleB = c.sideBRole;
        representing = c.representing;
        nature.text = c.natureOfCase;
        court.text = c.courtName ?? '';
        caseNo.text = c.caseNumber;
        caseYear.text = c.caseYear;
        clientName.text = c.clientName ?? '';
        clientPhone.text = c.clientPhone ?? '';
        judge.text = c.judgeName ?? '';
        proceedings.text = c.nextProceedings ?? '';
        filed = parseYmd(c.filedDate) ?? today();
        next = parseYmd(c.nextHearingDate);
        priority = c.isPriority;
        lawyerId = c.lawyerId ?? lawyerId;
        final parts = await repo.parties(c.id);
        extraA = parts.where((p) => p.side == 'A').toList();
        extraB = parts.where((p) => p.side == 'B').toList();
      }
    } else {
      caseYear.text = DateTime.now().year.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    for (final c in [aName, bName, nature, court, caseNo, caseYear, clientName, clientPhone, judge, proceedings]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyCategory(String cat, List<CustomCategory> custom) {
    category = cat;
    for (final c in builtInCategories) {
      if (c.en == cat) {
        roleA = c.roleA;
        roleB = c.roleB;
        return;
      }
    }
    for (final c in custom) {
      if (c.label == cat) {
        if (c.roleA.isNotEmpty) roleA = c.roleA;
        if (c.roleB.isNotEmpty) roleB = c.roleB;
      }
    }
  }

  Future<List<String>?> _askText(String title, {String? label2}) async {
    final c1 = TextEditingController(), c2 = TextEditingController();
    final l = ref.read(l10nProvider);
    final r = await showDialog<List<String>>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: c1, autofocus: true, decoration: dec(context, l('nameEnglish'))),
          if (label2 != null) ...[
            const SizedBox(height: 10),
            TextField(controller: c2, decoration: dec(context, label2)),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, [c1.text, c2.text]), child: Text(l('save'))),
        ],
      ),
    );
    if (r == null || r[0].trim().isEmpty) return null;
    return [r[0].trim(), r[1].trim()];
  }

  Widget _roleDrop(String value, ValueChanged<String> onChanged) {
    final l = ref.watch(l10nProvider);
    final lb = ref.watch(labelsProvider);
    final custom = ref.watch(customRolesProvider).valueOrNull ?? const [];
    final all = <String>[...builtInRoles.map((e) => e.en), ...custom.map((e) => e.label)];
    if (value.isNotEmpty && !all.contains(value)) all.add(value);
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: all.contains(value) ? value : null,
      decoration: dec(context, l('role')),
      items: [
        ...all.map((r) => DropdownMenuItem(value: r, child: Text(lb.role(r), overflow: TextOverflow.ellipsis))),
        DropdownMenuItem(value: '__add__', child: Text('+ ${l('addCustomRole')}', style: TextStyle(color: Theme.of(context).colorScheme.primary))),
      ],
      onChanged: (v) async {
        if (v == '__add__') {
          final n = await _askText(l('addCustomRole'), label2: l('nameUrdu'));
          if (n != null) {
            await ref.read(repoProvider).addCustomRole(n[0], n[1]);
            onChanged(n[0]);
          }
        } else if (v != null) {
          onChanged(v);
        }
      },
    );
  }

  Future<void> _editParties(String side) async {
    final l = ref.read(l10nProvider);
    final list = side == 'A' ? extraA : extraB;
    final defRole = side == 'A' ? roleA : roleB;
    final working = [for (final p in list) PartyEntry(p.side, p.name, p.role)];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l('moreParties'), style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (var i = 0; i < working.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: working[i].name,
                          decoration: dec(ctx, l('name')),
                          onChanged: (v) => working[i].name = v,
                        ),
                      ),
                      IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setM(() => working.removeAt(i))),
                    ]),
                  ),
              ]),
            ),
            Row(children: [
              TextButton.icon(
                  onPressed: () => setM(() => working.add(PartyEntry(side, '', defRole))),
                  icon: const Icon(Icons.add),
                  label: Text(l('addParty'))),
              const Spacer(),
              FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l('done'))),
            ]),
          ]),
        ),
      ),
    );
    setState(() {
      final cleaned = working.where((p) => p.name.trim().isNotEmpty).toList();
      if (side == 'A') {
        extraA = cleaned;
      } else {
        extraB = cleaned;
      }
    });
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    if (!requireWritable(context, ref)) return;
    final l = ref.read(l10nProvider);
    setState(() => saving = true);
    try {
      final repo = ref.read(repoProvider);
      final c = existing ?? CaseModel();
      c
        ..sideAName = aName.text
        ..sideBName = bName.text
        ..sideAEtc = aEtc
        ..sideBEtc = bEtc
        ..sideARole = roleA
        ..sideBRole = roleB
        ..caseCategory = category
        ..natureOfCase = nature.text
        ..caseNumber = caseNo.text
        ..caseYear = caseYear.text
        ..representing = representing
        ..lawyerId = lawyerId
        ..filedDate = ymd(filed)
        ..nextHearingDate = next == null ? null : ymd(next!)
        ..nextProceedings = proceedings.text.trim()
        ..isPriority = priority;
      final parties = [
        ...extraA.map((p) => PartyEntry('A', p.name, p.role)),
        ...extraB.map((p) => PartyEntry('B', p.name, p.role)),
      ];
      final id = await repo.saveCase(c,
          courtName: court.text,
          judgeName: judge.text,
          clientName: clientName.text,
          clientPhone: clientPhone.text,
          parties: parties);
      if (remindAt != null) {
        await ref.read(notificationServiceProvider).scheduleCaseReminder(
            caseId: id,
            when: remindAt!,
            message: '${l('reminderPrefix')}: ${c.computedTitle}');
      }
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      if (editing) {
        context.pop();
      } else {
        context.pushReplacement('/case/$id');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _dateField(String label, DateTime? v, ValueChanged<DateTime?> onPick, {bool clearable = false}) {
    final l = ref.watch(l10nProvider);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final d = await pickDate(context, v);
        if (d != null) onPick(d);
      },
      child: InputDecorator(
        decoration: dec(context, label,
            suffix: clearable && v != null
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () => onPick(null))
                : const Icon(Icons.event)),
        child: Text(v == null ? '—' : l.date(v), style: const TextStyle(fontSize: 15)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final lb = ref.watch(labelsProvider);
    final customCats = ref.watch(customCategoriesProvider).valueOrNull ?? const [];
    final catList = <String>[...builtInCategories.map((e) => e.en), ...customCats.map((e) => e.label)];
    if (!catList.contains(category)) catList.add(category);
    if (loading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    final title = buildTitle(aName.text, aEtc, bName.text, bEtc);
    const gap = SizedBox(height: 14);

    return Scaffold(
      appBar: AppBar(title: Text(editing ? l('editCase') : l('newCase'))),
      body: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
          // 1. category
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: category,
            decoration: dec(context, l('category')),
            items: [
              ...catList.map((c) => DropdownMenuItem(value: c, child: Text(lb.cat(c)))),
              DropdownMenuItem(value: '__add__', child: Text('+ ${l('addCustomCategory')}', style: TextStyle(color: Theme.of(context).colorScheme.primary))),
            ],
            onChanged: (v) async {
              if (v == '__add__') {
                final name = await _askText(l('addCustomCategory'), label2: l('nameUrdu'));
                if (name != null) {
                  await ref.read(repoProvider).addCustomCategory(name[0], name[1], roleA, roleB);
                  setState(() => category = name[0]);
                }
              } else if (v != null) {
                setState(() => _applyCategory(v, customCats));
              }
            },
          ),
          gap,
          // 2. first party
          Text(l('firstParty'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 5,
              child: TextFormField(
                controller: aName,
                textCapitalization: TextCapitalization.words,
                decoration: dec(context, l('name')),
                validator: (v) => (v == null || v.trim().isEmpty) ? l('required') : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(flex: 4, child: _roleDrop(roleA, (v) => setState(() => roleA = v))),
          ]),
          Row(children: [
            Switch(value: aEtc, onChanged: (v) => setState(() => aEtc = v)),
            const Text('etc'),
            const Spacer(),
            TextButton.icon(
                onPressed: () => _editParties('A'),
                icon: const Icon(Icons.group_add_outlined, size: 18),
                label: Text('${l('addMoreParties')}${extraA.isEmpty ? '' : ' (${extraA.length})'}')),
          ]),
          // 3. second party
          Text(l('secondParty'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 5,
              child: TextFormField(
                controller: bName,
                textCapitalization: TextCapitalization.words,
                decoration: dec(context, l('name')),
                validator: (v) => (v == null || v.trim().isEmpty) ? l('required') : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(flex: 4, child: _roleDrop(roleB, (v) => setState(() => roleB = v))),
          ]),
          Row(children: [
            Switch(value: bEtc, onChanged: (v) => setState(() => bEtc = v)),
            const Text('etc'),
            const Spacer(),
            TextButton.icon(
                onPressed: () => _editParties('B'),
                icon: const Icon(Icons.group_add_outlined, size: 18),
                label: Text('${l('addMoreParties')}${extraB.isEmpty ? '' : ' (${extraB.length})'}')),
          ]),
          // 4. live preview
          AppCard(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l('titlePreview'), style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text(title.isEmpty ? '—' : title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${lb.cat(category)}  |  ${lb.role(roleA)} Vs ${lb.role(roleB)}', style: const TextStyle(fontSize: 12.5)),
            ]),
          ),
          gap,
          AutoField(controller: nature, label: l('natureOfCase'), suggestions: natures),
          gap,
          AutoField(controller: court, label: l('court'), suggestions: courts),
          gap,
          Row(children: [
            Expanded(flex: 3, child: TextFormField(controller: caseNo, decoration: dec(context, l('caseNumber')))),
            const SizedBox(width: 8),
            Expanded(
                flex: 2,
                child: TextFormField(
                    controller: caseYear,
                    keyboardType: TextInputType.number,
                    decoration: dec(context, l('year')))),
          ]),
          gap,
          Text(l('representing'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'SIDE_A', label: Text(lb.role(roleA), overflow: TextOverflow.ellipsis)),
              ButtonSegment(value: 'SIDE_B', label: Text(lb.role(roleB), overflow: TextOverflow.ellipsis)),
            ],
            selected: {representing},
            onSelectionChanged: (s) => setState(() => representing = s.first),
          ),
          gap,
          AutoField(
            controller: clientName,
            label: l('client'),
            suggestions: clients.map((e) => e.name).toList(),
            onSelected: (n) {
              final m = clients.where((e) => e.name == n);
              if (m.isNotEmpty) clientPhone.text = m.first.phone;
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
              controller: clientPhone,
              keyboardType: TextInputType.phone,
              decoration: dec(context, l('clientPhone'), prefix: const Icon(Icons.phone))),
          if (lawyers.length > 1) ...[
            gap,
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: lawyers.any((x) => x.id == lawyerId) ? lawyerId : null,
              decoration: dec(context, l('assignedLawyer')),
              items: lawyers.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name))).toList(),
              onChanged: (v) => setState(() => lawyerId = v),
            ),
          ],
          gap,
          Row(children: [
            Expanded(child: _dateField(l('currentDate'), filed, (d) => setState(() => filed = d ?? filed))),
            const SizedBox(width: 8),
            Expanded(child: _dateField(l('nextHearing'), next, (d) => setState(() => next = d), clearable: true)),
          ]),
          gap,
          AutoField(controller: judge, label: l('judge'), suggestions: judges),
          gap,
          TextFormField(
            controller: proceedings,
            minLines: 3,
            maxLines: 6,
            decoration: dec(context, l('proceedings'), suffix: VoiceButton(controller: proceedings)),
          ),
          gap,
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.star_rounded, color: kGold),
            title: Text(l('markPriority')),
            value: priority,
            onChanged: (v) => setState(() => priority = v),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final d = await pickDateTime(context, remindAt ?? next);
              if (d != null) setState(() => remindAt = d);
            },
            child: InputDecorator(
              decoration: dec(context, l('remindMe'),
                  suffix: remindAt == null
                      ? const Icon(Icons.alarm_add)
                      : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => remindAt = null))),
              child: Text(remindAt == null ? '—' : fmtDateTime(remindAt!, l.lang)),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: saving ? null : _save,
            icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
            label: Text(l('save')),
          ),
        ]),
      ),
    );
  }
}
