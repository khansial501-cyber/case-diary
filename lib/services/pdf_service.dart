import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/providers.dart';
import '../core/roles.dart';
import '../core/utils.dart';
import '../data/models.dart';

class PdfFonts {
  final pw.Font base, bold, urdu, urduBold;
  PdfFonts(this.base, this.bold, this.urdu, this.urduBold);
  static PdfFonts? _c;
  static Future<PdfFonts> load() async {
    if (_c != null) return _c!;
    Future<pw.Font> f(String p) async => pw.Font.ttf(await rootBundle.load(p));
    _c = PdfFonts(await f('assets/fonts/Inter-Regular.ttf'), await f('assets/fonts/Inter-Bold.ttf'),
        await f('assets/fonts/NotoNaskhArabic-Regular.ttf'), await f('assets/fonts/NotoNaskhArabic-Bold.ttf'));
    return _c!;
  }

  pw.ThemeData theme() => pw.ThemeData.withFont(base: base, bold: bold, fontFallback: [urdu, urduBold]);
}

bool _hasArabic(String s) => RegExp(r'[\u0600-\u06FF]').hasMatch(s);

/// Text that flips to RTL automatically when it contains Urdu/Arabic letters.
pw.Widget t(String s, {double size = 11, bool bold = false, PdfColor? color, pw.TextAlign? align}) => pw.Text(
      s,
      textDirection: _hasArabic(s) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      textAlign: align ?? (_hasArabic(s) ? pw.TextAlign.right : pw.TextAlign.left),
      style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color),
    );

const _navy = PdfColor.fromInt(0xFF1B3A5C);
const _gold = PdfColor.fromInt(0xFFC9A24B);

pw.Widget _header(AppSettings s, String subtitle, pw.ImageProvider? logo) => pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _gold, width: 2))),
      child: pw.Row(children: [
        if (logo != null) pw.Container(width: 46, height: 46, margin: const pw.EdgeInsets.only(right: 10), child: pw.Image(logo)),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            t(s.firmName, size: 17, bold: true, color: _navy),
            if (s.lawyerName.isNotEmpty) t('${s.lawyerName}${s.phone.isEmpty ? '' : '  |  ${s.phone}'}', size: 10),
            if (s.address.isNotEmpty) t(s.address, size: 9),
          ]),
        ),
        t(subtitle, size: 10),
      ]),
    );

Future<pw.ImageProvider?> _logo(AppSettings s) async {
  if (s.logoPath.isEmpty || !File(s.logoPath).existsSync()) return null;
  return pw.MemoryImage(await File(s.logoPath).readAsBytes());
}

