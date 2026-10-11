import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../shared/widgets.dart';

final docsProvider = FutureProvider.autoDispose.family<List<DocModel>, String>((ref, id) {
  ref.watch(dataVersionProvider);
  return ref.read(repoProvider).documents(id);
});

String docTypeLabel(L10n l, String t) => l('doc_$t');

IconData _typeIcon(String t) {
  switch (t) {
    case 'APPLICATION':
      return Icons.description_outlined;
    case 'ORDER_SHEET':
      return Icons.receipt_long_outlined;
    case 'EVIDENCE':
      return Icons.photo_library_outlined;
    case 'JUDGMENT':
      return Icons.gavel;
    default:
      return Icons.attach_file;
  }
}

Future<Directory> _caseDir(String caseId) async {
  final base = await getApplicationDocumentsDirectory();
  final d = Directory(p.join(base.path, 'docs', caseId));
  if (!d.existsSync()) d.createSync(recursive: true);
  return d;
}

String _mime(String path) {
  final e = p.extension(path).toLowerCase();
  if (e == '.pdf') return 'application/pdf';
  if (e == '.png') return 'image/png';
  if (e == '.jpg' || e == '.jpeg') return 'image/jpeg';
  if (e == '.webp') return 'image/webp';
  return 'application/octet-stream';
}

class DocumentsSection extends ConsumerWidget {
  final String caseId;
  const DocumentsSection({super.key, required this.caseId});

