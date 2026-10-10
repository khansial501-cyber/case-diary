import '../core/utils.dart';

int _i(Object? v) => v is int ? v : (v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0));
bool _b(Object? v) => _i(v) == 1;

class CaseModel {
  String id;
  String sideAName, sideARole, sideBName, sideBRole;
  bool sideAEtc, sideBEtc;
  String caseCategory, title, caseNumber, caseYear, natureOfCase;
  String? courtId, currentJudgeId, clientId, lawyerId;
  String representing; // SIDE_A | SIDE_B
  String? filedDate, nextHearingDate, nextProceedings, stage, decidedDate, outcomeNote, notes;
  bool isPriority;
  String status; // ONGOING | DECIDED
  // joined display fields
  String? courtName, judgeName, clientName, clientPhone, clientWhatsapp, lawyerName;
  int reminderCount;
  int createdAt, updatedAt;

  CaseModel({
    this.id = '',
    this.sideAName = '',
    this.sideARole = 'Plaintiff',
    this.sideBName = '',
    this.sideBRole = 'Defendant',
    this.sideAEtc = false,
    this.sideBEtc = false,
    this.caseCategory = 'Civil Suit',
    this.title = '',
    this.caseNumber = '',
    this.caseYear = '',
    this.natureOfCase = '',
    this.courtId,
    this.currentJudgeId,
    this.clientId,
    this.lawyerId,
    this.representing = 'SIDE_A',
    this.filedDate,
    this.nextHearingDate,
    this.nextProceedings,
    this.stage,
    this.decidedDate,
    this.outcomeNote,
    this.notes,
    this.isPriority = false,
    this.status = 'ONGOING',
    this.courtName,
    this.judgeName,
    this.clientName,
    this.clientPhone,
    this.clientWhatsapp,
    this.lawyerName,
    this.reminderCount = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  bool get isDecided => status == 'DECIDED';
  String get representedRole => representing == 'SIDE_A' ? sideARole : sideBRole;
  String get computedTitle => buildTitle(sideAName, sideAEtc, sideBName, sideBEtc);
  String get fullCaseNo => [caseNumber, caseYear].where((e) => e.trim().isNotEmpty).join('/');

  factory CaseModel.fromMap(Map<String, Object?> m) => CaseModel(
        id: m['id'] as String,
        sideAName: (m['sideAName'] ?? '') as String,
        sideARole: (m['sideARole'] ?? '') as String,
        sideBName: (m['sideBName'] ?? '') as String,
        sideBRole: (m['sideBRole'] ?? '') as String,
        sideAEtc: _b(m['sideAEtc']),
        sideBEtc: _b(m['sideBEtc']),
        caseCategory: (m['caseCategory'] ?? '') as String,
        title: (m['title'] ?? '') as String,
        caseNumber: (m['caseNumber'] ?? '') as String,
        caseYear: (m['caseYear'] ?? '') as String,
        natureOfCase: (m['natureOfCase'] ?? '') as String,
        courtId: m['courtId'] as String?,
        currentJudgeId: m['currentJudgeId'] as String?,
        clientId: m['clientId'] as String?,
        lawyerId: m['lawyerId'] as String?,
        representing: (m['representing'] ?? 'SIDE_A') as String,
        filedDate: m['filedDate'] as String?,
        nextHearingDate: m['nextHearingDate'] as String?,
        nextProceedings: m['nextProceedings'] as String?,
        stage: m['stage'] as String?,
        decidedDate: m['decidedDate'] as String?,
        outcomeNote: m['outcomeNote'] as String?,
        notes: m['notes'] as String?,
        isPriority: _b(m['isPriority']),
        status: (m['status'] ?? 'ONGOING') as String,
        courtName: m['courtName'] as String?,
        judgeName: m['judgeName'] as String?,
        clientName: m['clientName'] as String?,
        clientPhone: m['clientPhone'] as String?,
        clientWhatsapp: m['clientWhatsapp'] as String?,
        lawyerName: m['lawyerName'] as String?,
        reminderCount: _i(m['reminderCount']),
        createdAt: _i(m['createdAt']),
        updatedAt: _i(m['updatedAt']),
      );

  /// Only real table columns (no joined fields).
  Map<String, Object?> toMap() => {
        'sideAName': sideAName.trim(),
        'sideARole': sideARole,
        'sideAEtc': sideAEtc ? 1 : 0,
        'sideBName': sideBName.trim(),
        'sideBRole': sideBRole,
        'sideBEtc': sideBEtc ? 1 : 0,
        'caseCategory': caseCategory,
        'title': computedTitle,
        'caseNumber': caseNumber.trim(),
        'caseYear': caseYear.trim(),
        'natureOfCase': natureOfCase.trim(),
        'courtId': courtId,
        'currentJudgeId': currentJudgeId,
        'clientId': clientId,
        'lawyerId': lawyerId,
        'representing': representing,
        'filedDate': filedDate,
        'nextHearingDate': nextHearingDate,
        'nextProceedings': nextProceedings,
        'stage': stage,
        'decidedDate': decidedDate,
        'outcomeNote': outcomeNote,
        'notes': notes,
        'isPriority': isPriority ? 1 : 0,
        'status': status,
      };
}

class PartyEntry {
  String side; // A | B
  String name, role;
  PartyEntry(this.side, this.name, this.role);
}

class HearingModel {
  final String id, caseId;
  final String? hearingDate, judgeId, judgeName, proceedings, nextDateSet;
  final int createdAt;
  HearingModel(this.id, this.caseId, this.hearingDate, this.judgeId, this.judgeName, this.proceedings,
      this.nextDateSet, this.createdAt);
  factory HearingModel.fromMap(Map<String, Object?> m) => HearingModel(
      m['id'] as String,
      m['caseId'] as String,
      m['hearingDate'] as String?,
      m['judgeId'] as String?,
      m['judgeName'] as String?,
      m['proceedings'] as String?,
      m['nextDateSet'] as String?,
      _i(m['createdAt']));
}

const docTypes = ['APPLICATION', 'ORDER_SHEET', 'EVIDENCE', 'JUDGMENT', 'OTHER'];

class DocModel {
  final String id, caseId, type, title, filePath;
  final String? mimeType, hearingId;
  final int pageCount, addedAt;
  DocModel(this.id, this.caseId, this.type, this.title, this.filePath, this.mimeType, this.pageCount,
      this.addedAt, this.hearingId);
  bool get isImage => (mimeType ?? '').startsWith('image/');
  bool get isPdf => (mimeType ?? '') == 'application/pdf';
  factory DocModel.fromMap(Map<String, Object?> m) => DocModel(
      m['id'] as String,
      m['caseId'] as String,
      (m['type'] ?? 'OTHER') as String,
      (m['title'] ?? '') as String,
      (m['filePath'] ?? '') as String,
      m['mimeType'] as String?,
      _i(m['pageCount']),
      _i(m['addedAt']),
      m['hearingId'] as String?);
}

class ReminderModel {
  final String id, caseId;
  final String? caseTitle;
  final int remindAt, notificationId;
  final String message;
  final bool isDone;
  ReminderModel(this.id, this.caseId, this.caseTitle, this.remindAt, this.message, this.notificationId, this.isDone);
  DateTime get when => DateTime.fromMillisecondsSinceEpoch(remindAt);
  factory ReminderModel.fromMap(Map<String, Object?> m) => ReminderModel(
      m['id'] as String,
      m['caseId'] as String,
      m['caseTitle'] as String?,
      _i(m['remindAt']),
      (m['message'] ?? '') as String,
      _i(m['notificationId']),
      _b(m['isDone']));
}

class LawyerModel {
  final String id;
  final String name, enrolmentNo, phone, email;
  final bool isOwner;
  LawyerModel(this.id, this.name, this.enrolmentNo, this.phone, this.email, this.isOwner);
  factory LawyerModel.fromMap(Map<String, Object?> m) => LawyerModel(m['id'] as String, (m['name'] ?? '') as String,
      (m['enrolmentNo'] ?? '') as String, (m['phone'] ?? '') as String, (m['email'] ?? '') as String, _b(m['isOwner']));
}

class ClientModel {
  final String id;
  final String name, phone, whatsapp, email, address, notes;
  ClientModel(this.id, this.name, this.phone, this.whatsapp, this.email, this.address, this.notes);
  factory ClientModel.fromMap(Map<String, Object?> m) => ClientModel(
      m['id'] as String,
      (m['name'] ?? '') as String,
      (m['phone'] ?? '') as String,
      (m['whatsapp'] ?? '') as String,
      (m['email'] ?? '') as String,
      (m['address'] ?? '') as String,
      (m['notes'] ?? '') as String);
}

class PaymentModel {
  final String id, caseId;
  final double amount;
  final String date, note;
  PaymentModel(this.id, this.caseId, this.amount, this.date, this.note);
  factory PaymentModel.fromMap(Map<String, Object?> m) => PaymentModel(m['id'] as String, m['caseId'] as String,
      ((m['amount'] ?? 0) as num).toDouble(), (m['date'] ?? '') as String, (m['note'] ?? '') as String);
}

class CustomRole {
  final String id, label, labelUr;
  CustomRole(this.id, this.label, this.labelUr);
}

class CustomCategory {
  final String id, label, labelUr, roleA, roleB;
  CustomCategory(this.id, this.label, this.labelUr, this.roleA, this.roleB);
}
