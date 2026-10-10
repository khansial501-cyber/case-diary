import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/utils.dart';
import '../../services/auth_service.dart';
import '../../services/lock_service.dart';
import '../../services/messaging_service.dart';
import '../../services/notification_service.dart';
import '../license/license_state.dart';
import '../license/setup_page.dart';
import '../shared/widgets.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<String?> _pinDialog(BuildContext context, WidgetRef ref, {required bool confirmNew}) async {
    final l = ref.read(l10nProvider);
    final a = TextEditingController(), b = TextEditingController();
    String? err;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          title: Text(confirmNew ? l('setPin') : l('enterPin')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: a, keyboardType: TextInputType.number, obscureText: true, maxLength: 6, autofocus: true, decoration: InputDecoration(labelText: confirmNew ? l('newPin') : 'PIN', counterText: '')),
            if (confirmNew) TextField(controller: b, keyboardType: TextInputType.number, obscureText: true, maxLength: 6, decoration: InputDecoration(labelText: l('confirmPin'), counterText: '')),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: Colors.red))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l('cancel'))),
            FilledButton(
              onPressed: () {
                if (a.text.length < 4) return setM(() => err = l('pinTooShort'));
                if (confirmNew && a.text != b.text) return setM(() => err = l('errPasswordMismatch'));
                Navigator.pop(ctx, a.text);
              },
              child: Text(l('ok')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref, String hk, String mk, int dh, int dm) async {
    final s = ref.read(settingsProvider);
    final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: int.tryParse(s.get(hk, '$dh')) ?? dh, minute: int.tryParse(s.get(mk, '$dm')) ?? dm));
    if (t == null) return;
    await ref.read(settingsProvider.notifier).setMany({hk: '${t.hour}', mk: '${t.minute}'});
    await ref.read(notificationServiceProvider).rebuildDigests();
  }

  String _hm(AppSettings s, String hk, String mk, int dh, int dm) {
    final h = int.tryParse(s.get(hk, '$dh')) ?? dh, m = int.tryParse(s.get(mk, '$dm')) ?? dm;
    return fmtTime(DateTime(2000, 1, 1, h, m));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final lock = ref.watch(lockProvider);
    final lic = ref.watch(licenseProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l('settings'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        SectionTitle(l('general')),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.business),
          title: Text(l('firmProfile')),
          subtitle: Text(s.firmName),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SetupPage(edit: true))),
        ),
        Text(l('language')),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'en', label: Text('English')), ButtonSegment(value: 'ur', label: Text('اردو'))],
          selected: {s.lang},
          onSelectionChanged: (v) => n.set('lang', v.first),
        ),
        const SizedBox(height: 14),
        Text(l('theme')),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: [ButtonSegment(value: 'system', label: Text(l('system'))), ButtonSegment(value: 'light', label: Text(l('light'))), ButtonSegment(value: 'dark', label: Text(l('dark')))],
          selected: {s.theme},
          onSelectionChanged: (v) => n.set('theme', v.first),
        ),
        const SizedBox(height: 14),
        Text(l('mode')),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: [ButtonSegment(value: 'owner', label: Text(l('owner'))), ButtonSegment(value: 'assistant', label: Text(l('assistant')))],
          selected: {s.get('role', 'owner')},
          onSelectionChanged: (v) async {
            if (v.first == 'owner' && lock.enabled) {
              final pin = await _pinDialog(context, ref, confirmNew: false);
              if (pin == null || !await ref.read(lockProvider.notifier).verifyPin(pin)) {
                if (context.mounted && pin != null) snack(context, l('wrongPin'));
                return;
              }
            }
            await n.set('role', v.first);
          },
        ),
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(l('modeHelp'), style: const TextStyle(fontSize: 12.5))),

        SectionTitle(l('security')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l('appLock')),
          subtitle: Text(l('appLockHelp')),
          value: lock.enabled,
          onChanged: (v) async {
            if (v) {
              final pin = await _pinDialog(context, ref, confirmNew: true);
              if (pin != null) await ref.read(lockProvider.notifier).setPin(pin);
            } else {
              final pin = await _pinDialog(context, ref, confirmNew: false);
              if (pin != null && await ref.read(lockProvider.notifier).verifyPin(pin)) {
                await ref.read(lockProvider.notifier).removePin();
              } else if (pin != null && context.mounted) {
                snack(context, l('wrongPin'));
              }
            }
          },
        ),
        if (lock.enabled) ...[
          FutureBuilder<bool>(
            future: ref.read(lockProvider.notifier).biometricAvailable(),
            builder: (ctx, snap) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l('biometric')),
              value: lock.biometric,
              onChanged: snap.data == true ? (v) => ref.read(lockProvider.notifier).setBiometric(v) : null,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l('autoLockAfter')),
            trailing: DropdownButton<String>(
              value: s.get('autoLockSeconds', '30'),
              items: const [
                DropdownMenuItem(value: '0', child: Text('0 s')),
                DropdownMenuItem(value: '30', child: Text('30 s')),
                DropdownMenuItem(value: '60', child: Text('1 min')),
                DropdownMenuItem(value: '300', child: Text('5 min')),
              ],
              onChanged: (v) => n.set('autoLockSeconds', v ?? '30'),
            ),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l('secureScreen')),
          subtitle: Text(l('secureScreenHelp')),
          value: s.flag('secureScreen'),
          onChanged: (v) => n.set('secureScreen', v ? '1' : '0'),
        ),

        SectionTitle(l('notifications')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l('eveningDigest')),
          subtitle: Text(l('eveningDigestHelp')),
          value: s.flag('digestEnabled', true),
          onChanged: (v) async {
            await n.set('digestEnabled', v ? '1' : '0');
            await ref.read(notificationServiceProvider).rebuildDigests();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: s.flag('digestEnabled', true),
          title: Text(l('digestTime')),
          trailing: Text(_hm(s, 'digestHour', 'digestMinute', 20, 0), style: const TextStyle(fontWeight: FontWeight.w700)),
          onTap: () => _pickTime(context, ref, 'digestHour', 'digestMinute', 20, 0),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l('morningDigest')),
          value: s.flag('morningDigest'),
          onChanged: (v) async {
            await n.set('morningDigest', v ? '1' : '0');
            await ref.read(notificationServiceProvider).rebuildDigests();
          },
        ),
        if (s.flag('morningDigest'))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l('morningTime')),
            trailing: Text(_hm(s, 'morningHour', 'morningMinute', 8, 0), style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => _pickTime(context, ref, 'morningHour', 'morningMinute', 8, 0),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_active_outlined),
          title: Text(l('allowNotifications')),
          onTap: () async {
            final ok = await ensureNotificationPermissions();
            if (context.mounted) snack(context, ok ? l('notificationsOn') : l('notificationsDenied'));
          },
        ),

        SectionTitle(l('clientMessages')),
        TextFormField(
          initialValue: s.get('msgTplEn', defaultMsgEn),
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'English'),
          onChanged: (v) => n.set('msgTplEn', v),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: s.get('msgTplUr', defaultMsgUr),
          minLines: 2,
          maxLines: 4,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'اردو'),
          onChanged: (v) => n.set('msgTplUr', v),
        ),
        Padding(padding: const EdgeInsets.only(top: 6), child: Text(l('templateHelp'), style: const TextStyle(fontSize: 12.5))),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: s.countryCode,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(border: const OutlineInputBorder(), labelText: l('countryCode')),
          onChanged: (v) => n.set('countryCode', v.replaceAll(RegExp(r'[^0-9]'), '')),
        ),

        SectionTitle(l('account')),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.mail_outline), title: Text(auth.email.isEmpty ? '—' : auth.email)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified_outlined),
          title: Text(l('licence')),
          subtitle: Text(lic.lifetime ? l('lifetime') : (lic.expiry == null ? '—' : '${lic.expired ? l('expiredOn') : l('validUntil')}: ${l.date(lic.expiry, weekday: false)}')),
          trailing: TextButton(onPressed: () => context.push('/renew'), child: Text(l('renew'))),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.phone_android),
          title: Text(l('deviceId')),
          subtitle: SelectableText(lic.deviceId),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout, color: Colors.red),
          title: Text(l('logout'), style: const TextStyle(color: Colors.red)),
          onTap: () async {
            if (await confirm(context, l('logoutConfirm'))) await ref.read(authProvider.notifier).logout();
          },
        ),
        const SizedBox(height: 16),
        Center(child: Text('$kAppName 1.0.0', style: const TextStyle(fontSize: 12))),
      ]),
    );
  }
}
