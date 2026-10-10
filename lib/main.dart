import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app.dart';
import 'core/providers.dart';
import 'data/db.dart';
import 'data/repo.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('en');
    await initializeDateFormatting('ur');
    const storage = FlutterSecureStorage();
    final db = await AppDatabase.open(storage);
    final repo = Repo(db);
    final settings = await repo.loadSettings();
    await NotificationService.instance.init();
    await initFirebaseIfConfigured();
    runApp(ProviderScope(
      overrides: [
        repoProvider.overrideWithValue(repo),
        initialSettingsProvider.overrideWithValue(settings),
      ],
      child: const CaseDiaryApp(),
    ));
  } catch (e, st) {
    debugPrint('Startup error: $e\n$st');
    runApp(MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.red),
              const SizedBox(height: 16),
              const Text('The app could not open its database.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text('$e', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ),
      ),
    ));
  }
}
