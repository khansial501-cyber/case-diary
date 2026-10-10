import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/print_service.dart';
import '../shared/widgets.dart';

class PrinterPage extends ConsumerStatefulWidget {
  const PrinterPage({super.key});
  @override
  ConsumerState<PrinterPage> createState() => _PrinterState();
}

class _PrinterState extends ConsumerState<PrinterPage> {
  List<BluetoothInfo> devices = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => loading = true);
    final d = await pairedPrinters();
    if (mounted) setState(() {
      devices = d;
      loading = false;
    });
  }

  Future<void> _test() async {
    final l = ref.read(l10nProvider);
    final s = ref.read(settingsProvider);
    final c = CaseModel(
      sideAName: 'Ali', sideBName: 'Ahmad', sideAEtc: true, sideBEtc: true, caseCategory: 'Civil Suit',
      caseNumber: '123', caseYear: '2026', courtName: 'Civil Court', clientName: 'Test Client',
      nextHearingDate: '2026-12-01', nextProceedings: 'Evidence of plaintiff',
    );
    final png = await renderReceiptPng(
        s: s, c: c, lb: ref.read(labelsProvider), lang: s.get('receiptLang', 'app') == 'app' ? s.lang : s.get('receiptLang'),
        widthPx: s.receiptSize == '80' ? 576 : 384);
    final err = await sendPngToThermal(png, s);
    if (mounted) snack(context, err == null ? l('printed') : l(err));
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l('printerSettings')), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _scan)]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(l('printerHelp')),
        const SectionTitle('58 / 80 mm'),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: '58', label: Text('58 mm')), ButtonSegment(value: '80', label: Text('80 mm'))],
          selected: {s.receiptSize},
          onSelectionChanged: (v) => n.set('receiptSize', v.first),
        ),
        const SizedBox(height: 14),
        Text(l('receiptLanguage')),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: [ButtonSegment(value: 'app', label: Text(l('followApp'))), const ButtonSegment(value: 'en', label: Text('English')), const ButtonSegment(value: 'ur', label: Text('اردو'))],
          selected: {s.get('receiptLang', 'app')},
          onSelectionChanged: (v) => n.set('receiptLang', v.first),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l('showRoles')),
          subtitle: Text(l('showRolesHelp')),
          value: s.showRolesOnReceipt,
          onChanged: (v) => n.set('showRolesOnReceipt', v ? '1' : '0'),
        ),
        SectionTitle(l('pairedPrinters')),
        if (loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
        if (!loading && devices.isEmpty) Text(l('noPairedPrinters')),
        for (final d in devices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              onTap: () => n.setMany({'printerMac': d.macAdress, 'printerName': d.name}),
              child: Row(children: [
                const Icon(Icons.print),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)), Text(d.macAdress, style: const TextStyle(fontSize: 12))])),
                if (s.get('printerMac') == d.macAdress) const Icon(Icons.check_circle, color: kGold),
              ]),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: s.get('printerMac').isEmpty ? null : _test, icon: const Icon(Icons.receipt), label: Text(l('testPrint'))),
        if (s.get('printerMac').isNotEmpty)
          TextButton(onPressed: () => n.setMany({'printerMac': '', 'printerName': ''}), child: Text(l('forgetPrinter'))),
      ]),
    );
  }
}
