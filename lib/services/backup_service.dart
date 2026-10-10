import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../data/db.dart';
import '../data/repo.dart';

/// Encrypted single-file backups (.cdbk): AES-256-GCM, key from the user's password (PBKDF2).
/// Contains the (already SQLCipher-encrypted) database, its key, and all attached documents.
class BackupService {
  final Repo repo;
  final FlutterSecureStorage storage;
  BackupService(this.repo, this.storage);

  static const _magic = [0x43, 0x44, 0x42, 0x4B, 0x31]; // "CDBK1"
  static const _iterations = 60000;

  Future<SecretKey> _key(String password, List<int> salt) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: _iterations, bits: 256).deriveKeyFromPassword(password: password, nonce: salt);

  Future<Directory> _docsRoot() async => Directory(p.join((await getApplicationDocumentsDirectory()).path, 'docs'));

  /// Returns the path of the created backup file.
  Future<String> create(String password) async {
    final dbPath = await AppDatabase.dbPath();
    final arc = Archive();
    final dbBytes = await File(dbPath).readAsBytes();
    arc.addFile(ArchiveFile('db.sqlite', dbBytes.length, dbBytes));
    final key = utf8.encode(await AppDatabase.loadOrCreateKey(storage));
    arc.addFile(ArchiveFile('dbkey.txt', key.length, key));
    final root = await _docsRoot();
    if (root.existsSync()) {
      for (final e in root.listSync(recursive: true)) {
        if (e is File) {
          final rel = p.relative(e.path, from: root.path).replaceAll('\\', '/');
          final b = await e.readAsBytes();
          arc.addFile(ArchiveFile('docs/$rel', b.length, b));
        }
      }
    }
    final zip = Uint8List.fromList(ZipEncoder().encode(arc)!);
    final saltRnd = SecretKeyData.random(length: 16).bytes;
    final k = await _key(password, saltRnd);
    final box = await AesGcm.with256bits().encrypt(zip, secretKey: k);
    final out = BytesBuilder()
      ..add(_magic)
      ..add(saltRnd)
      ..add(box.concatenation());
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final tmp = await getTemporaryDirectory();
    final f = File(p.join(tmp.path, 'CaseDiary_Backup_${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}.cdbk'));
    await f.writeAsBytes(out.toBytes());
    await repo.setSetting('lastBackup', n.millisecondsSinceEpoch.toString());
    return f.path;
  }

  /// Restores a backup. The app must be restarted afterwards. Returns an error key or null.
  Future<String?> restore(String path, String password) async {
    try {
      final all = await File(path).readAsBytes();
      if (all.length < 5 + 16 + 12 + 16 || !List.generate(5, (i) => all[i] == _magic[i]).every((e) => e)) return 'errBackupFormat';
      final salt = all.sublist(5, 21);
      final k = await _key(password, salt);
      List<int> zip;
      try {
        zip = await AesGcm.with256bits().decrypt(SecretBox.fromConcatenation(all.sublist(21), nonceLength: 12, macLength: 16), secretKey: k);
      } catch (_) {
        return 'errBackupPassword';
      }
      final arc = ZipDecoder().decodeBytes(zip);
      final dbFile = arc.findFile('db.sqlite');
      final keyFile = arc.findFile('dbkey.txt');
      if (dbFile == null || keyFile == null) return 'errBackupFormat';
      final dbKey = utf8.decode(keyFile.content as List<int>);

      // Close the live DB, swap in the restored one.
      await repo.db.close();
      final dbPath = await AppDatabase.dbPath();
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final f = File('$dbPath$suffix');
        if (f.existsSync()) f.deleteSync();
      }
      await File(dbPath).writeAsBytes(dbFile.content as List<int>);
      await storage.write(key: 'db_key', value: dbKey);

      // Documents.
      final root = await _docsRoot();
      if (root.existsSync()) root.deleteSync(recursive: true);
      for (final f in arc.files) {
        if (f.isFile && f.name.startsWith('docs/')) {
          final dest = File(p.join(root.path, f.name.substring(5)));
          dest.parent.createSync(recursive: true);
          await dest.writeAsBytes(f.content as List<int>);
        }
      }
      // Point document rows at this phone's folder.
      final tmp = await openDatabase(dbPath, password: dbKey);
      await tmp.rawUpdate("UPDATE documents SET filePath = ? || substr(filePath, instr(filePath, '/docs/')) WHERE instr(filePath, '/docs/') > 0",
          [p.dirname(root.path)]);
      await tmp.close();
      return null;
    } catch (_) {
      return 'errBackupFormat';
    }
  }
}