/// One PDF: details + hearing history + every attached document, in order.
Future<Uint8List> buildCaseFilePdf({
  required AppSettings s,
  required L10n l,
  required Labels lb,
  required CaseModel c,
  required List<PartyEntry> parties,
  required List<HearingModel> hearings,
  required List<DocModel> docs,
}) async {
  final fonts = await PdfFonts.load();
  final doc = pw.Document(theme: fonts.theme());
  final logo = await _logo(s);
  String d(String? v) => fmtYmd(v, l.lang);

  pw.Widget row(String k, String? v) => (v == null || v.trim().isEmpty)
      ? pw.SizedBox()
      : pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.SizedBox(width: 120, child: t(k, size: 10, color: PdfColors.grey700)),
            pw.Expanded(child: t(v, size: 11, bold: true)),
          ]));

  final showRoles = s.showRolesOnReceipt;
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    header: (_) => _header(s, l('caseFile'), logo),
    build: (_) => [
      pw.SizedBox(height: 12),
      t(c.title, size: 22, bold: true, color: _navy),
      pw.SizedBox(height: 4),
      t('${lb.cat(c.caseCategory)}${showRoles ? '  |  ${lb.role(c.sideARole)} Vs ${lb.role(c.sideBRole)}' : ''}', size: 10),
      pw.SizedBox(height: 10),
      row(l('firstParty'), '${c.sideAName}${c.sideAEtc ? ' etc' : ''} (${lb.role(c.sideARole)})'),
      row(l('secondParty'), '${c.sideBName}${c.sideBEtc ? ' etc' : ''} (${lb.role(c.sideBRole)})'),
      for (final p in parties) row(p.side == 'A' ? l('firstParty') : l('secondParty'), '${p.name} (${lb.role(p.role)})'),
      row(l('youRepresent'), lb.role(c.representedRole)),
      row(l('natureOfCase'), c.natureOfCase),
      row(l('court'), c.courtName),
      row(l('caseNumber'), c.fullCaseNo),
      row(l('judge'), c.judgeName),
      row(l('client'), c.clientName),
      row(l('assignedLawyer'), c.lawyerName),
      row(l('currentDate'), d(c.filedDate)),
      row(l('status'), c.isDecided ? '${l('decided')} - ${d(c.decidedDate)}' : l('ongoing')),
      if (!c.isDecided) row(l('nextHearing'), d(c.nextHearingDate)),
      row(l('outcome'), c.outcomeNote),
      row(l('latestProceedings'), c.nextProceedings),
      pw.SizedBox(height: 16),
      t(l('hearingHistory'), size: 14, bold: true, color: _navy),
      pw.SizedBox(height: 6),
      if (hearings.isEmpty) t('—'),
      for (final h in hearings)
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            t('${d(h.hearingDate)}${(h.judgeName ?? '').isEmpty ? '' : '  -  ${h.judgeName}'}', bold: true),
            if ((h.proceedings ?? '').trim().isNotEmpty) t(h.proceedings!.trim(), size: 10),
            if ((h.nextDateSet ?? '').isNotEmpty) t('${l('nextDate')}: ${d(h.nextDateSet)}', size: 9.5, color: _navy),
          ]),
        ),
      if ((c.notes ?? '').trim().isNotEmpty) ...[
        pw.SizedBox(height: 10),
        t(l('notes'), size: 14, bold: true, color: _navy),
        t(c.notes!.trim(), size: 10),
      ],
    ],
  ));

  // Attached documents, one page per image / PDF page.
  for (final dm in docs) {
    final f = File(dm.filePath);
    if (!f.existsSync()) continue;
    final images = <pw.ImageProvider>[];
    try {
      if (dm.isImage) {
        images.add(pw.MemoryImage(await f.readAsBytes()));
      } else if (dm.isPdf) {
        await for (final page in Printing.raster(await f.readAsBytes(), dpi: 120)) {
          images.add(pw.MemoryImage(await page.toPng()));
        }
      }
    } catch (_) {}
    for (var i = 0; i < images.length; i++) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Column(children: [
          t('${dm.title}  (${dm.type.replaceAll('_', ' ')})  ${images.length > 1 ? '${i + 1}/${images.length}' : ''}', size: 10, color: PdfColors.grey700),
          pw.SizedBox(height: 6),
          pw.Expanded(child: pw.Center(child: pw.Image(images[i], fit: pw.BoxFit.contain))),
        ]),
      ));
    }
  }
  return doc.save();
}

/// Cause list (all ongoing hearings between two dates).
Future<Uint8List> buildCauseListPdf({
  required AppSettings s,
  required L10n l,
  required Labels lb,
  required String from,
  required String to,
  required List<CaseModel> cases,
}) async {
  final fonts = await PdfFonts.load();
  final doc = pw.Document(theme: fonts.theme());
  final logo = await _logo(s);
  final byDate = <String, List<CaseModel>>{};
  for (final c in cases) {
    byDate.putIfAbsent(c.nextHearingDate ?? '', () => []).add(c);
  }
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    header: (_) => _header(s, '${l('causeList')}\n${fmtYmd(from, l.lang)}${from == to ? '' : ' - ${fmtYmd(to, l.lang)}'}', logo),
    build: (_) => [
      if (cases.isEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 20), child: t(l('noHearings'))),
      for (final e in byDate.entries) ...[
        pw.SizedBox(height: 12),
        t(fmtYmd(e.key, l.lang, weekday: true), size: 13, bold: true, color: _navy),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
          cellStyle: const pw.TextStyle(fontSize: 9.5),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignment: pw.Alignment.centerLeft,
          headers: ['#', l('caseTitle'), l('court'), l('caseNumber'), l('judge'), l('proceedings')],
          columnWidths: {0: const pw.FixedColumnWidth(20), 1: const pw.FlexColumnWidth(3), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(1.4), 4: const pw.FlexColumnWidth(1.6), 5: const pw.FlexColumnWidth(3)},
          data: [
            for (var i = 0; i < e.value.length; i++)
              [
                '${i + 1}',
                '${e.value[i].title}${s.showRolesOnReceipt ? '\n${lb.role(e.value[i].sideARole)} Vs ${lb.role(e.value[i].sideBRole)}' : ''}',
                e.value[i].courtName ?? '',
                e.value[i].fullCaseNo,
                e.value[i].judgeName ?? '',
                (e.value[i].nextProceedings ?? '').trim(),
              ]
          ],
        ),
      ],
    ],
  ));
  return doc.save();
}
