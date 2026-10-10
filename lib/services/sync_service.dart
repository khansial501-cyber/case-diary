import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config.dart';
import '../core/providers.dart';
import '../data/db.dart';
import 'auth_service.dart';

Future<void> initFirebaseIfConfigured() async {
  if (!firebaseConfigured) return;
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: kFirebaseApiKey,
        appId: kFirebaseAppId,
        messagingSenderId: kFirebaseMessagingSenderId,
        projectId: kFirebaseProjectId,
      ),
    );
  } catch (_) {}
}

/// Optional cloud sync of all text data (cases, hearings, clients ...). Attached files stay on the phone
/// (use encrypted backups for those). Conflict rule: the row with the newer updatedAt wins.
class SyncService {
  final Ref ref;
  bool _busy = false;
  SyncService(this.ref);

  /// Returns null on success or a language key.
  Future<String?> syncNow() async {
    if (!firebaseReady) return 'errSyncNotConfigured';
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'errSyncSignIn';
    if (_busy) return null;
    final net = await Connectivity().checkConnectivity();
    if (net.contains(ConnectivityResult.none) && net.length == 1) return 'errNetwork';
    _busy = true;
    try {
      final repo = ref.read(repoProvider);
      final fs = FirebaseFirestore.instance;
      final base = fs.collection('users').doc(user.uid);
      final settings = ref.read(settingsProvider);
      final lastPull = int.tryParse(settings.get('syncLastPull', '0')) ?? 0;
      var maxPull = lastPull;
      for (final t in syncTables) {
        // push
        final rows = await repo.changedRows(t, 0);
        for (var i = 0; i < rows.length; i += 400) {
          final chunk = rows.sublist(i, i + 400 > rows.length ? rows.length : i + 400);
          final batch = fs.batch();
          for (final r in chunk) {
            batch.set(base.collection(t).doc(r['id'] as String), Map<String, Object?>.from(r)..remove('syncedAt'));
          }
          await batch.commit();
          await repo.markSynced(t, chunk.map((e) => e['id'] as String).toList(), DateTime.now().millisecondsSinceEpoch);
        }
        // pull
        final snap = await base.collection(t).where('updatedAt', isGreaterThan: lastPull).get();
        for (final d in snap.docs) {
          final m = Map<String, Object?>.from(d.data());
          m['id'] = d.id;
          final up = (m['updatedAt'] as num?)?.toInt() ?? 0;
          if (up > maxPull) maxPull = up;
          await repo.upsertRemote(t, m, DateTime.now().millisecondsSinceEpoch);
        }
      }
      await ref.read(settingsProvider.notifier).setMany({'syncLastPull': '$maxPull', 'lastSync': '${DateTime.now().millisecondsSinceEpoch}'});
      repo.notifyChanged();
      return null;
    } on FirebaseException catch (_) {
      return 'errSyncFailed';
    } catch (_) {
      return 'errSyncFailed';
    } finally {
      _busy = false;
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) => SyncService(ref));
