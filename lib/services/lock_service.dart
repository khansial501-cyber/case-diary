import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../core/providers.dart';

class LockState {
  final bool loading, enabled, biometric, locked;
  final DateTime? blockedUntil;
  const LockState({this.loading = true, this.enabled = false, this.biometric = false, this.locked = false, this.blockedUntil});
  LockState copy({bool? enabled, bool? biometric, bool? locked, DateTime? blockedUntil, bool clearBlock = false}) =>
      LockState(
        loading: false,
        enabled: enabled ?? this.enabled,
        biometric: biometric ?? this.biometric,
        locked: locked ?? this.locked,
        blockedUntil: clearBlock ? null : (blockedUntil ?? this.blockedUntil),
      );
}

class LockNotifier extends StateNotifier<LockState> {
  final FlutterSecureStorage s;
  final LocalAuthentication _auth = LocalAuthentication();
  int _fails = 0;
  LockNotifier(this.s) : super(const LockState()) {
    _load();
  }

  Future<void> _load() async {
    final h = await s.read(key: 'pin_hash');
    final bio = await s.read(key: 'lock_bio') == '1';
    final en = h != null && h.isNotEmpty;
    state = LockState(loading: false, enabled: en, biometric: bio && en, locked: en);
  }

  Future<String> _hash(String pin, String salt) async {
    final h = await Sha256().hash(utf8.encode('$salt:$pin'));
    return base64Encode(h.bytes);
  }

  Future<void> setPin(String pin) async {
    final r = Random.secure();
    final salt = base64Encode(List<int>.generate(12, (_) => r.nextInt(256)));
    await s.write(key: 'pin_salt', value: salt);
    await s.write(key: 'pin_hash', value: await _hash(pin, salt));
    state = state.copy(enabled: true, locked: false);
  }

  Future<void> removePin() async {
    await s.delete(key: 'pin_hash');
    await s.delete(key: 'pin_salt');
    await s.write(key: 'lock_bio', value: '0');
    state = state.copy(enabled: false, biometric: false, locked: false);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await s.read(key: 'pin_salt') ?? '';
    final h = await s.read(key: 'pin_hash');
    return h != null && h == await _hash(pin, salt);
  }

  Future<bool> unlockWithPin(String pin) async {
    if (state.blockedUntil != null && DateTime.now().isBefore(state.blockedUntil!)) return false;
    if (await verifyPin(pin)) {
      _fails = 0;
      state = state.copy(locked: false, clearBlock: true);
      return true;
    }
    _fails++;
    if (_fails >= 5) {
      _fails = 0;
      state = state.copy(blockedUntil: DateTime.now().add(const Duration(seconds: 30)));
    }
    return false;
  }

  Future<bool> biometricAvailable() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlockWithBiometric(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (ok) state = state.copy(locked: false, clearBlock: true);
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometric(bool v) async {
    await s.write(key: 'lock_bio', value: v ? '1' : '0');
    state = state.copy(biometric: v && state.enabled);
  }

  void lockNow() {
    if (state.enabled && !state.locked) state = state.copy(locked: true);
  }
}

final lockProvider = StateNotifierProvider<LockNotifier, LockState>((ref) => LockNotifier(ref.read(secureStorageProvider)));
