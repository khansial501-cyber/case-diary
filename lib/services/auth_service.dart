import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/config.dart';
import '../core/providers.dart';

class AuthState {
  final bool loading, loggedIn;
  final String email;
  const AuthState({this.loading = true, this.loggedIn = false, this.email = ''});
}

bool get firebaseReady => firebaseConfigured && Firebase.apps.isNotEmpty;

/// Accounts: Firebase Auth when configured (online first login, reset by email),
/// otherwise / additionally a salted local credential so the app works offline.
class AuthNotifier extends StateNotifier<AuthState> {
  final FlutterSecureStorage s;
  AuthNotifier(this.s) : super(const AuthState()) {
    _load();
  }

  Future<void> _load() async {
    final session = await s.read(key: 'auth_session');
    final email = await s.read(key: 'auth_email') ?? '';
    state = AuthState(loading: false, loggedIn: session == '1', email: email);
  }

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<String> _hash(String pw, String salt) async {
    final algo = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 20000, bits: 256);
    final k = await algo.deriveKeyFromPassword(password: pw, nonce: base64Decode(salt));
    return base64Encode(await k.extractBytes());
  }

  Future<void> _storeLocal(String email, String pw) async {
    final r = Random.secure();
    final salt = base64Encode(List<int>.generate(16, (_) => r.nextInt(256)));
    await s.write(key: 'acct_email', value: email);
    await s.write(key: 'acct_salt', value: salt);
    await s.write(key: 'acct_hash', value: await _hash(pw, salt));
  }

  Future<void> _session(String email) async {
    await s.write(key: 'auth_session', value: '1');
    await s.write(key: 'auth_email', value: email);
    state = AuthState(loading: false, loggedIn: true, email: email);
  }

  /// Every method returns null on success, or a language key describing the error.
  Future<String?> register(String email, String pw) async {
    email = email.trim().toLowerCase();
    if (!_emailRe.hasMatch(email)) return 'errInvalidEmail';
    if (pw.length < 6) return 'errWeakPassword';
    try {
      if (firebaseReady) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pw);
      }
      await _storeLocal(email, pw);
      await _session(email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _fbError(e);
    } catch (_) {
      return 'errGeneric';
    }
  }

  Future<String?> login(String email, String pw) async {
    email = email.trim().toLowerCase();
    if (!_emailRe.hasMatch(email)) return 'errInvalidEmail';
    try {
      final localEmail = await s.read(key: 'acct_email');
      if (localEmail == email) {
        // Works offline: compare against the stored salted hash.
        final salt = await s.read(key: 'acct_salt') ?? '';
        final h = await s.read(key: 'acct_hash');
        if (salt.isNotEmpty && h == await _hash(pw, salt)) {
          await _session(email);
          return null;
        }
        if (!firebaseReady) return 'errWrongCredentials';
      } else if (!firebaseReady) {
        return 'errNoAccount';
      }
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pw);
      await _storeLocal(email, pw);
      await _session(email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _fbError(e);
    } catch (_) {
      return 'errGeneric';
    }
  }

  Future<String?> sendReset(String email) async {
    email = email.trim().toLowerCase();
    if (!_emailRe.hasMatch(email)) return 'errInvalidEmail';
    if (!firebaseReady) return 'errResetNeedsFirebase';
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _fbError(e);
    } catch (_) {
      return 'errGeneric';
    }
  }

  /// Offline fallback: reset the local password after confirming the registered phone number.
  Future<String?> resetLocal(String email, String phoneOnFile, String phoneEntered, String newPw) async {
    email = email.trim().toLowerCase();
    final localEmail = await s.read(key: 'acct_email');
    if (localEmail != email) return 'errNoAccount';
    String d(String x) => x.replaceAll(RegExp(r'[^0-9]'), '');
    if (d(phoneOnFile).isEmpty || d(phoneOnFile) != d(phoneEntered)) return 'errPhoneMismatch';
    if (newPw.length < 6) return 'errWeakPassword';
    await _storeLocal(email, newPw);
    return null;
  }

  Future<void> logout() async {
    await s.write(key: 'auth_session', value: '0');
    if (firebaseReady) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
    state = AuthState(loading: false, loggedIn: false, email: state.email);
  }

  String _fbError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'errInvalidEmail';
      case 'weak-password':
        return 'errWeakPassword';
      case 'email-already-in-use':
        return 'errExists';
      case 'user-not-found':
        return 'errNoAccount';
      case 'wrong-password':
      case 'invalid-credential':
        return 'errWrongCredentials';
      case 'network-request-failed':
        return 'errNetwork';
      default:
        return 'errGeneric';
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref.read(secureStorageProvider)));
