import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../services/license_service.dart';

class LicenseState {
  final bool loading;
  final bool activated; // a correctly signed code for THIS device is stored (even if expired)
  final bool expired;
  final bool lifetime;
  final DateTime? expiry;
  final String deviceId;
  const LicenseState({
    this.loading = true,
    this.activated = false,
    this.expired = false,
    this.lifetime = false,
    this.expiry,
    this.deviceId = '',
  });
}

final licenseServiceProvider = Provider<LicenseService>((ref) => LicenseService(ref.read(secureStorageProvider)));

class LicenseNotifier extends StateNotifier<LicenseState> {
  final LicenseService svc;
  LicenseNotifier(this.svc) : super(const LicenseState()) {
    reload();
  }

  Future<void> reload() async {
    final id = await svc.deviceId();
    final r = await svc.checkStored();
    if (r == null || r.result == LicenseResult.badFormat || r.result == LicenseResult.badSignature) {
      state = LicenseState(loading: false, deviceId: id);
      return;
    }
    state = LicenseState(
      loading: false,
      activated: true,
      expired: r.result == LicenseResult.expired,
      lifetime: r.lifetime,
      expiry: r.expiry,
      deviceId: id,
    );
  }

  Future<LicenseResult> activate(String code) async {
    final r = await svc.activate(code);
    if (r.isValid) await reload();
    return r.result;
  }
}

final licenseProvider =
    StateNotifierProvider<LicenseNotifier, LicenseState>((ref) => LicenseNotifier(ref.read(licenseServiceProvider)));
