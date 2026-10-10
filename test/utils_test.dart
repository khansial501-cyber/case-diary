import 'package:case_diary/core/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildTitle', () {
    test('simple', () => expect(buildTitle('Ali', false, 'Ahmad', false), 'Ali Vs Ahmad'));
    test('one etc', () => expect(buildTitle('Ali', true, 'Ahmad', false), 'Ali etc Vs Ahmad'));
    test('both etc', () => expect(buildTitle('Ali', true, 'Ahmad', true), 'Ali etc Vs Ahmad etc'));
    test('trims and collapses spaces', () => expect(buildTitle('  Ali   Khan ', false, ' Ahmad ', true), 'Ali Khan Vs Ahmad etc'));
    test('empty', () => expect(buildTitle('', true, '', true), ''));
  });

  group('normalizePhone', () {
    test('local 03xx', () => expect(normalizePhone('0300-1234567'), '923001234567'));
    test('plus form', () => expect(normalizePhone('+92 300 1234567'), '923001234567'));
    test('00 form', () => expect(normalizePhone('0092300 1234567'), '923001234567'));
    test('already international', () => expect(normalizePhone('923001234567'), '923001234567'));
    test('other country code', () => expect(normalizePhone('0501234567', cc: '971'), '971501234567'));
    test('empty', () => expect(normalizePhone('  '), ''));
  });

  test('fillTemplate', () {
    expect(fillTemplate('Dear {client}, {date}', {'client': 'Bilal', 'date': '01 Dec 2026'}), 'Dear Bilal, 01 Dec 2026');
  });

  test('ymd round trip', () {
    expect(ymd(DateTime(2026, 3, 5)), '2026-03-05');
    expect(parseYmd('2026-03-05'), DateTime(2026, 3, 5));
    expect(parseYmd(null), null);
  });

  test('money grouping', () {
    expect(money(1234567), '1,234,567');
    expect(money(999), '999');
  });

  test('fmtDate english and urdu month names', () {
    expect(fmtDate(DateTime(2026, 10, 8), 'en'), 'Thu, 08 Oct 2026');
    expect(fmtDate(DateTime(2026, 10, 8), 'ur', weekday: false), '08 اکتوبر 2026');
  });
}
