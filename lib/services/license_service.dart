import 'dart:convert';
import 'package:android_id/android_id.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/config.dart';

enum LicenseResult { valid, expired, badFormat, badSignature }

class LicenseCheck {
  final LicenseResult result;
  final DateTime? expiry; // null = lifetime
  final bool lifetime;
  const LicenseCheck(this.result, {this.expiry, this.lifetime = false});
  bool get isValid => result == LicenseResult.valid;
}

List<int> hexToBytes(String hex) {
  final h = hex.trim();
  if (h.length % 2 != 0) throw const FormatException('odd hex');
  return [for (var i = 0; i < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)];
}

/// Pure, offline Ed25519 verification of "YYYYMMDD-<128 hex>" codes.
class LicenseVerifier {
  final String publicKeyHex;
  const LicenseVerifier(this.publicKeyHex);

  static final _re = RegExp(r'^(\d{8})-([0-9a-fA-F]{128})$');

  Future<LicenseCheck> verify(String code, String deviceId, {DateTime? now}) async {
    final m = _re.firstMatch(code.trim());
    if (m == null) return const LicenseCheck(LicenseResult.badFormat);
    final exp = m.group(1)!;
    final sigHex = m.group(2)!;
    final msg = utf8.encode('${deviceId.trim().toLowerCase()}|$exp');
    bool ok;
    try {
      ok = await Ed25519().verify(
        msg,
        signature: Signature(
          hexToBytes(sigHex),
          publicKey: SimplePublicKey(hexToBytes(publicKeyHex), type: KeyPairType.ed25519),
        ),
      );
    } catch (_) {
      ok = false;
    }
    if (!ok) return const LicenseCheck(LicenseResult.badSignature);
    if (exp == '99991231') return const LicenseCheck(LicenseResult.valid, lifetime: true);
    final y = int.parse(exp.substring(0, 4)), mo = int.parse(exp.substring(4, 6)), d = int.parse(exp.substring(6, 8));
    final date = DateTime(y, mo, d);
    if (date.year != y || date.month != mo || date.day != d) return const LicenseCheck(LicenseResult.badFormat);
    final endOfDay = DateTime(y, mo, d, 23, 59, 59);
    final n = now ?? DateTime.now();
    if (n.isAfter(endOfDay)) return LicenseCheck(LicenseResult.expired, expiry: date);
    return LicenseCheck(LicenseResult.valid, expiry: date);
  }
}

class LicenseService {
  final FlutterSecureStorage storage;
  final LicenseVerifier verifier;
  LicenseService(this.storage, {LicenseVerifier? verifier}) : verifier = verifier ?? const LicenseVerifier(kPublicKeyHex);

  Future<String> deviceId() async {
    String? id;
    try {
      id = await const AndroidId().getId();
    } catch (_) {}
    return (id ?? 'unknown-device').trim().toLowerCase();
  }

  /// Latest date ever seen on this phone: stops people extending a licence by rolling the clock back.
  Future<DateTime> _effectiveNow() async {
    final now = DateTime.now();
    final raw = await storage.read(key: 'lic_last_seen');
    var eff = now;
    if (raw != null) {
      final prev = DateTime.tryParse(raw);
      if (prev != null && prev.isAfter(now)) eff = prev;
    }
    await storage.write(key: 'lic_last_seen', value: eff.toIso8601String());
    return eff;
  }

  Future<String?> storedCode() => storage.read(key: 'license_code');

  /// Re-verifies the stored code (called on every launch). Returns null if none stored.
  Future<LicenseCheck?> checkStored() async {
    final code = await storedCode();
    if (code == null || code.isEmpty) return null;
    return verifier.verify(code, await deviceId(), now: await _effectiveNow());
  }

  /// Verifies and stores a new code. Only VALID codes are stored.
  Future<LicenseCheck> activate(String code) async {
    final r = await verifier.verify(code, await deviceId(), now: await _effectiveNow());
    if (r.isValid) await storage.write(key: 'license_code', value: code.trim());
    return r;
  }
}
