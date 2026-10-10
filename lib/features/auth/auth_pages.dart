import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/lock_service.dart';
import '../shared/widgets.dart';

Widget _authScaffold(BuildContext context, String title, List<Widget> children) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(22), children: children)),
    );

ButtonStyle _bigBtn() => FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)));

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginPage> {
  final email = TextEditingController(), pw = TextEditingController();
  bool busy = false, hide = true;
  String? err;

  @override
  void initState() {
    super.initState();
    email.text = ref.read(authProvider).email;
  }

  Future<void> _go() async {
    setState(() {
      busy = true;
      err = null;
    });
    final e = await ref.read(authProvider.notifier).login(email.text, pw.text);
    if (mounted) setState(() {
      busy = false;
      err = e;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    return _authScaffold(context, l('login'), [
      const SizedBox(height: 10),
      const Icon(Icons.balance, size: 56, color: kGold),
      const SizedBox(height: 8),
      Text(ref.watch(settingsProvider).firmName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 24),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: dec(context, l('email'), prefix: const Icon(Icons.mail_outline))),
      const SizedBox(height: 14),
      TextField(
        controller: pw,
        obscureText: hide,
        decoration: dec(context, l('password'),
            prefix: const Icon(Icons.lock_outline),
            suffix: IconButton(icon: Icon(hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hide = !hide))),
      ),
      if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(l(err!), style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 18),
      FilledButton(style: _bigBtn(), onPressed: busy ? null : _go, child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l('login'))),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        TextButton(onPressed: () => context.push('/forgot'), child: Text(l('forgotPassword'))),
        TextButton(onPressed: () => context.push('/register'), child: Text(l('createAccount'))),
      ]),
    ]);
  }
}

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});
  @override
  ConsumerState<RegisterPage> createState() => _RegisterState();
}

class _RegisterState extends ConsumerState<RegisterPage> {
  final email = TextEditingController(), pw = TextEditingController(), pw2 = TextEditingController();
  bool busy = false;
  String? err;

  Future<void> _go() async {
    if (pw.text != pw2.text) {
      setState(() => err = 'errPasswordMismatch');
      return;
    }
    setState(() {
      busy = true;
      err = null;
    });
    final e = await ref.read(authProvider.notifier).register(email.text, pw.text);
    if (mounted) setState(() {
      busy = false;
      err = e;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    return _authScaffold(context, l('createAccount'), [
      Text(firebaseReady ? l('registerOnlineHint') : l('registerLocalHint')),
      const SizedBox(height: 16),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: dec(context, l('email'), prefix: const Icon(Icons.mail_outline))),
      const SizedBox(height: 14),
      TextField(controller: pw, obscureText: true, decoration: dec(context, l('password'), prefix: const Icon(Icons.lock_outline))),
      const SizedBox(height: 14),
      TextField(controller: pw2, obscureText: true, decoration: dec(context, l('confirmPassword'), prefix: const Icon(Icons.lock_outline))),
      if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(l(err!), style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 18),
      FilledButton(style: _bigBtn(), onPressed: busy ? null : _go, child: Text(l('createAccount'))),
    ]);
  }
}

class ForgotPage extends ConsumerStatefulWidget {
  const ForgotPage({super.key});
  @override
  ConsumerState<ForgotPage> createState() => _ForgotState();
}

class _ForgotState extends ConsumerState<ForgotPage> {
  final email = TextEditingController(), phone = TextEditingController(), pw = TextEditingController();
  String? err, ok;
  bool busy = false;

  Future<void> _go() async {
    setState(() {
      busy = true;
      err = null;
      ok = null;
    });
    final a = ref.read(authProvider.notifier);
    String? e;
    if (firebaseReady) {
      e = await a.sendReset(email.text);
      if (e == null) ok = 'resetEmailSent';
    } else {
      e = await a.resetLocal(email.text, ref.read(settingsProvider).phone, phone.text, pw.text);
      if (e == null) ok = 'passwordReset';
    }
    if (mounted) setState(() {
      busy = false;
      err = e;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    return _authScaffold(context, l('forgotPassword'), [
      Text(firebaseReady ? l('resetOnlineHint') : l('resetLocalHint')),
      const SizedBox(height: 16),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: dec(context, l('email'), prefix: const Icon(Icons.mail_outline))),
      if (!firebaseReady) ...[
        const SizedBox(height: 14),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: dec(context, l('registeredPhone'), prefix: const Icon(Icons.phone))),
        const SizedBox(height: 14),
        TextField(controller: pw, obscureText: true, decoration: dec(context, l('newPassword'), prefix: const Icon(Icons.lock_outline))),
      ],
      if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(l(err!), style: const TextStyle(color: Colors.red))),
      if (ok != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(l(ok!), style: const TextStyle(color: Colors.green))),
      const SizedBox(height: 18),
      FilledButton(style: _bigBtn(), onPressed: busy ? null : _go, child: Text(firebaseReady ? l('sendResetEmail') : l('resetPassword'))),
    ]);
  }
}

/// App lock screen: PIN + optional biometric.
class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key});
  @override
  ConsumerState<LockPage> createState() => _LockState();
}

class _LockState extends ConsumerState<LockPage> {
  String pin = '';
  bool wrong = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
  }

  Future<void> _bio() async {
    final st = ref.read(lockProvider);
    if (st.biometric) {
      await ref.read(lockProvider.notifier).unlockWithBiometric(ref.read(l10nProvider)('unlockReason'));
    }
  }

  Future<void> _tap(String d) async {
    if (pin.length >= 6) return;
    HapticFeedback.selectionClick();
    setState(() {
      pin += d;
      wrong = false;
    });
    if (pin.length >= 4) {
      final ok = await ref.read(lockProvider.notifier).unlockWithPin(pin);
      if (!ok && pin.length == 6 && mounted) {
        setState(() {
          wrong = true;
          pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final st = ref.watch(lockProvider);
    final blocked = st.blockedUntil != null && DateTime.now().isBefore(st.blockedUntil!);
    Widget key(String d) => SizedBox(
        width: 78,
        height: 62,
        child: TextButton(onPressed: blocked ? null : () => _tap(d), child: Text(d, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600))));
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock, size: 48, color: kGold),
              const SizedBox(height: 12),
              Text(l('enterPin'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < 6; i++)
                  Container(
                    margin: const EdgeInsets.all(6),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < pin.length ? kGold : Colors.transparent,
                        border: Border.all(color: kGold)),
                  ),
              ]),
              SizedBox(
                  height: 28,
                  child: wrong
                      ? Text(l('wrongPin'), style: const TextStyle(color: Colors.red))
                      : (blocked ? Text(l('tooManyTries'), style: const TextStyle(color: Colors.red)) : null)),
              for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']]) Row(mainAxisSize: MainAxisSize.min, children: row.map(key).toList()),
              Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                    width: 78,
                    height: 62,
                    child: st.biometric ? IconButton(icon: const Icon(Icons.fingerprint, size: 30), onPressed: _bio) : null),
                key('0'),
                SizedBox(
                    width: 78,
                    height: 62,
                    child: IconButton(icon: const Icon(Icons.backspace_outlined), onPressed: () => setState(() => pin = pin.isEmpty ? '' : pin.substring(0, pin.length - 1)))),
              ]),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  if (await confirm(context, l('logoutConfirm'))) {
                    await ref.read(lockProvider.notifier).removePin();
                    await ref.read(authProvider.notifier).logout();
                  }
                },
                child: Text(l('forgotPin')),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
