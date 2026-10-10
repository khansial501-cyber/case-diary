import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

const dbFileName = 'case_diary.db';
const _common = 'createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL, deletedAt INTEGER, syncedAt INTEGER';

/// Tables that take part in sync / backup (everything except `settings`).
const syncTables = [
  'lawyers', 'courts', 'judges', 'clients', 'cases', 'case_parties', 'party_roles', 'case_categories',
  'hearings', 'documents', 'reminders', 'fees', 'payments',
];

class AppDatabase {
  static Future<String> dbPath() async {
    final dir = await getDatabasesPath();
    return p.join(dir, dbFileName);
  }

  /// Returns the SQLCipher key; creates one on first run (kept in Android Keystore via secure storage).
  static Future<String> loadOrCreateKey(FlutterSecureStorage s) async {
    var k = await s.read(key: 'db_key');
    if (k == null || k.isEmpty) {
      final r = Random.secure();
      k = base64UrlEncode(List<int>.generate(32, (_) => r.nextInt(256)));
      await s.write(key: 'db_key', value: k);
    }
    return k;
  }

  static Future<Database> open(FlutterSecureStorage s) async {
    final key = await loadOrCreateKey(s);
    final path = await dbPath();
    return openDatabase(path, password: key, version: 1, onCreate: _create);
  }

  static Future<void> _create(Database db, int v) async {
    final b = db.batch();
    b.execute('CREATE TABLE lawyers(id TEXT PRIMARY KEY, name TEXT NOT NULL, enrolmentNo TEXT, phone TEXT, email TEXT, isOwner INTEGER DEFAULT 0, $_common)');
    b.execute('CREATE TABLE courts(id TEXT PRIMARY KEY, name TEXT NOT NULL, city TEXT, type TEXT, $_common)');
    b.execute('CREATE TABLE judges(id TEXT PRIMARY KEY, name TEXT NOT NULL, courtId TEXT, $_common)');
    b.execute('CREATE TABLE clients(id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT, whatsapp TEXT, email TEXT, address TEXT, notes TEXT, $_common)');
    b.execute('''CREATE TABLE cases(id TEXT PRIMARY KEY,
      sideAName TEXT, sideAEtc INTEGER DEFAULT 0, sideARole TEXT,
      sideBName TEXT, sideBEtc INTEGER DEFAULT 0, sideBRole TEXT,
      caseCategory TEXT, title TEXT, caseNumber TEXT, caseYear TEXT, natureOfCase TEXT,
      courtId TEXT, currentJudgeId TEXT, representing TEXT DEFAULT 'SIDE_A', clientId TEXT, lawyerId TEXT,
      filedDate TEXT, nextHearingDate TEXT, nextProceedings TEXT, stage TEXT,
      isPriority INTEGER DEFAULT 0, status TEXT DEFAULT 'ONGOING', decidedDate TEXT, outcomeNote TEXT, notes TEXT,
      $_common)''');
    b.execute('CREATE INDEX idx_cases_next ON cases(status, nextHearingDate)');
    b.execute('CREATE INDEX idx_cases_title ON cases(title)');
    b.execute('CREATE TABLE case_parties(id TEXT PRIMARY KEY, caseId TEXT NOT NULL, side TEXT, name TEXT, role TEXT, orderNo INTEGER DEFAULT 0, $_common)');
    b.execute('CREATE TABLE party_roles(id TEXT PRIMARY KEY, label TEXT NOT NULL, labelUr TEXT, $_common)');
    b.execute('CREATE TABLE case_categories(id TEXT PRIMARY KEY, label TEXT NOT NULL, labelUr TEXT, roleA TEXT, roleB TEXT, $_common)');
    b.execute('CREATE TABLE hearings(id TEXT PRIMARY KEY, caseId TEXT NOT NULL, hearingDate TEXT, judgeId TEXT, proceedings TEXT, nextDateSet TEXT, $_common)');
    b.execute('CREATE INDEX idx_hearings_case ON hearings(caseId, hearingDate)');
    b.execute('CREATE TABLE documents(id TEXT PRIMARY KEY, caseId TEXT NOT NULL, type TEXT, title TEXT, filePath TEXT, mimeType TEXT, pageCount INTEGER DEFAULT 1, addedAt INTEGER, hearingId TEXT, $_common)');
    b.execute('CREATE TABLE reminders(id TEXT PRIMARY KEY, caseId TEXT NOT NULL, remindAt INTEGER, message TEXT, notificationId INTEGER, isDone INTEGER DEFAULT 0, $_common)');
    b.execute('CREATE TABLE fees(id TEXT PRIMARY KEY, caseId TEXT NOT NULL, agreedAmount REAL DEFAULT 0, $_common)');
    b.execute('CREATE TABLE payments(id TEXT PRIMARY KEY, caseId TEXT NOT NULL, amount REAL, date TEXT, note TEXT, $_common)');
    b.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT, updatedAt INTEGER)');
    await b.commit(noResult: true);
  }
}
