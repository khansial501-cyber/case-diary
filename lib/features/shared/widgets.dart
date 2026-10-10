import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../license/license_state.dart';

void snack(BuildContext c, String msg) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<DateTime?> pickDate(BuildContext c, DateTime? initial, {DateTime? first, DateTime? last}) {
  return showDatePicker(
    context: c,
    initialDate: initial ?? today(),
    firstDate: first ?? DateTime(2000),
    lastDate: last ?? DateTime(2100),
  );
}

Future<DateTime?> pickDateTime(BuildContext c, DateTime? initial) async {
  final base = initial ?? DateTime.now().add(const Duration(hours: 1));
  final d = await showDatePicker(context: c, initialDate: base, firstDate: DateTime(2000), lastDate: DateTime(2100));
  if (d == null) return null;
  final t = await showTimePicker(context: c, initialTime: TimeOfDay.fromDateTime(base));
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

Future<bool> confirm(BuildContext c, String msg, {String? yes, String? no}) async {
  final l = ProviderScope.containerOf(c).read(l10nProvider);
  final r = await showDialog<bool>(
    context: c,
    builder: (_) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(no ?? l('cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(yes ?? l('ok'))),
      ],
    ),
  );
  return r ?? false;
}

/// Blocks writes when the licence has expired. Returns true if the action may proceed.
bool requireWritable(BuildContext c, WidgetRef ref) {
  final lic = ref.read(licenseProvider);
  if (lic.expired) {
    final l = ref.read(l10nProvider);
    showDialog(
      context: c,
      builder: (_) => AlertDialog(
        title: Text(l('licenceExpired')),
        content: Text(l('licenceExpiredMsg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l('cancel'))),
          FilledButton(
              onPressed: () {
                Navigator.pop(c);
                c.push('/renew');
              },
              child: Text(l('renew'))),
        ],
      ),
    );
    return false;
  }
  return true;
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Row(children: [
          Expanded(
              child: Text(text,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurface.withOpacity(0.45);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                shape: BoxShape.circle, border: Border.all(color: c, width: 1.4)),
            child: Icon(icon, size: 44, color: c),
          ),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: c, fontSize: 15)),
        ]),
      ),
    );
  }
}

/// Text field with inline suggestions (works offline, lists are small).
class AutoField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final List<String> suggestions;
  final ValueChanged<String>? onSelected;
  final String? Function(String?)? validator;
  final Widget? suffix;
  const AutoField({
    super.key,
    required this.controller,
    required this.label,
    required this.suggestions,
    this.onSelected,
    this.validator,
    this.suffix,
  });

  @override
  State<AutoField> createState() => _AutoFieldState();
}

class _AutoFieldState extends State<AutoField> {
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return widget.suggestions.where((s) => s.toLowerCase().contains(q) && s.toLowerCase() != q).take(8);
      },
      onSelected: (s) => widget.onSelected?.call(s),
      fieldViewBuilder: (ctx, ctrl, fn, _) => TextFormField(
        controller: ctrl,
        focusNode: fn,
        validator: widget.validator,
        textCapitalization: TextCapitalization.words,
        decoration: dec(context, widget.label, suffix: widget.suffix),
      ),
      optionsViewBuilder: (ctx, onSel, options) => Align(
        alignment: AlignmentDirectional.topStart,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 220, maxWidth: MediaQuery.of(context).size.width - 32),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: options.map((o) => ListTile(dense: true, title: Text(o), onTap: () => onSel(o))).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact case card used in every list.
class CaseCard extends ConsumerWidget {
  final CaseModel c;
  final bool showDate;
  final bool swipe;
  const CaseCard(this.c, {super.key, this.showDate = true, this.swipe = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final lb = ref.watch(labelsProvider);
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withOpacity(0.6);
    final roles = '${lb.role(c.sideARole)} Vs ${lb.role(c.sideBRole)}';
    final card = AppCard(
      onTap: () => context.push('/case/${c.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(c.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          if (c.reminderCount > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6),
              child: Badge(label: Text('${c.reminderCount}'), child: Icon(Icons.alarm, size: 20, color: muted)),
            ),
          if (c.isPriority)
            const Padding(
              padding: EdgeInsetsDirectional.only(start: 8),
              child: Icon(Icons.star_rounded, color: kGold, size: 22),
            ),
        ]),
        const SizedBox(height: 4),
        Text('${lb.cat(c.caseCategory)}  |  $roles', style: TextStyle(color: muted, fontSize: 12.5)),
        const SizedBox(height: 8),
        Wrap(spacing: 14, runSpacing: 4, children: [
          if (showDate && c.nextHearingDate != null)
            _meta(Icons.event, l.ymdDate(c.nextHearingDate), muted),
          if ((c.courtName ?? '').isNotEmpty) _meta(Icons.account_balance, c.courtName!, muted),
          if (c.fullCaseNo.isNotEmpty) _meta(Icons.tag, c.fullCaseNo, muted),
        ]),
        if ((c.nextProceedings ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(c.nextProceedings!.trim(),
              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.35)),
        ],
      ]),
    );
    if (!swipe) return card;
    return Dismissible(
      key: ValueKey('c_${c.id}'),
      background: _swipeBg(context, Icons.call, l('callClient'), Alignment.centerLeft, cs.primary),
      secondaryBackground:
          _swipeBg(context, c.isPriority ? Icons.star_border : Icons.star, l('priority'), Alignment.centerRight, kGold),
      confirmDismiss: (dir) async {
        HapticFeedback.mediumImpact();
        if (dir == DismissDirection.startToEnd) {
          final phone = c.clientPhone ?? '';
          if (phone.isEmpty) {
            snack(context, l('noPhone'));
          } else {
            await showClientSheet(context, ref, c);
          }
        } else {
          if (requireWritable(context, ref)) {
            await ref.read(repoProvider).setPriority(c.id, !c.isPriority);
          }
        }
        return false;
      },
      child: card,
    );
  }

  Widget _meta(IconData i, String t, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 15, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(t, style: TextStyle(fontSize: 13, color: color))),
      ]);

  Widget _swipeBg(BuildContext ctx, IconData i, String t, Alignment a, Color color) => Container(
        alignment: a,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(18)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(i, color: color), Text(t, style: TextStyle(color: color, fontSize: 12))]),
      );
}

/// Quick sheet: call / SMS / WhatsApp. Defined here so swipe works without extra imports.
Future<void> showClientSheet(BuildContext context, WidgetRef ref, CaseModel c) async {
  // Implemented in messaging_service.dart (registered at startup) to avoid import cycles.
  await clientSheetHook?.call(context, ref, c);
}

Future<void> Function(BuildContext, WidgetRef, CaseModel)? clientSheetHook;

class CountChip extends StatelessWidget {
  final String label;
  final int n;
  final bool highlight;
  final VoidCallback? onTap;
  final bool selected;
  const CountChip(this.label, this.n, {super.key, this.highlight = false, this.onTap, this.selected = false});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = highlight ? kGold.withOpacity(0.2) : (selected ? cs.primaryContainer : cs.onSurface.withOpacity(0.06));
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20), border: highlight ? Border.all(color: kGold) : null),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text('$n', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
      ),
    );
  }
}
