import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../shared/widgets.dart';

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});
  @override
  ConsumerState<ClientsPage> createState() => _ClientsState();
}

class _ClientsState extends ConsumerState<ClientsPage> {
  String q = '';

  Future<void> _edit(ClientModel? x) async {
    if (!requireWritable(context, ref)) return;
    final l = ref.read(l10nProvider);
    final name = TextEditingController(text: x?.name ?? ''), phone = TextEditingController(text: x?.phone ?? '');
    final wa = TextEditingController(text: x?.whatsapp ?? ''), email = TextEditingController(text: x?.email ?? '');
    final addr = TextEditingController(text: x?.address ?? ''), notes = TextEditingController(text: x?.notes ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(x == null ? l('addClient') : l('edit')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: dec(ctx, l('name'))),
            const SizedBox(height: 10),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: dec(ctx, l('phone'))),
            const SizedBox(height: 10),
            TextField(controller: wa, keyboardType: TextInputType.phone, decoration: dec(ctx, 'WhatsApp')),
            const SizedBox(height: 10),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: dec(ctx, l('email'))),
            const SizedBox(height: 10),
            TextField(controller: addr, decoration: dec(ctx, l('address'))),
            const SizedBox(height: 10),
            TextField(controller: notes, decoration: dec(ctx, l('notes'))),
          ]),
        ),
        actions: [
          if (x != null)
            TextButton(
                onPressed: () async {
                  if (await confirm(ctx, l('deleteConfirm'))) {
                    await ref.read(repoProvider).deleteClient(x.id);
                    if (ctx.mounted) Navigator.pop(ctx, false);
                  }
                },
                child: Text(l('delete'), style: const TextStyle(color: Colors.red))),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l('save'))),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await ref.read(repoProvider).saveClient(x?.id, {
        'name': name.text.trim(), 'phone': phone.text.trim(), 'whatsapp': wa.text.trim(),
        'email': email.text.trim(), 'address': addr.text.trim(), 'notes': notes.text.trim(),
      });
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    ref.watch(dataVersionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l('clients'))),
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(null), child: const Icon(Icons.person_add)),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(decoration: dec(context, l('search'), prefix: const Icon(Icons.search)), onChanged: (v) => setState(() => q = v))),
        Expanded(
          child: FutureBuilder<List<ClientModel>>(
            future: ref.read(repoProvider).clients(q: q),
            builder: (ctx, snap) {
              final list = snap.data ?? const [];
              if (list.isEmpty) return EmptyState(icon: Icons.people_outline, text: l('noClients'));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final x = list[i];
                  return AppCard(
                    onTap: () => _edit(x),
                    child: Row(children: [
                      CircleAvatar(backgroundColor: kNavy, child: Text(x.name[0].toUpperCase(), style: const TextStyle(color: kGold))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(x.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), if (x.phone.isNotEmpty) Text(x.phone, style: const TextStyle(fontSize: 12.5))])),
                      if (x.phone.isNotEmpty) IconButton(icon: const Icon(Icons.call), onPressed: () => launchUrl(Uri.parse('tel:+${normalizePhone(x.phone, cc: ref.read(settingsProvider).countryCode)}'))),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
