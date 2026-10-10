import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../shared/widgets.dart';

class _FilterBar extends ConsumerWidget {
  final StateProvider<CaseFilter> provider;
  const _FilterBar(this.provider);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final lb = ref.watch(labelsProvider);
    final f = ref.watch(provider);
    final custom = ref.watch(customRolesProvider).valueOrNull ?? const [];
    final cats = ref.watch(customCategoriesProvider).valueOrNull ?? const [];
    final catList = [...builtInCategories.map((e) => e.en), ...cats.map((e) => e.label)];
    final roleList = [...builtInRoles.map((e) => e.en), ...custom.map((e) => e.label)];
    void upd(CaseFilter n) => ref.read(provider.notifier).state = n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(children: [
        TextField(
          decoration: dec(context, l('search'), prefix: const Icon(Icons.search)),
          onChanged: (v) => upd(f.copy(q: v)),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: f.category,
              decoration: dec(context, l('category')),
              items: [
                DropdownMenuItem(value: '', child: Text(l('all'))),
                ...catList.map((c) => DropdownMenuItem(value: c, child: Text(lb.cat(c), overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => upd(f.copy(category: v ?? '')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: f.role,
              decoration: dec(context, l('iRepresent')),
              items: [
                DropdownMenuItem(value: '', child: Text(l('all'))),
                ...roleList.map((c) => DropdownMenuItem(value: c, child: Text(lb.role(c), overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => upd(f.copy(role: v ?? '')),
            ),
          ),
        ]),
      ]),
    );
  }
}

Widget _listBody(BuildContext context, AsyncValue<List<CaseModel>> a, IconData icon, String empty,
    {Widget Function(CaseModel)? builder}) {
  return a.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => Center(child: Text('$e')),
    data: (list) => list.isEmpty
        ? EmptyState(icon: icon, text: empty)
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => builder != null ? builder(list[i]) : CaseCard(list[i]),
          ),
  );
}

class CasesPage extends ConsumerWidget {
  const CasesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final a = ref.watch(ongoingCasesProvider);
    return Column(children: [
      _FilterBar(casesFilterProvider),
      Expanded(child: _listBody(context, a, Icons.folder_open, l('noCases'))),
    ]);
  }
}

class PriorityPage extends ConsumerWidget {
  const PriorityPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    return _listBody(context, ref.watch(priorityCasesProvider), Icons.star_border_rounded, l('noPriority'));
  }
}

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final a = ref.watch(decidedCasesProvider);
    return Column(children: [
      _FilterBar(historyFilterProvider),
      Expanded(
        child: _listBody(context, a, Icons.history, l('noHistory'), builder: (c) {
          return AppCard(
            onTap: () => context.push('/case/${c.id}'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 4),
              Text('${ref.read(labelsProvider).cat(c.caseCategory)}  |  ${c.courtName ?? ''}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12.5)),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.check_circle, size: 16, color: kGold),
                const SizedBox(width: 6),
                Text('${l('decidedOn')}: ${l.ymdDate(c.decidedDate)}'),
              ]),
              if ((c.outcomeNote ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(c.outcomeNote!, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ]),
          );
        }),
      ),
    ]);
  }
}
