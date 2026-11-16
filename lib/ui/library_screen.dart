import 'package:material_ui/material_ui.dart';

import '../constants.dart';
import 'sheets.dart';
import 'widgets.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String type = 'resistance', q = '', region = '';

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final lib = st.db.library;
    int count(String t) => lib.where((e) => e.type == t).length;
    var list = lib.where((e) => e.type == type).toList();
    final regions = list.expand((e) => e.regions).toSet().toList();
    if (region.isNotEmpty) list = list.where((e) => e.regions.contains(region)).toList();
    if (q.isNotEmpty) list = list.where((e) => e.name.toLowerCase().contains(q.toLowerCase())).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    const types = [('resistance', 'Resistance'), ('cardio', 'Cardio'), ('warmup', 'Warm-up'), ('cooldown', 'Cool-down')];
    final mq = MediaQuery.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, mq.padding.top + 10, 16, mq.padding.bottom + 120),
      children: [
        const PageTitle('Library'),
        Muted('${lib.length} exercises', padding: const EdgeInsets.fromLTRB(2, 0, 2, 10)),
        SegCtl<String>(
          items: [for (final (k, l) in types) (k, '$l ${count(k)}')],
          value: type,
          onTap: (k) => setState(() {
            type = k;
            region = '';
          }),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              decoration: fieldDeco(hint: 'Search').copyWith(prefixIcon: const Icon(Icons.search, color: AppColors.muted)),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
          const SizedBox(width: 10),
          AppDropdown<String>(
            value: regions.contains(region) ? region : '',
            items: [('', 'All regions'), for (final r in regions) (r, kRegionLabel[r] ?? r)],
            onChanged: (v) => setState(() => region = v ?? ''),
          ),
        ]),
        const SizedBox(height: 12),
        Pill('Add exercise', icon: Icons.add, kind: PillKind.primary, block: true, onTap: () => openLibForm(context, null, type: type)),
        const SizedBox(height: 6),
        GlassSection(children: [
          if (list.isEmpty) const Muted('Nothing here yet.'),
          for (var i = 0; i < list.length; i++)
            ExRow(
              first: i == 0,
              e: list[i],
              onInfo: () => openInfo(context, list[i].id),
              action: RoundIconButton(Icons.edit_outlined, tooltip: 'Edit', onTap: () => openLibForm(context, list[i].id)),
            ),
        ]),
      ],
    );
  }
}
