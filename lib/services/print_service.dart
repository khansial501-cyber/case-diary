import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import '../core/providers.dart';
import '../core/utils.dart';
import '../data/models.dart';
import '../features/shared/widgets.dart';

/// Draws the client receipt with Flutter's own text engine so Urdu (Nastaliq) shapes correctly,
/// then returns it as PNG bytes. [widthPx] = 384 for 58 mm, 576 for 80 mm paper.
Future<Uint8List> renderReceiptPng({
  required AppSettings s,
  required CaseModel c,
  required Labels lb,
  required String lang,
  required int widthPx,
}) async {
  final ur = lang == 'ur';
  final dir = ur ? TextDirection.rtl : TextDirection.ltr;
  String d(String? v) => fmtYmd(v, lang, weekday: true);
  final big = widthPx >= 500;
  final k = big ? 1.3 : 1.0;
  const pad = 10.0;
  final painters = <Object>[]; // TextPainter | double (gap) | 'line'

  TextPainter tp(String t, double size, {bool bold = false}) {
    final p = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          color: Colors.black,
          fontSize: size * k,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontFamily: ur ? 'NotoNastaliqUrdu' : 'Inter',
          fontFamilyFallback: const ['NotoNastaliqUrdu', 'Inter'],
          height: ur ? 1.75 : 1.25,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: dir,
    )..layout(maxWidth: widthPx - pad * 2);
    return p;
  }

  void add(String t, double size, {bool bold = false}) {
    if (t.trim().isEmpty) return;
    painters.add(tp(t, size, bold: bold));
  }

  add(s.firmName, 30, bold: true);
  if (s.lawyerName.isNotEmpty) add(s.lawyerName, 21);
  if (s.phone.isNotEmpty) add(s.phone, 21);
  painters.add('line');
  add(ur ? 'مقدمہ' : 'CASE', 19);
  add(c.title, 30, bold: true);
  if (s.showRolesOnReceipt) add('${lb.role(c.sideARole)} Vs ${lb.role(c.sideBRole)}', 21);
  add(lb.cat(c.caseCategory), 20);
  if ((c.courtName ?? '').isNotEmpty) add(c.courtName!, 22);
  if (c.fullCaseNo.isNotEmpty) add('${ur ? 'نمبر' : 'No.'} ${c.fullCaseNo}', 21);
  if ((c.clientName ?? '').isNotEmpty) add(c.clientName!, 21);
  painters.add('line');
  add(ur ? 'اگلی سماعت' : 'NEXT HEARING', 20);
  add(d(c.nextHearingDate), 32, bold: true);
  if ((c.nextProceedings ?? '').trim().isNotEmpty) {
    painters.add(8.0);
    add(c.nextProceedings!.trim().length > 140 ? '${c.nextProceedings!.trim().substring(0, 140)}…' : c.nextProceedings!.trim(), 19);
  }
  painters.add('line');
  add(ur ? 'شکریہ' : 'Thank you', 20);

  var h = pad;
  for (final p in painters) {
    if (p is TextPainter) {
      h += p.height + 4;
    } else if (p is double) {
      h += p;
    } else {
      h += 14;
    }
  }
  h += pad + 10;

  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec, Rect.fromLTWH(0, 0, widthPx.toDouble(), h));
  canvas.drawRect(Rect.fromLTWH(0, 0, widthPx.toDouble(), h), Paint()..color = Colors.white);
  var y = pad;
  for (final p in painters) {
    if (p is TextPainter) {
      p.paint(canvas, Offset((widthPx - p.width) / 2, y));
      y += p.height + 4;
    } else if (p is double) {
      y += p;
    } else {
      canvas.drawLine(Offset(pad, y + 7), Offset(widthPx - pad, y + 7), Paint()..color = Colors.black..strokeWidth = 2);
      y += 14;
    }
  }
  final image = await rec.endRecording().toImage(widthPx, h.ceil());
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  return bd!.buffer.asUint8List();
}

String _lang(AppSettings s) {
  final r = s.get('receiptLang', 'app');
  return r == 'app' ? s.lang : r;
}

Future<bool> _btPermissions() async {
  final r = await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
  return r.values.every((e) => e.isGranted || e.isLimited);
}

Future<List<BluetoothInfo>> pairedPrinters() async {
  if (!await _btPermissions()) return [];
  return PrintBluetoothThermal.pairedBluetooths;
}

/// Sends PNG bytes to the paired thermal printer. Returns an error key or null.
Future<String?> sendPngToThermal(Uint8List png, AppSettings s) async {
  final mac = s.get('printerMac');
  if (mac.isEmpty) return 'errNoPrinter';
  if (!await _btPermissions()) return 'errBtPermission';
  try {
    if (!await PrintBluetoothThermal.bluetoothEnabled) return 'errBtOff';
    final connected = await PrintBluetoothThermal.connectionStatus;
    if (!connected) {
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
      if (!ok) return 'errPrinterConnect';
    }
    final profile = await CapabilityProfile.load();
    final gen = Generator(s.receiptSize == '80' ? PaperSize.mm80 : PaperSize.mm58, profile);
    final image = img.decodePng(png);
    if (image == null) return 'errGeneric';
    final bytes = <int>[...gen.reset(), ...gen.imageRaster(image, align: PosAlign.center), ...gen.feed(3), ...gen.cut()];
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    return ok ? null : 'errPrinterWrite';
  } catch (_) {
    return 'errPrinterWrite';
  }
}

/// Print the receipt: thermal printer if configured, otherwise the system print dialog (PDF roll).
Future<void> printReceipt(BuildContext context, WidgetRef ref, CaseModel c) async {
  final l = ref.read(l10nProvider);
  final s = ref.read(settingsProvider);
  final lb = ref.read(labelsProvider);
  final width = s.receiptSize == '80' ? 576 : 384;
  final png = await renderReceiptPng(s: s, c: c, lb: lb, lang: _lang(s), widthPx: width);
  if (s.get('printerMac').isNotEmpty) {
    final err = await sendPngToThermal(png, s);
    if (context.mounted) snack(context, err == null ? l('printed') : l(err));
    if (err == null) return;
  }
  // Fallback: system print dialog / save as PDF.
  final mm = s.receiptSize == '80' ? 80.0 : 58.0;
  final decoded = img.decodePng(png)!;
  final heightMm = mm * decoded.height / decoded.width;
  final fmt = PdfPageFormat(mm * PdfPageFormat.mm, heightMm * PdfPageFormat.mm, marginAll: 0);
  final pdf = pw.Document();
  pdf.addPage(pw.Page(pageFormat: fmt, margin: pw.EdgeInsets.zero, build: (_) => pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.fill)));
  await Printing.layoutPdf(onLayout: (_) async => pdf.save(), name: 'Receipt ${c.title}', format: fmt);
}
