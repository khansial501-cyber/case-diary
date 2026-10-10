import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/providers.dart';
import '../core/roles.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../data/models.dart';
import '../features/shared/widgets.dart';

const defaultMsgEn =
    'Dear {client}, your case {title} is fixed for hearing on {date} at {court}. Regards, {firm}';
const defaultMsgUr =
    'محترم {client}، آپ کا مقدمہ {title} مورخہ {date} کو {court} میں سماعت کے لیے مقرر ہے۔ والسلام، {firm}';

void registerMessagingHooks() {
  clientSheetHook = showNotifyClientSheet;
}

String buildClientMessage(WidgetRef ref, CaseModel c, String lang, {String? template}) {
  final s = ref.read(settingsProvider);
  final custom = ref.read(roleMapProvider);
  final tpl = template ?? (lang == 'ur' ? s.get('msgTplUr', defaultMsgUr) : s.get('msgTplEn', defaultMsgEn));
  var title = c.title;
  if (s.showRolesOnReceipt) {
    title += ' (${roleLabel(c.sideARole, lang, custom)} Vs ${roleLabel(c.sideBRole, lang, custom)})';
  }
  return fillTemplate(tpl, {
    'client': c.clientName ?? '',
    'title': title,
    'date': fmtYmd(c.nextHearingDate, lang),
    'court': c.courtName ?? '',
    'firm': s.firmName,
  });
}

Future<void> showNotifyClientSheet(BuildContext context, WidgetRef ref, CaseModel c) async {
  final l = ref.read(l10nProvider);
  final s = ref.read(settingsProvider);
  var lang = l.lang;
  final ctrl = TextEditingController(text: buildClientMessage(ref, c, lang));
  final phone = normalizePhone(c.clientWhatsapp?.isNotEmpty == true ? c.clientWhatsapp! : (c.clientPhone ?? ''), cc: s.countryCode);
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setM) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(c.clientName ?? l('client'), style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(c.clientPhone ?? '', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: 'en', label: Text('English')), ButtonSegment(value: 'ur', label: Text('اردو'))],
              selected: {lang},
              onSelectionChanged: (v) => setM(() {
                lang = v.first;
                ctrl.text = buildClientMessage(ref, c, lang);
              }),
            ),
            const SizedBox(height: 12),
            TextField(controller: ctrl, minLines: 3, maxLines: 7, textDirection: lang == 'ur' ? TextDirection.rtl : TextDirection.ltr, decoration: dec(ctx, l('message'))),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                icon: const Icon(Icons.sms),
                label: const Text('SMS'),
                onPressed: phone.isEmpty ? null : () => launchUrl(Uri.parse('sms:+$phone?body=${Uri.encodeComponent(ctrl.text)}')),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.black),
                icon: const Icon(Icons.chat),
                label: const Text('WhatsApp'),
                onPressed: phone.isEmpty ? null : () => launchUrl(Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(ctrl.text)}'), mode: LaunchMode.externalApplication),
              ),
              OutlinedButton.icon(icon: const Icon(Icons.share), label: Text(l('otherApps')), onPressed: () => Share.share(ctrl.text)),
              OutlinedButton.icon(
                icon: const Icon(Icons.call),
                label: Text(l('callClient')),
                onPressed: phone.isEmpty ? null : () => launchUrl(Uri.parse('tel:+$phone')),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
}
