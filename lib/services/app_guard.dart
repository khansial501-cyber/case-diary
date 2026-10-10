import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import '../core/gate.dart';
import '../core/providers.dart';
import 'lock_service.dart';
import 'messaging_service.dart';
import 'notification_service.dart';

/// Wraps the whole app: auto-lock, FLAG_SECURE, digest rebuilds, startup scheduling.
class AppGuard extends ConsumerStatefulWidget {
  final Widget child;
  const AppGuard({super.key, required this.child});
  @override
  ConsumerState<AppGuard> createState() => _AppGuardState();
}

class _AppGuardState extends ConsumerState<AppGuard> with WidgetsBindingObserver {
  DateTime? _pausedAt;
  Timer? _idle, _debounce;
  bool? _secure;
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    registerMessagingHooks();
    _resetIdle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idle?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  int get _graceSeconds => int.tryParse(ref.read(settingsProvider).get('autoLockSeconds', '30')) ?? 30;

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (s == AppLifecycleState.resumed) {
      final p = _pausedAt;
      if (p != null && DateTime.now().difference(p).inSeconds >= _graceSeconds) {
        ref.read(lockProvider.notifier).lockNow();
      }
      _pausedAt = null;
      if (ref.read(gateProvider) == Stage.ready) ref.read(notificationServiceProvider).rebuildDigests();
    }
  }

  void _resetIdle() {
    _idle?.cancel();
    _idle = Timer(const Duration(minutes: 5), () => ref.read(lockProvider.notifier).lockNow());
  }

  Future<void> _applySecure(bool on) async {
    if (_secure == on) return;
    _secure = on;
    try {
      if (on) {
        await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
      } else {
        await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataVersionProvider); // makes sure the repo change hook is installed
    ref.listen<int>(dataVersionProvider, (_, __) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 1500), () {
        if (ref.read(gateProvider) == Stage.ready) ref.read(notificationServiceProvider).rebuildDigests();
      });
    });
    ref.listen<Stage>(gateProvider, (_, st) {
      if (st == Stage.ready && !_booted) {
        _booted = true;
        ref.read(notificationServiceProvider).rescheduleAll();
      }
    });
    _applySecure(ref.watch(settingsProvider.select((s) => s.flag('secureScreen', false))));
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetIdle(),
      child: widget.child,
    );
  }
}
