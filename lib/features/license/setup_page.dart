import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../shared/widgets.dart';

/// First-run firm profile. Also used from Settings > Profile (edit = true).
class SetupPage extends ConsumerStatefulWidget {
  final bool edit;
  const SetupPage({super.key, this.edit = false});
  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController firm, lawyer, bar, phone, email, address;
  String logo = '';

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    firm = TextEditingController(text: s.firmName);
    lawyer = TextEditingController(text: s.lawyerName);
    bar = TextEditingController(text: s.barNo);
    phone = TextEditingController(text: s.phone);
    email = TextEditingController(text: s.email);
    address = TextEditingController(text: s.address);
    logo = s.logoPath;
  }

  Future<void> _pickLogo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 90);
    if (x == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = p.join(dir.path, 'logo_${DateTime.now().millisecondsSinceEpoch}${p.extension(x.path)}');
    await File(x.path).copy(dest);
    setState(() => logo = dest);
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final n = ref.read(settingsProvider.notifier);
    await n.setMany({
      'firmName': firm.text.trim(),
      'lawyerName': lawyer.text.trim(),
      'barNo': bar.text.trim(),
      'phone': phone.text.trim(),
      'email': email.text.trim(),
      'address': address.text.trim(),
      'logoPath': logo,
    });
    final repo = ref.read(repoProvider);
    final lawyers = await repo.lawyers();
    final owner = lawyers.where((x) => x.isOwner).toList();
    final name = lawyer.text.trim().isEmpty ? firm.text.trim() : lawyer.text.trim();
    if (owner.isEmpty) {
      await repo.saveLawyer(name: name, enrolmentNo: bar.text, phone: phone.text, email: email.text, isOwner: true);
    } else {
      await repo.saveLawyer(id: owner.first.id, name: name, enrolmentNo: bar.text, phone: phone.text, email: email.text, isOwner: true);
    }
    if (mounted && widget.edit) {
      snack(context, ref.read(l10nProvider)('saved'));
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(title: Text(widget.edit ? l('firmProfile') : l('setup'))),
      body: SafeArea(
        child: Form(
          key: _key,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            if (!widget.edit) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(l('setupIntro'))),
            Center(
              child: GestureDetector(
                onTap: _pickLogo,
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage: logo.isNotEmpty && File(logo).existsSync() ? FileImage(File(logo)) : null,
                  child: logo.isEmpty ? const Icon(Icons.add_a_photo, size: 30, color: kGold) : null,
                ),
              ),
            ),
            Center(child: TextButton(onPressed: _pickLogo, child: Text(l('chooseLogo')))),
            gap,
            TextFormField(
              controller: firm,
              decoration: dec(context, '${l('firmName')} *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? l('required') : null,
            ),
            gap,
            TextFormField(controller: lawyer, decoration: dec(context, l('lawyerName'))),
            gap,
            TextFormField(controller: bar, decoration: dec(context, l('barNo'))),
            gap,
            TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: dec(context, l('phone'))),
            gap,
            TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: dec(context, l('email'))),
            gap,
            TextFormField(controller: address, minLines: 2, maxLines: 3, decoration: dec(context, l('address'))),
            const SizedBox(height: 22),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: _save,
              child: Text(widget.edit ? l('save') : l('continue')),
            ),
          ]),
        ),
      ),
    );
  }
}
