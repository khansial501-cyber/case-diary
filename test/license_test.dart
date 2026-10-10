import 'dart:convert';
import 'package:case_diary/core/config.dart';
import 'package:case_diary/services/license_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

String _hex(List<int> b) => b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

void main() {
  late LicenseVerifier verifier;
  late SimpleKeyPair kp;

  Future<String> sign(String device, String exp) async {
    final sig = await Ed25519().sign(utf8.encode('${device.toLowerCase()}|$exp'), keyPair: kp);
    return '$exp-${_hex(sig.bytes)}';
  }

  setUp(() async {
    kp = await Ed25519().newKeyPair();
    final pub = await kp.extractPublicKey();
    verifier = LicenseVerifier(_hex(pub.bytes));
  });

  test('valid lifetime code', () async {
    final r = await verifier.verify(await sign('abc123def456', '99991231'), 'abc123def456');
    expect(r.result, LicenseResult.valid);
    expect(r.lifetime, true);
  });

  test('valid dated code, and device id is case/space tolerant', () async {
    final code = await sign('abc123def456', '20301231');
    final r = await verifier.verify(code, '  ABC123DEF456 ', now: DateTime(2026, 10, 8));
    expect(r.result, LicenseResult.valid);
    expect(r.expiry, DateTime(2030, 12, 31));
  });

  test('expired code is reported as expired', () async {
    final code = await sign('abc123def456', '20250101');
    final r = await verifier.verify(code, 'abc123def456', now: DateTime(2026, 10, 8));
    expect(r.result, LicenseResult.expired);
  });

  test('expiry day itself is still valid until 23:59:59', () async {
    final code = await sign('abc123def456', '20261008');
    final r = await verifier.verify(code, 'abc123def456', now: DateTime(2026, 10, 8, 23, 0));
    expect(r.result, LicenseResult.valid);
  });

  test('code for another device is rejected', () async {
    final code = await sign('device-one', '99991231');
    final r = await verifier.verify(code, 'device-two');
    expect(r.result, LicenseResult.badSignature);
  });

  test('tampered expiry date is rejected', () async {
    final code = await sign('abc123def456', '20260101');
    final tampered = '20991231' + code.substring(8);
    final r = await verifier.verify(tampered, 'abc123def456');
    expect(r.result, LicenseResult.badSignature);
  });

  test('garbage is rejected as bad format', () async {
    expect((await verifier.verify('hello', 'x')).result, LicenseResult.badFormat);
    expect((await verifier.verify('', 'x')).result, LicenseResult.badFormat);
  });

  test('code from Key_Generator.html verifies with the public key in config.dart', () async {
    const real = LicenseVerifier(kPublicKeyHex);
    final r = await real.verify('99991231-3f349a429a9d214f7ee3ae1c1d2aba3e06f27ee1a9453c1ddfd3d7bf16359255e08249008a5666c13c7ff714a8754b37dc2289c3dd2e60f59847f9f6cc6f3502', '9f3c2a7d41b8e605');
    expect(r.result, LicenseResult.valid);
    expect(r.lifetime, true);
    final wrong = await real.verify('99991231-3f349a429a9d214f7ee3ae1c1d2aba3e06f27ee1a9453c1ddfd3d7bf16359255e08249008a5666c13c7ff714a8754b37dc2289c3dd2e60f59847f9f6cc6f3502', '0000000000000000');
    expect(wrong.result, LicenseResult.badSignature);
  });
}
