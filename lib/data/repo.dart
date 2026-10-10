import 'package:sqflite_sqlcipher/sqflite.dart';
import '../core/utils.dart';
import 'db.dart';
import 'models.dart';

class CaseFilter {
  final String q;
  final String category; // '' = all
  final String role; // role I represent, '' = all
  final String lawyerId; // '' = all
  const CaseFilter({this.q = '', this.category = '', this.role = '', this.lawyerId = ''});
  CaseFilter copy({String? q, String? category, String? role, String? lawyerId}) => CaseFilter(
      q: q ?? this.q, category: category ?? this.category, role: role ?? this.role, lawyerId: lawyerId ?? this.lawyerId);
}

class Repo {
  final Database db;
  void Function()? onChange;
  Repo(this.db);

  void _changed() => onChange?.call();

  // ---------- generic helpers ----------
  Future<String> _insert(String t, Map<String, Object?> m) async {
    final n = nowMs();
    final id = (m['id'] as String?) ?? newId();
    m['id'] = id;
    m['createdAt'] ??= n;
    m['updatedAt'] = n;
    await db.insert(t, m, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<void> _update(String t, String id, Map<String, Object?> m) async {
    m['updatedAt'] = nowMs();
    await db.update(t, m, where: 'id=?', whereArgs: [id]);
  }

  Future<void> _softDelete(String t, String id) async {
    final n = nowMs();
    await db.update(t, {'deletedAt': n, 'updatedAt': n}, where: 'id=?', whereArgs: [id]);
  }

  // ---------- settings ----------
  Future<Map<String, String>> loadSettings() async {
    final rows = await db.query('settings');
    return {for (final r in rows) r['key'] as String: (r['value'] ?? '') as String};
  }

  Future<void> setSetting(String k, String v) async {
    await db.insert('settings', {'key': k, 'value': v, 'updatedAt': nowMs()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- named lists (courts / judges / roles / categories) ----------
  Future<String?> _ensureNamed(String table, String? name, {Map<String, Object?> extra = const {}}) async {
    final n = (name ?? '').trim();
    if (n.isEmpty) return null;
    final rows = await db.query(table,
        columns: ['id'], where: 'name=? COLLATE NOCASE AND deletedAt IS NULL', whereArgs: [n], limit: 1);
    if (rows.isNotEmpty) return rows.first['id'] as String;
    return _insert(table, {'name': n, ...extra});
  }

  Future<String?> ensureCourt(String? name) => _ensureNamed('courts', name);
  Future<String?> ensureJudge(String? name, {String? courtId}) =>
      _ensureNamed('judges', name, extra: {'courtId': courtId});

  Future<List<String>> courtNames() async => (await db.query('courts',
          columns: ['name'], where: 'deletedAt IS NULL', orderBy: 'name COLLATE NOCASE'))
      .map((e) => e['name'] as String)
      .toList();

  Future<List<String>> judgeNames() async => (await db.query('judges',
          columns: ['name'], where: 'deletedAt IS NULL', orderBy: 'name COLLATE NOCASE'))
      .map((e) => e['name'] as String)
      .toList();

  Future<List<String>> natureNames() async {
    final rows = await db.rawQuery(
        "SELECT DISTINCT natureOfCase n FROM cases WHERE deletedAt IS NULL AND natureOfCase<>'' ORDER BY n COLLATE NOCASE");
    return rows.map((e) => e['n'] as String).toList();
  }

  Future<List<CustomRole>> customRoles() async => (await db.query('party_roles', where: 'deletedAt IS NULL'))
      .map((r) => CustomRole(r['id'] as String, (r['label'] ?? '') as String, (r['labelUr'] ?? '') as String))
      .toList();

  Future<void> addCustomRole(String label, String labelUr) async {
    final n = label.trim();
    if (n.isEmpty) return;
    final ex = await db.query('party_roles',
        where: 'label=? COLLATE NOCASE AND deletedAt IS NULL', whereArgs: [n], limit: 1);
    if (ex.isNotEmpty) return;
    await _insert('party_roles', {'label': n, 'labelUr': labelUr.trim()});
    _changed();
  }

  Future<List<CustomCategory>> customCategories() async =>
      (await db.query('case_categories', where: 'deletedAt IS NULL'))
          .map((r) => CustomCategory(r['id'] as String, (r['label'] ?? '') as String, (r['labelUr'] ?? '') as String,
              (r['roleA'] ?? '') as String, (r['roleB'] ?? '') as String))
          .toList();

  Future<void> addCustomCategory(String label, String labelUr, String roleA, String roleB) async {
    if (label.trim().isEmpty) return;
    await _insert('case_categories',
        {'label': label.trim(), 'labelUr': labelUr.trim(), 'roleA': roleA, 'roleB': roleB});
    _changed();
  }

  // ---------- lawyers ----------
  Future<List<LawyerModel>> lawyers() async => (await db.query('lawyers',
          where: 'deletedAt IS NULL', orderBy: 'isOwner DESC, name COLLATE NOCASE'))
      .map(LawyerModel.fromMap)
      .toList();

  Future<String> saveLawyer({String? id, required String name, String enrolmentNo = '', String phone = '',
      String email = '', bool isOwner = false}) async {
    final m = {'name': name.trim(), 'enrolmentNo': enrolmentNo.trim(), 'phone': phone.trim(),
      'email': email.trim(), 'isOwner': isOwner ? 1 : 0};
    if (id == null) {
      id = await _insert('lawyers', m);
    } else {
      await _update('lawyers', id, m);
    }
    _changed();
    return id;
  }

  Future<void> deleteLawyer(String id) async {
    await _softDelete('lawyers', id);
    await db.update('cases', {'lawyerId': null, 'updatedAt': nowMs()}, where: 'lawyerId=?', whereArgs: [id]);
    _changed();
  }

  // ---------- clients ----------
  Future<List<ClientModel>> clients({String q = ''}) async {
    final like = '%${q.trim()}%';
    final rows = await db.query('clients',
        where: q.trim().isEmpty ? 'deletedAt IS NULL' : 'deletedAt IS NULL AND (name LIKE ? OR phone LIKE ?)',
        whereArgs: q.trim().isEmpty ? null : [like, like],
        orderBy: 'name COLLATE NOCASE');
    return rows.map(ClientModel.fromMap).toList();
  }

  Future<ClientModel?> clientById(String? id) async {
    if (id == null) return null;
    final r = await db.query('clients', where: 'id=?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : ClientModel.fromMap(r.first);
  }

  Future<String?> ensureClient(String? name, String? phone) async {
    final n = (name ?? '').trim();
    if (n.isEmpty) return null;
    final rows = await db.query('clients',
        where: 'name=? COLLATE NOCASE AND deletedAt IS NULL', whereArgs: [n], limit: 1);
    if (rows.isNotEmpty) {
      final id = rows.first['id'] as String;
      if ((phone ?? '').trim().isNotEmpty && rows.first['phone'] != phone!.trim()) {
        await _update('clients', id, {'phone': phone.trim()});
      }
      return id;
    }
    return _insert('clients', {'name': n, 'phone': (phone ?? '').trim()});
  }

  Future<void> saveClient(String? id, Map<String, Object?> m) async {
    if (id == null) {
      await _insert('clients', m);
    } else {
      await _update('clients', id, m);
    }
    _changed();
  }

  Future<void> deleteClient(String id) async {
    await _softDelete('clients', id);
    _changed();
  }

  // ---------- cases ----------
  static const _sel = '''
SELECT c.*, ct.name AS courtName, j.name AS judgeName, cl.name AS clientName, cl.phone AS clientPhone,
  cl.whatsapp AS clientWhatsapp, lw.name AS lawyerName,
  (SELECT COUNT(*) FROM reminders r WHERE r.caseId=c.id AND r.deletedAt IS NULL AND r.isDone=0 AND r.remindAt>?) AS reminderCount
FROM cases c
LEFT JOIN courts ct ON ct.id=c.courtId
LEFT JOIN judges j ON j.id=c.currentJudgeId
LEFT JOIN clients cl ON cl.id=c.clientId
LEFT JOIN lawyers lw ON lw.id=c.lawyerId
''';

  Future<List<CaseModel>> _cases(String where, List<Object?> args, {String order = 'c.title COLLATE NOCASE', int? limit}) async {
    final rows = await db.rawQuery(
        '$_sel WHERE c.deletedAt IS NULL AND ($where) ORDER BY $order${limit != null ? ' LIMIT $limit' : ''}',
        [nowMs(), ...args]);
    return rows.map(CaseModel.fromMap).toList();
  }

  Future<CaseModel?> getCase(String id) async {
    final l = await _cases('c.id=?', [id]);
    return l.isEmpty ? null : l.first;
  }

  Future<List<CaseModel>> casesOn(String date, {String lawyerId = ''}) => _cases(
      "c.status='ONGOING' AND c.nextHearingDate=?${lawyerId.isEmpty ? '' : ' AND c.lawyerId=?'}",
      [date, if (lawyerId.isNotEmpty) lawyerId],
      order: 'c.isPriority DESC, c.title COLLATE NOCASE');

  /// Calendar day list: ongoing cases fixed for the day + any case heard that day.
  Future<List<CaseModel>> casesOnDay(String date) => _cases(
      "(c.status='ONGOING' AND c.nextHearingDate=?) OR c.id IN (SELECT caseId FROM hearings WHERE hearingDate=? AND deletedAt IS NULL)",
      [date, date],
      order: 'c.title COLLATE NOCASE');

  Future<int> countOn(String date, {String lawyerId = ''}) async {
    final r = await db.rawQuery(
        "SELECT COUNT(*) n FROM cases WHERE deletedAt IS NULL AND status='ONGOING' AND nextHearingDate=?${lawyerId.isEmpty ? '' : ' AND lawyerId=?'}",
        [date, if (lawyerId.isNotEmpty) lawyerId]);
    return (r.first['n'] as int?) ?? 0;
  }

  Future<List<CaseModel>> overdue(String todayYmd, {String lawyerId = ''}) => _cases(
      "c.status='ONGOING' AND c.nextHearingDate IS NOT NULL AND c.nextHearingDate<?${lawyerId.isEmpty ? '' : ' AND c.lawyerId=?'}",
      [todayYmd, if (lawyerId.isNotEmpty) lawyerId],
      order: 'c.nextHearingDate');

  Future<List<CaseModel>> ongoing(CaseFilter f) {
    final w = StringBuffer("c.status='ONGOING'");
    final a = <Object?>[];
    _filter(f, w, a);
    return _cases(w.toString(), a, order: "CASE WHEN c.nextHearingDate IS NULL THEN 1 ELSE 0 END, c.nextHearingDate, c.title COLLATE NOCASE");
  }

  Future<List<CaseModel>> priority() =>
      _cases("c.status='ONGOING' AND c.isPriority=1", [], order: 'c.nextHearingDate, c.title COLLATE NOCASE');

  Future<List<CaseModel>> decided(CaseFilter f) {
    final w = StringBuffer("c.status='DECIDED'");
    final a = <Object?>[];
    _filter(f, w, a);
    return _cases(w.toString(), a, order: 'c.decidedDate DESC, c.title COLLATE NOCASE');
  }

  void _filter(CaseFilter f, StringBuffer w, List<Object?> a) {
    final q = f.q.trim();
    if (q.isNotEmpty) {
      w.write(' AND (c.title LIKE ? OR c.caseNumber LIKE ? OR j.name LIKE ? OR ct.name LIKE ? OR c.natureOfCase LIKE ? OR lw.name LIKE ? OR cl.name LIKE ?)');
      for (var i = 0; i < 7; i++) {
        a.add('%$q%');
      }
    }
    if (f.category.isNotEmpty) {
      w.write(' AND c.caseCategory=?');
      a.add(f.category);
    }
    if (f.role.isNotEmpty) {
      w.write(" AND (CASE c.representing WHEN 'SIDE_A' THEN c.sideARole ELSE c.sideBRole END)=?");
      a.add(f.role);
    }
    if (f.lawyerId.isNotEmpty) {
      w.write(' AND c.lawyerId=?');
      a.add(f.lawyerId);
    }
  }

  Future<Map<String, int>> counts() async {
    final rows = await db.rawQuery('SELECT status, COUNT(*) n FROM cases WHERE deletedAt IS NULL GROUP BY status');
    final m = {'ONGOING': 0, 'DECIDED': 0};
    for (final r in rows) {
      m[r['status'] as String] = (r['n'] as int?) ?? 0;
    }
    return m;
  }

  Future<List<PartyEntry>> parties(String caseId) async => (await db.query('case_parties',
          where: 'caseId=? AND deletedAt IS NULL', whereArgs: [caseId], orderBy: 'side, orderNo'))
      .map((r) => PartyEntry((r['side'] ?? 'A') as String, (r['name'] ?? '') as String, (r['role'] ?? '') as String))
      .toList();

  /// Create or update a case. For a NEW case with proceedings/date, the first hearing-history row is written.
  Future<String> saveCase(CaseModel c,
      {String? courtName, String? judgeName, String? clientName, String? clientPhone,
      List<PartyEntry> parties = const []}) async {
    c.courtId = await ensureCourt(courtName) ?? c.courtId;
    if ((courtName ?? '').trim().isEmpty) c.courtId = null;
    c.currentJudgeId = await ensureJudge(judgeName, courtId: c.courtId);
    c.clientId = await ensureClient(clientName, clientPhone);
    final isNew = c.id.isEmpty;
    final m = c.toMap();
    late String id;
    if (isNew) {
      id = await _insert('cases', m);
      if ((c.nextProceedings ?? '').trim().isNotEmpty || (judgeName ?? '').trim().isNotEmpty) {
        await _insert('hearings', {
          'caseId': id,
          'hearingDate': c.filedDate ?? ymd(today()),
          'judgeId': c.currentJudgeId,
          'proceedings': c.nextProceedings,
          'nextDateSet': c.nextHearingDate,
        });
      }
    } else {
      id = c.id;
      await _update('cases', id, m);
    }
    await db.delete('case_parties', where: 'caseId=?', whereArgs: [id]);
    var order = 0;
    for (final p in parties) {
      if (p.name.trim().isEmpty) continue;
      await _insert('case_parties',
          {'caseId': id, 'side': p.side, 'name': p.name.trim(), 'role': p.role, 'orderNo': order++});
    }
    _changed();
    return id;
  }

  /// "Set next date": writes a hearings history row and moves the case to the new date.
  Future<void> setNextDate({
    required String caseId,
    required String hearingDate, // the hearing that just took place
    String? judgeName,
    String proceedingsDone = '',
    required String newDate,
    String proceedingsNext = '',
  }) async {
    await db.transaction((txn) async {
      final jr = (judgeName ?? '').trim();
      String? judgeId;
      if (jr.isNotEmpty) {
        final f = await txn.query('judges',
            columns: ['id'], where: 'name=? COLLATE NOCASE AND deletedAt IS NULL', whereArgs: [jr], limit: 1);
        if (f.isNotEmpty) {
          judgeId = f.first['id'] as String;
        } else {
          judgeId = newId();
          final n = nowMs();
          await txn.insert('judges', {'id': judgeId, 'name': jr, 'createdAt': n, 'updatedAt': n});
        }
      }
      final n = nowMs();
      await txn.insert('hearings', {
        'id': newId(), 'caseId': caseId, 'hearingDate': hearingDate, 'judgeId': judgeId,
        'proceedings': proceedingsDone.trim(), 'nextDateSet': newDate, 'createdAt': n, 'updatedAt': n,
      });
      final latest = proceedingsNext.trim().isNotEmpty ? proceedingsNext.trim() : proceedingsDone.trim();
      await txn.update(
          'cases',
          {
            'nextHearingDate': newDate,
            'nextProceedings': latest,
            if (judgeId != null) 'currentJudgeId': judgeId,
            'updatedAt': n,
          },
          where: 'id=?',
          whereArgs: [caseId]);
    });
    _changed();
  }

  Future<List<HearingModel>> hearings(String caseId) async => (await db.rawQuery('''
SELECT h.*, j.name AS judgeName FROM hearings h LEFT JOIN judges j ON j.id=h.judgeId
WHERE h.caseId=? AND h.deletedAt IS NULL ORDER BY h.hearingDate DESC, h.createdAt DESC''', [caseId]))
      .map(HearingModel.fromMap)
      .toList();

  Future<void> markDecided(String id, String date, String note) async {
    await _update('cases', id, {'status': 'DECIDED', 'decidedDate': date, 'outcomeNote': note.trim()});
    _changed();
  }

  Future<void> reopen(String id) async {
    await _update('cases', id, {'status': 'ONGOING', 'decidedDate': null});
    _changed();
  }

  Future<void> setPriority(String id, bool v) async {
    await _update('cases', id, {'isPriority': v ? 1 : 0});
    _changed();
  }

  Future<void> setCaseNotes(String id, String notes) async {
    await _update('cases', id, {'notes': notes});
    _changed();
  }

  Future<void> deleteCase(String id) async {
    await _softDelete('cases', id);
    _changed();
  }

  /// Dates (yyyy-MM-dd) -> number of cases, for calendar dots.
  Future<Map<String, int>> hearingDots(String from, String to) async {
    final rows = await db.rawQuery('''
SELECT d, COUNT(DISTINCT cid) n FROM (
  SELECT nextHearingDate d, id cid FROM cases WHERE deletedAt IS NULL AND status='ONGOING' AND nextHearingDate IS NOT NULL
  UNION ALL
  SELECT hearingDate d, caseId cid FROM hearings WHERE deletedAt IS NULL
) WHERE d BETWEEN ? AND ? GROUP BY d''', [from, to]);
    return {for (final r in rows) r['d'] as String: (r['n'] as int?) ?? 0};
  }

  /// Ongoing hearings between two dates (cause list / week digest).
  Future<List<CaseModel>> casesBetween(String from, String to) => _cases(
      "c.status='ONGOING' AND c.nextHearingDate BETWEEN ? AND ?", [from, to],
      order: 'c.nextHearingDate, c.title COLLATE NOCASE');

  // ---------- documents ----------
  Future<List<DocModel>> documents(String caseId) async => (await db.query('documents',
          where: 'caseId=? AND deletedAt IS NULL', whereArgs: [caseId], orderBy: 'addedAt'))
      .map(DocModel.fromMap)
      .toList();

  Future<void> addDocument(String caseId, String type, String title, String path, String mime, int pages,
      {String? hearingId}) async {
    await _insert('documents', {
      'caseId': caseId, 'type': type, 'title': title, 'filePath': path, 'mimeType': mime,
      'pageCount': pages, 'addedAt': nowMs(), 'hearingId': hearingId,
    });
    _changed();
  }

  Future<void> updateDocument(String id, {String? title, String? type}) async {
    await _update('documents', id, {if (title != null) 'title': title, if (type != null) 'type': type});
    _changed();
  }

  Future<void> deleteDocument(String id) async {
    await _softDelete('documents', id);
    _changed();
  }

  // ---------- reminders ----------
  Future<int> addReminder(String caseId, DateTime when, String message) async {
    final nid = (nowMs() ~/ 1000) % 2000000000;
    await _insert('reminders', {'caseId': caseId, 'remindAt': when.millisecondsSinceEpoch, 'message': message,
      'notificationId': nid, 'isDone': 0});
    _changed();
    return nid;
  }

  Future<List<ReminderModel>> reminders({String? caseId, bool upcomingOnly = false}) async {
    final w = StringBuffer('r.deletedAt IS NULL');
    final a = <Object?>[];
    if (caseId != null) {
      w.write(' AND r.caseId=?');
      a.add(caseId);
    }
    if (upcomingOnly) {
      w.write(' AND r.isDone=0 AND r.remindAt>?');
      a.add(nowMs());
    }
    final rows = await db.rawQuery(
        'SELECT r.*, c.title AS caseTitle FROM reminders r LEFT JOIN cases c ON c.id=r.caseId WHERE $w ORDER BY r.remindAt', a);
    return rows.map(ReminderModel.fromMap).toList();
  }

  Future<void> setReminderDone(String id, bool done) async {
    await _update('reminders', id, {'isDone': done ? 1 : 0});
    _changed();
  }

  Future<void> deleteReminder(String id) async {
    await _softDelete('reminders', id);
    _changed();
  }

  // ---------- fees ----------
  Future<double> agreedFee(String caseId) async {
    final r = await db.query('fees', where: 'caseId=? AND deletedAt IS NULL', whereArgs: [caseId], limit: 1);
    return r.isEmpty ? 0 : ((r.first['agreedAmount'] ?? 0) as num).toDouble();
  }

  Future<void> setAgreedFee(String caseId, double amount) async {
    final r = await db.query('fees', columns: ['id'], where: 'caseId=? AND deletedAt IS NULL', whereArgs: [caseId], limit: 1);
    if (r.isEmpty) {
      await _insert('fees', {'caseId': caseId, 'agreedAmount': amount});
    } else {
      await _update('fees', r.first['id'] as String, {'agreedAmount': amount});
    }
    _changed();
  }

  Future<List<PaymentModel>> payments(String caseId) async => (await db.query('payments',
          where: 'caseId=? AND deletedAt IS NULL', whereArgs: [caseId], orderBy: 'date DESC'))
      .map(PaymentModel.fromMap)
      .toList();

  Future<void> addPayment(String caseId, double amount, String date, String note) async {
    await _insert('payments', {'caseId': caseId, 'amount': amount, 'date': date, 'note': note.trim()});
    _changed();
  }

  Future<void> deletePayment(String id) async {
    await _softDelete('payments', id);
    _changed();
  }

  /// Per case: title, agreed, paid. Only cases with a fee or payment.
  Future<List<Map<String, Object?>>> feeLedger() => db.rawQuery('''
SELECT c.id, c.title, c.status,
  COALESCE((SELECT SUM(agreedAmount) FROM fees f WHERE f.caseId=c.id AND f.deletedAt IS NULL),0) AS agreed,
  COALESCE((SELECT SUM(amount) FROM payments p WHERE p.caseId=c.id AND p.deletedAt IS NULL),0) AS paid
FROM cases c WHERE c.deletedAt IS NULL
  AND (EXISTS(SELECT 1 FROM fees f WHERE f.caseId=c.id AND f.deletedAt IS NULL AND f.agreedAmount>0)
    OR EXISTS(SELECT 1 FROM payments p WHERE p.caseId=c.id AND p.deletedAt IS NULL))
ORDER BY c.title COLLATE NOCASE''');

  // ---------- reports ----------
  Future<List<Map<String, Object?>>> reportByCourt() => db.rawQuery('''
SELECT COALESCE(ct.name,'—') AS k, COUNT(*) AS n FROM cases c LEFT JOIN courts ct ON ct.id=c.courtId
WHERE c.deletedAt IS NULL GROUP BY k ORDER BY n DESC''');

  Future<List<Map<String, Object?>>> reportByMonth() => db.rawQuery('''
SELECT substr(COALESCE(filedDate,''),1,7) AS k, COUNT(*) AS n FROM cases
WHERE deletedAt IS NULL AND filedDate IS NOT NULL GROUP BY k ORDER BY k DESC LIMIT 24''');

  Future<List<Map<String, Object?>>> reportByOutcome() => db.rawQuery('''
SELECT CASE WHEN status='ONGOING' THEN 'Ongoing' WHEN COALESCE(outcomeNote,'')='' THEN 'Decided (no note)' ELSE outcomeNote END AS k,
  COUNT(*) AS n FROM cases WHERE deletedAt IS NULL GROUP BY k ORDER BY n DESC LIMIT 30''');

  Future<List<Map<String, Object?>>> reportFeesByMonth() => db.rawQuery('''
SELECT substr(date,1,7) AS k, SUM(amount) AS n FROM payments WHERE deletedAt IS NULL GROUP BY k ORDER BY k DESC LIMIT 24''');

  // ---------- sync support ----------
  Future<List<Map<String, Object?>>> changedRows(String table, int since) =>
      db.query(table, where: 'updatedAt>? AND (syncedAt IS NULL OR syncedAt<updatedAt)', whereArgs: [since]);

  Future<void> markSynced(String table, List<String> ids, int ts) async {
    final b = db.batch();
    for (final id in ids) {
      b.rawUpdate('UPDATE $table SET syncedAt=? WHERE id=?', [ts, id]);
    }
    await b.commit(noResult: true);
  }

  /// Insert/replace a row that came from the cloud (only if remote is newer).
  Future<void> upsertRemote(String table, Map<String, Object?> row, int ts) async {
    final id = row['id'] as String;
    final ex = await db.query(table, columns: ['updatedAt'], where: 'id=?', whereArgs: [id], limit: 1);
    final remoteUp = (row['updatedAt'] as num?)?.toInt() ?? 0;
    if (ex.isNotEmpty && ((ex.first['updatedAt'] as int?) ?? 0) >= remoteUp) return;
    final r = Map<String, Object?>.from(row)..['syncedAt'] = ts;
    await db.insert(table, r, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  void notifyChanged() => _changed();
}
