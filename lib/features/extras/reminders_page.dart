import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../services/notification_service.dart';
import '../shared/widgets.dart';

class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    ref.watch(dataVersionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l('reminders'))),
      body: FutureBuilder<List<ReminderModel>>(
        future: ref.read(repoProvider).reminders(),
        builder: (ctx, snap) {
          final all = snap.data ?? const [];
          final upcoming = all.where((r) => !r.isDone && r.when.isAfter(DateTime.now())).toList();
          if (upcoming.isEmpty) return EmptyState(icon: Icons.alarm_off, text: l('noReminders'));
          return ListView(padding: const EdgeInsets.all(16), children: [
            for (final r in upcoming)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => context.push('/case/${r.caseId}'),
                  child: Row(children: [
                    const Icon(Icons.alarm, color: kGold),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(fmtDateTime(r.when, l.lang), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(r.caseTitle ?? '', style: const TextStyle(fontSize: 13)),
                      Text(r.message, style: const TextStyle(fontSize: 12.5)),
                    ])),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        await ref.read(notificationServiceProvider).cancelReminder(r.notificationId);
                        await ref.read(repoProvider).deleteReminder(r.id);
                      },
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
