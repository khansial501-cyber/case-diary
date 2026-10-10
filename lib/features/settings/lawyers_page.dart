import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../shared/widgets.dart';

class LawyersPage extends ConsumerWidget {
  const LawyersPage({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, LawyerModel? x) async {
    if (!requireWritable(context, ref)) return;
    final l = ref.read(l10nProvider);
    final name = TextEditingController(text: x?.name ?? '');
    final bar = TextEditingController(text: x?.enrolmentNo ?? '');
    final phone = TextEditingController(text: x?.phone ?? '');
    final email = TextEditingController(text: x?.email ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(x == null ? l('addLawyer') : l('edit')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: dec(ctx, l('name'))),
            const SizedBox(height: 10),
            TextField(controller: bar, decoration: dec(ctx, l('barNo'))),
            const SizedBox(height: 10),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: dec(ctx, l('phone'))),
            const SizedBox(height: 10),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: dec(ctx, l('email'))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l('save'))),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await ref.read(repoProvider).saveLawyer(
          id: x?.id, name: name.text, enrolmentNo: bar.text, phone: phone.text, email: email.text, isOwner: x?.isOwner ?? false);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final list = ref.watch(lawyersProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l('lawyers'))),
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(context, ref, null), child: const Icon(Icons.person_add)),
      body: list.isEmpty
          ? EmptyState(icon: Icons.badge_outlined, text: l('noLawyers'))
          : ListView(padding: const EdgeInsets.all(16), children: [
              for (final x in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: () => _edit(context, ref, x),
                    child: Row(children: [
                      CircleAvatar(backgroundColor: kNavy, child: Text(x.name.isEmpty ? '?' : x.name[0].toUpperCase(), style: const TextStyle(color: kGold))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(x.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          if (x.enrolmentNo.isNotEmpty) Text('${l('barNo')}: ${x.enrolmentNo}', style: const TextStyle(fontSize: 12.5)),
                          if (x.phone.isNotEmpty) Text(x.phone, style: const TextStyle(fontSize: 12.5)),
                        ]),
                      ),
                      if (x.isOwner) Chip(label: Text(l('owner')))
                      else IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (requireWritable(context, ref) && await confirm(context, l('deleteConfirm'))) {
                              await ref.read(repoProvider).deleteLawyer(x.id);
                            }
                          }),
                    ]),
                  ),
                ),
            ]),
    );
  }
}
