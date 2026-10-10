import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../services/license_service.dart';
import '../shared/widgets.dart';
import 'license_state.dart';

class ActivationPage extends ConsumerStatefulWidget {
  final bool renew;
  const ActivationPage({super.key, this.renew = false});
  @override
  ConsumerState<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends ConsumerState<ActivationPage> {
  final code = TextEditingController();
  String? error;
  bool busy = false;

  Future<void> _go() async {
    final l = ref.read(l10nProvider);
    setState(() {
      busy = true;
      error = null;
    });
    final r = await ref.read(licenseProvider.notifier).activate(code.text);
    if (!mounted) return;
    setState(() => busy = false);
    switch (r) {
      case LicenseResult.valid:
        HapticFeedback.mediumImpact();
        snack(context, l('activated'));
        if (widget.renew && context.canPop()) context.pop();
        break;
      case LicenseResult.expired:
        setState(() => error = l('errCodeExpired'));
        break;
      case LicenseResult.badFormat:
        setState(() => error = l('errCodeFormat'));
        break;
      case LicenseResult.badSignature:
        setState(() => error = l('errCodeInvalid'));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final lic = ref.watch(licenseProvider);
    final s = ref.watch(settingsProvider);
    return Scaffold(
      appBar: widget.renew ? AppBar(title: Text(l('renew'))) : null,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (!widget.renew) ...[
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [ButtonSegment(value: 'en', label: Text('English')), ButtonSegment(value: 'ur', label: Text('اردو'))],
                selected: {s.lang},
                onSelectionChanged: (v) => ref.read(settingsProvider.notifier).set('lang', v.first),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.balance, size: 64, color: kGold),
            const SizedBox(height: 12),
            Text(kAppName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(l('activateIntro'), textAlign: TextAlign.center),
            const SizedBox(height: 24),
          ] else ...[
            if (lic.expiry != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('${l('expiredOn')}: ${l.date(lic.expiry)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
              ),
          ],
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l('deviceId'), style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              SelectableText(lic.deviceId, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 8),
              Row(children: [
                OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: lic.deviceId));
                      snack(context, l('copied'));
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(l('copy'))),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                    onPressed: () => Share.share('${l('deviceId')}: ${lic.deviceId}'),
                    icon: const Icon(Icons.share, size: 18),
                    label: Text(l('share'))),
              ]),
              const SizedBox(height: 8),
              Text(l('deviceIdHelp'), style: const TextStyle(fontSize: 12.5)),
            ]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: code,
            minLines: 2,
            maxLines: 5,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: dec(context, l('activationCode'), suffix: IconButton(
              icon: const Icon(Icons.paste),
              onPressed: () async {
                final d = await Clipboard.getData('text/plain');
                if (d?.text != null) setState(() => code.text = d!.text!.trim());
              },
            )),
          ),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: busy ? null : _go,
            child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l('activate')),
          ),
        ]),
      ),
    );
  }
}