  Future<({String type, String title})?> _ask(BuildContext context, WidgetRef ref, String defTitle, {String type = 'OTHER'}) async {
    final l = ref.read(l10nProvider);
    final title = TextEditingController(text: defTitle);
    var t = type;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          title: Text(l('documentDetails')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, decoration: dec(ctx, l('title'))),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: t,
              decoration: dec(ctx, l('type')),
              items: docTypes.map((e) => DropdownMenuItem(value: e, child: Text(docTypeLabel(l, e)))).toList(),
              onChanged: (v) => setM(() => t = v ?? t),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l('save'))),
          ],
        ),
      ),
    );
    if (ok != true) return null;
    return (type: t, title: title.text.trim().isEmpty ? defTitle : title.text.trim());
  }

  Future<void> _addFromPaths(BuildContext context, WidgetRef ref, List<String> imgs, {bool asPdf = false}) async {
    if (imgs.isEmpty) return;
    final dir = await _caseDir(caseId);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final defTitle = 'Scan ${fmtDate(DateTime.now(), 'en', weekday: false)}';
    final info = await _ask(context, ref, defTitle);
    if (info == null) return;
    final repo = ref.read(repoProvider);
    if (asPdf && imgs.length > 1) {
      final pdf = pw.Document();
      for (final path in imgs) {
        final img = pw.MemoryImage(await File(path).readAsBytes());
        pdf.addPage(pw.Page(margin: const pw.EdgeInsets.all(12), build: (_) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain))));
      }
      final out = File(p.join(dir.path, '$stamp.pdf'));
      await out.writeAsBytes(await pdf.save());
      await repo.addDocument(caseId, info.type, info.title, out.path, 'application/pdf', imgs.length);
    } else {
      for (var i = 0; i < imgs.length; i++) {
        final ext = p.extension(imgs[i]).isEmpty ? '.jpg' : p.extension(imgs[i]);
        final out = await File(imgs[i]).copy(p.join(dir.path, '${stamp}_$i$ext'));
        await repo.addDocument(caseId, info.type, imgs.length > 1 ? '${info.title} ${i + 1}' : info.title, out.path, _mime(out.path), 1);
      }
    }
  }

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final l = ref.read(l10nProvider);
    final cam = await Permission.camera.request();
    if (!cam.isGranted) {
      if (context.mounted) snack(context, l('cameraDenied'));
      return;
    }
    final pics = <String>[];
    while (true) {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
      if (x == null) break;
      pics.add(x.path);
      if (!context.mounted) return;
      final more = await confirm(context, l('addAnotherPage'), yes: l('yes'), no: l('done'));
      if (!more) break;
    }
    if (pics.isNotEmpty && context.mounted) await _addFromPaths(context, ref, pics, asPdf: true);
  }

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    if (!requireWritable(context, ref)) return;
    final l = ref.read(l10nProvider);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.document_scanner), title: Text(l('scanDocument')), subtitle: Text(l('scanHint')), onTap: () => Navigator.pop(ctx, 'scan')),
          ListTile(leading: const Icon(Icons.photo_camera), title: Text(l('takePhoto')), onTap: () => Navigator.pop(ctx, 'camera')),
          ListTile(leading: const Icon(Icons.photo_library), title: Text(l('fromGallery')), onTap: () => Navigator.pop(ctx, 'gallery')),
          ListTile(leading: const Icon(Icons.picture_as_pdf), title: Text(l('pickPdfFile')), onTap: () => Navigator.pop(ctx, 'file')),
        ]),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'scan') {
      await _scan(context, ref);
    } else if (choice == 'camera') {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
      if (x != null && context.mounted) await _addFromPaths(context, ref, [x.path]);
    } else if (choice == 'gallery') {
      final xs = await ImagePicker().pickMultiImage(imageQuality: 85);
      if (xs.isNotEmpty && context.mounted) await _addFromPaths(context, ref, xs.map((e) => e.path).toList());
    } else {
      final r = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (r == null || !context.mounted) return;
      final dir = await _caseDir(caseId);
      for (final f in r.files) {
        if (f.path == null) continue;
        final info = await _ask(context, ref, p.basenameWithoutExtension(f.name));
        if (info == null) continue;
        final out = await File(f.path!).copy(p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}_${f.name}'));
        await ref.read(repoProvider).addDocument(caseId, info.type, info.title, out.path, _mime(out.path), 1);
      }
    }
  }

  void _open(BuildContext context, DocModel d) {
    if (d.isImage) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ImageViewer(d)));
    } else if (d.isPdf) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PdfViewer(d)));
    } else {
      Share.shareXFiles([XFile(d.filePath)]);
    }
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, DocModel d) async {
    final l = ref.read(l10nProvider);
    final act = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.edit), title: Text(l('rename')), onTap: () => Navigator.pop(ctx, 'rename')),
          ListTile(leading: const Icon(Icons.category), title: Text(l('changeType')), onTap: () => Navigator.pop(ctx, 'type')),
          ListTile(leading: const Icon(Icons.share), title: Text(l('share')), onTap: () => Navigator.pop(ctx, 'share')),
          ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: Text(l('delete')), onTap: () => Navigator.pop(ctx, 'delete')),
        ]),
      ),
    );
    if (act == null || !context.mounted) return;
    final repo = ref.read(repoProvider);
    if (act == 'share') {
      await Share.shareXFiles([XFile(d.filePath)]);
      return;
    }
    if (!requireWritable(context, ref)) return;
    if (act == 'delete') {
      if (await confirm(context, l('deleteConfirm'))) {
        await repo.deleteDocument(d.id);
        try {
          File(d.filePath).deleteSync();
        } catch (_) {}
      }
    } else {
      final info = await _ask(context, ref, d.title, type: d.type);
      if (info != null) await repo.updateDocument(d.id, title: info.title, type: info.type);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final docs = ref.watch(docsProvider(caseId)).valueOrNull ?? const [];
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle(l('documents'),
          trailing: FilledButton.tonalIcon(onPressed: () => _upload(context, ref), icon: const Icon(Icons.upload_file, size: 18), label: Text(l('upload')))),
      if (docs.isEmpty)
        Padding(padding: const EdgeInsets.all(12), child: Text(l('noDocuments'), style: TextStyle(color: cs.onSurface.withOpacity(0.55))))
      else
        for (final t in docTypes)
          if (docs.any((d) => d.type == t)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
              child: Row(children: [Icon(_typeIcon(t), size: 16, color: kGold), const SizedBox(width: 6), Text(docTypeLabel(l, t), style: const TextStyle(fontWeight: FontWeight.w700))]),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.82,
              children: [
                for (final d in docs.where((e) => e.type == t))
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _open(context, d),
                    onLongPress: () => _menu(context, ref, d),
                    child: Column(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            color: cs.onSurface.withOpacity(0.06),
                            child: d.isImage && File(d.filePath).existsSync()
                                ? Image.file(File(d.filePath), fit: BoxFit.cover, cacheWidth: 300)
                                : Icon(d.isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file, size: 40, color: cs.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                      if (d.pageCount > 1) Text('${d.pageCount} pp', style: const TextStyle(fontSize: 10)),
                    ]),
                  ),
              ],
            ),
          ],
    ]);
  }
}

class _ImageViewer extends StatelessWidget {
  final DocModel d;
  const _ImageViewer(this.d);
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text(d.title), actions: [IconButton(icon: const Icon(Icons.share), onPressed: () => Share.shareXFiles([XFile(d.filePath)]))]),
        body: InteractiveViewer(maxScale: 6, child: Center(child: Image.file(File(d.filePath)))),
      );
}

class _PdfViewer extends StatelessWidget {
  final DocModel d;
  const _PdfViewer(this.d);
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(d.title)),
        body: PdfPreview(
          build: (_) => File(d.filePath).readAsBytes(),
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          pdfFileName: '${d.title}.pdf',
        ),
      );
}
