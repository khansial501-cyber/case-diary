import 'dart:math';
import 'config.dart';

final _rnd = Random.secure();

/// Globally unique, sortable-ish id (safe for sync).
String newId() {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r = List.generate(10, (_) => _rnd.nextInt(36).toRadixString(36)).join();
  return '$t$r';
}

int nowMs() => DateTime.now().millisecondsSinceEpoch;

String _p2(int n) => n.toString().padLeft(2, '0');

/// yyyy-MM-dd (always Latin digits, locale independent).
String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_p2(d.month)}-${_p2(d.day)}';

DateTime? parseYmd(String? s) {
  if (s == null || s.length < 10) return null;
  try {
    final p = s.substring(0, 10).split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  } catch (_) {
    return null;
  }
}

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsUr = ['جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون', 'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر'];
const _daysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _daysUr = ['پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار'];

/// "Wed, 07 Oct 2026" (or Urdu month/day names).
String fmtDate(DateTime? d, String lang, {bool weekday = true}) {
  if (d == null) return '—';
  final ur = lang == 'ur';
  final m = (ur ? _monthsUr : _monthsEn)[d.month - 1];
  final w = (ur ? _daysUr : _daysEn)[d.weekday - 1];
  final core = '${_p2(d.day)} $m ${d.year}';
  return weekday ? '$w, $core' : core;
}

String fmtYmd(String? s, String lang, {bool weekday = false}) => fmtDate(parseYmd(s), lang, weekday: weekday);

String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${_p2(h)}:${_p2(d.minute)} ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String fmtDateTime(DateTime d, String lang) => '${fmtDate(d, lang, weekday: false)}  ${fmtTime(d)}';

/// Title built from NAMES ONLY: "Ali Vs Ahmad", "Ali etc Vs Ahmad etc".
String buildTitle(String a, bool aEtc, String b, bool bEtc) {
  String side(String n, bool etc) {
    final t = n.trim().replaceAll(RegExp(r'\s+'), ' ');
    return (etc && t.isNotEmpty) ? '$t etc' : t;
  }

  final sa = side(a, aEtc);
  final sb = side(b, bEtc);
  if (sa.isEmpty && sb.isEmpty) return '';
  return '$sa Vs $sb';
}

/// Normalises a phone number to digits with country code (no plus sign).
String normalizePhone(String raw, {String cc = kDefaultCountryCode}) {
  final d = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (d.isEmpty) return '';
  if (d.startsWith('+')) return d.substring(1);
  if (d.startsWith('00')) return d.substring(2);
  if (d.startsWith('0')) return cc + d.substring(1);
  if (d.length <= 10) return cc + d;
  return d;
}

String fillTemplate(String tpl, Map<String, String> vars) {
  var out = tpl;
  vars.forEach((k, v) => out = out.replaceAll('{$k}', v));
  return out;
}

String money(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i - 1] != '-') b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String fmtDateTimeMs(int ms, String lang) => fmtDateTime(DateTime.fromMillisecondsSinceEpoch(ms), lang);
