import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/license/license_state.dart';
import '../services/auth_service.dart';
import '../services/lock_service.dart';
import 'providers.dart';

enum Stage { loading, activate, setup, login, locked, ready }

/// Single source of truth for "which screen family may the user see right now".
final gateProvider = Provider<Stage>((ref) {
  final lic = ref.watch(licenseProvider);
  final firm = ref.watch(settingsProvider.select((s) => s.firmName));
  final auth = ref.watch(authProvider);
  final lock = ref.watch(lockProvider);
  if (lic.loading || auth.loading || lock.loading) return Stage.loading;
  if (!lic.activated) return Stage.activate;
  if (firm.trim().isEmpty) return Stage.setup;
  if (!auth.loggedIn) return Stage.login;
  if (lock.locked) return Stage.locked;
  return Stage.ready;
});
