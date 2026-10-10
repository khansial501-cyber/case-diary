import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/auth_service.dart';
import '../../services/backup_service.dart';
import '../../services/notification_service.dart';
import '../../services/sync_service.dart';
import '../shared/widgets.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});
  @override
  ConsumerState<BackupPage> createState() => _BackupState();
}

class _BackupState extends ConsumerState<BackupPage> {
  bool busy = false;

  Future<String?> _askPassword(String title, {bool confirmField = false}) async {
    final l = ref.read(l10nProvider);
    final a = TextEditingController(), b = TextEditingController();
    String? err;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          title: Text(title),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(confirmField ? l('backupPasswordHelp') : l('restorePasswordHelp'), style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(controller: a, obscureText: true, decoration: dec(ctx, l('password'))),
            if (confirmField) ...[const SizedBox(height: 10), TextField(controller: b, obscureText: true, decoration: dec(ctx, l('confirmPassword')))],
            if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: Colors.red))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l('cancel'))),
            FilledButton(
              onPressed: () {
                if (a.text.length < 6) return setM(() => err = l('errWeakPassword'));
                if (confirmField && a.text != b.text) return setM(() => err = l('errPasswordMismatch'));
                Navigator.pop(ctx, a.text);
              },
              child: Text(l('ok')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _backup() async {
    final l = ref.read(l10nProvider);
    final pw = await _askPassword(l('createBackup'), confirmField: true);
    if (pw == null) return;
    setState(() => busy = true);
    try {
      final svc = BackupService(ref.read(repoProvider), ref.read(secureStorageProvider));
      final path = await svc.create(pw);
      await ref.read(settingsProvider.notifier).set('lastBackup', DateTime.now().millisecondsSinceEpoch.toString());
      await Share.shareXFiles([XFile(path)], text: 'Case Diary backup');
    } catch (e) {
      if (mounted) snack(context, '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restore() async {
    final l = ref.read(l10nProvider);
    if (!requireWritable(context, ref)) return;
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    if (r == null || r.files.single.path == null) return;
    if (!mounted) return;
    if (!await confirm(context, l('restoreWarning'))) return;
    final pw = await _askPassword(l('restoreBackup'));
    if (pw == null) return;
    setState(() => busy = true);
    final err = await BackupService(ref.read(repoProvider), ref.read(secureStorageProvider)).restore(r.files.single.path!, pw);
    if (!mounted) return;
    setState(() => busy = false);
    if (err != null) {
      snack(context, l(err));
      return;
    }
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l('restoreDone')),
        content: Text(l('restartApp')),
        actions: [FilledButton(onPressed: () => SystemNavigator.pop(), child: Text(l('closeApp')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final s = ref.watch(settingsProvider);
    final last = int.tryParse(s.get('lastBackup', '0')) ?? 0;
    final lastSync = int.tryParse(s.get('lastSync', '0')) ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(l('backupRestore'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.shield_outlined, color: kGold), const SizedBox(width: 10), Expanded(child: Text(l('backupIntro')))]),
            const SizedBox(height: 10),
            Text('${l('lastBackup')}: ${last == 0 ? l('never') : fmtDT(last, l)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: busy ? null : _backup,
          icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_upload_outlined),
          label: Text(l('createBackup')),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: busy ? null : _restore,
          icon: const Icon(Icons.restore),
          label: Text(l('restoreBackup')),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l('weeklyBackupReminder')),
          value: s.flag('backupReminder', true),
          onChanged: (v) async {
            await ref.read(settingsProvider.notifier).set('backupReminder', v ? '1' : '0');
            await ref.read(notificationServiceProvider).scheduleWeeklyBackupReminder();
          },
        ),
        const Divider(height: 32),
        SectionTitle(l('cloudSync')),
        Text(firebaseReady ? l('cloudSyncHelp') : l('cloudSyncOff')),
        if (firebaseReady) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l('enableCloudSync')),
            value: s.flag('cloudSync'),
            onChanged: (v) => ref.read(settingsProvider.notifier).set('cloudSync', v ? '1' : '0'),
          ),
          Text('${l('lastSync')}: ${lastSync == 0 ? l('never') : fmtDT(lastSync, l)}'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.sync),
            label: Text(l('syncNow')),
            onPressed: () async {
              final e = await ref.read(syncServiceProvider).syncNow();
              if (mounted) snack(context, e == null ? l('syncDone') : l(e));
            },
          ),
        ],
      ]),
    );
  }
}

String fmtDT(int ms, dynamic l) => fmtDateTimeMs(ms, l.lang as String);
