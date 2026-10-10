import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/models.dart';
import '../data/repo.dart';
import 'roles.dart';
import 'strings.dart';
import 'utils.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((_) => const FlutterSecureStorage());

/// Overridden in main() once the encrypted database is open.
final repoProvider = Provider<Repo>((_) => throw UnimplementedError('repoProvider not overridden'));

/// Bumped on every database write; providers watch it to refresh.
class VersionNotifier extends StateNotifier<int> {
  VersionNotifier() : super(0);
  void bump() => state = state + 1;
}

final dataVersionProvider = StateNotifierProvider<VersionNotifier, int>((ref) {
  final n = VersionNotifier();
  ref.read(repoProvider).onChange = n.bump;
  return n;
});

// ---------------- settings ----------------
class AppSettings {
  final Map<String, String> m;
  const AppSettings(this.m);
  String get(String k, [String d = '']) => m[k] ?? d;
  bool flag(String k, [bool d = false]) => m.containsKey(k) ? m[k] == '1' : d;
  String get lang => get('lang', 'en');
  bool get isUr => lang == 'ur';
  String get theme => get('theme', 'system');
  String get firmName => get('firmName');
  String get lawyerName => get('lawyerName');
  String get phone => get('phone');
  String get email => get('email');
  String get address => get('address');
  String get barNo => get('barNo');
  String get logoPath => get('logoPath');
  String get countryCode => get('countryCode', '92');
  String get receiptSize => get('receiptSize', '58');
  bool get showRolesOnReceipt => flag('showRolesOnReceipt', true);
  bool get readOnlyRole => get('role', 'owner') == 'assistant';
  ThemeMode get themeMode =>
      theme == 'dark' ? ThemeMode.dark : (theme == 'light' ? ThemeMode.light : ThemeMode.system);
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  final Repo repo;
  SettingsNotifier(this.repo, Map<String, String> initial) : super(AppSettings(initial));
  Future<void> set(String k, String v) async {
    await repo.setSetting(k, v);
    state = AppSettings({...state.m, k: v});
  }

  Future<void> setMany(Map<String, String> kv) async {
    for (final e in kv.entries) {
      await repo.setSetting(e.key, e.value);
    }
    state = AppSettings({...state.m, ...kv});
  }
}

final initialSettingsProvider = Provider<Map<String, String>>((_) => {});
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
    (ref) => SettingsNotifier(ref.read(repoProvider), ref.read(initialSettingsProvider)));

// ---------------- localisation ----------------
class L10n {
  final String lang;
  const L10n(this.lang);
  bool get isUr => lang == 'ur';
  String call(String key) => (isUr ? urStrings[key] : null) ?? enStrings[key] ?? key;
  String f(String key, Map<String, String> vars) => fillTemplate(call(key), vars);
  String date(DateTime? d, {bool weekday = true}) => fmtDate(d, lang, weekday: weekday);
  String ymdDate(String? s, {bool weekday = false}) => fmtYmd(s, lang, weekday: weekday);
}

final l10nProvider = Provider<L10n>((ref) => L10n(ref.watch(settingsProvider.select((s) => s.lang))));

// ---------------- custom roles / categories ----------------
final customRolesProvider = FutureProvider<List<CustomRole>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.read(repoProvider).customRoles();
});

final customCategoriesProvider = FutureProvider<List<CustomCategory>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.read(repoProvider).customCategories();
});

/// English label -> Urdu label for custom roles.
final roleMapProvider = Provider<Map<String, String>>((ref) {
  final l = ref.watch(customRolesProvider).valueOrNull ?? const [];
  return {for (final r in l) r.label: r.labelUr};
});

final categoryMapProvider = Provider<Map<String, String>>((ref) {
  final l = ref.watch(customCategoriesProvider).valueOrNull ?? const [];
  return {for (final r in l) r.label: r.labelUr};
});

/// Helper bundle so widgets can label roles/categories in the current language.
class Labels {
  final String lang;
  final Map<String, String> roles, cats;
  Labels(this.lang, this.roles, this.cats);
  String role(String r) => roleLabel(r, lang, roles);
  String cat(String c) => categoryLabel(c, lang, cats);
}

final labelsProvider = Provider<Labels>((ref) =>
    Labels(ref.watch(l10nProvider).lang, ref.watch(roleMapProvider), ref.watch(categoryMapProvider)));

// ---------------- home / lists ----------------
final selectedDateProvider = StateProvider<DateTime>((_) => today());
final lawyerFilterProvider = StateProvider<String>((_) => '');

final dayCasesProvider = FutureProvider.autoDispose<List<CaseModel>>((ref) {
  ref.watch(dataVersionProvider);
  final d = ref.watch(selectedDateProvider);
  final lw = ref.watch(lawyerFilterProvider);
  return ref.read(repoProvider).casesOn(ymd(d), lawyerId: lw);
});

final dayCountProvider = FutureProvider.autoDispose.family<int, String>((ref, date) {
  ref.watch(dataVersionProvider);
  return ref.read(repoProvider).countOn(date, lawyerId: ref.watch(lawyerFilterProvider));
});

final overdueProvider = FutureProvider.autoDispose<List<CaseModel>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.read(repoProvider).overdue(ymd(today()), lawyerId: ref.watch(lawyerFilterProvider));
});

final countsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.read(repoProvider).counts();
});

final casesFilterProvider = StateProvider<CaseFilter>((_) => const CaseFilter());
final historyFilterProvider = StateProvider<CaseFilter>((_) => const CaseFilter());

final ongoingCasesProvider = FutureProvider.autoDispose<List<CaseModel>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.read(repoProvider).ongoing(ref.watch(casesFilterProvider));
});

final priorityCasesProvider = FutureProvider.autoDispose<List<CaseModel>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.read(repoProvider).priority();
});

final decidedCasesProvider = FutureProvider.autoDispose<List<CaseModel>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.read(repoProvider).decided(ref.watch(historyFilterProvider));
});

final caseProvider = FutureProvider.autoDispose.family<CaseModel?, String>((ref, id) {
  ref.watch(dataVersionProvider);
  return ref.read(repoProvider).getCase(id);
});

final hearingsProvider = FutureProvider.autoDispose.family<List<HearingModel>, String>((ref, id) {
  ref.watch(dataVersionProvider);
  return ref.read(repoProvider).hearings(id);
});

final lawyersProvider = FutureProvider.autoDispose<List<LawyerModel>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.read(repoProvider).lawyers();
});
