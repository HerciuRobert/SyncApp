import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../constants.dart';
import '../models.dart';
import '../timeline.dart';
import 'widgets.dart';

/// Standard bottom sheet: grab handle, sticky title row (back / close), scrollable body.
Future<T?> showAppSheet<T>(BuildContext context,
    {required String title, required WidgetBuilder builder, bool back = false, bool scroll = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.sheet,
    barrierColor: Colors.black.withValues(alpha: .55),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      side: BorderSide(color: AppColors.line),
    ),
    constraints: const BoxConstraints(maxWidth: 620),
    builder: (ctx) {
      final mq = MediaQuery.of(ctx);
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * .88),
        child: Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(color: const Color(0xFF4A504D), borderRadius: BorderRadius.circular(3))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Row(children: [
                if (back) ...[RoundIconButton(Icons.chevron_left, onTap: () => Navigator.pop(ctx), tooltip: 'Back'), const SizedBox(width: 8)],
                Expanded(child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300))),
                RoundIconButton(Icons.close, onTap: () => Navigator.of(ctx).popUntil((r) => r is! ModalBottomSheetRoute), tooltip: 'Close'),
              ]),
            ),
            Flexible(
              child: scroll
                  ? SingleChildScrollView(padding: EdgeInsets.fromLTRB(18, 0, 18, mq.padding.bottom + 24), child: builder(ctx))
                  : Padding(padding: EdgeInsets.fromLTRB(18, 0, 18, mq.padding.bottom + 8), child: builder(ctx)),
            ),
          ]),
        ),
      );
    },
  );
}

/// In-app confirmation sheet. Resolves to true when the user confirms.
Future<bool> askSheet(BuildContext context, String title, String msg, String yes, {bool danger = false}) async {
  final r = await showAppSheet<bool>(context,
      title: title,
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (msg.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(msg, style: const TextStyle(fontSize: 16, height: 1.4))),
            Pill(yes, kind: danger ? PillKind.danger : PillKind.primary, block: true, onTap: () => Navigator.pop(ctx, true)),
            const SizedBox(height: 8),
            Pill('Cancel', block: true, onTap: () => Navigator.pop(ctx, false)),
          ]));
  return r == true;
}

/// Text-entry sheet (name a workout, set week number ...).
Future<String?> nameSheet(BuildContext context, String title, String initial, String okLabel,
    {String label = 'Name', TextInputType? keyboard, int maxLength = 60}) {
  final c = TextEditingController(text: initial)..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  return showAppSheet<String>(context,
      title: title,
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Muted(label)),
            TextField(
              controller: c,
              autofocus: true,
              maxLength: maxLength,
              keyboardType: keyboard,
              style: const TextStyle(fontSize: 17),
              decoration: fieldDeco().copyWith(counterText: ''),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
            const SizedBox(height: 10),
            Pill(okLabel, kind: PillKind.primary, block: true, onTap: () => Navigator.pop(ctx, c.text)),
          ]));
}

// ================= exercise info =================
Widget _p(String label, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        TextSpan(text: text),
      ]), style: const TextStyle(fontSize: 15, height: 1.45)),
    );

Future<void> openInfo(BuildContext context, String id, {bool edit = true, bool back = false}) {
  final st = AppScope.read(context);
  final e = st.ex(id);
  return showAppSheet(context,
      title: e.name,
      back: back,
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Muted('${e.typeLabel} · ${e.regText} · ${e.eqText}${e.impact == 'high' ? ' · High impact' : ''}${e.combo ? ' · Combo' : ''}'),
            const SizedBox(height: 6),
            _p('Setup', e.setup),
            _p('Cues', e.cues.join(' · ')),
            _p('Common mistake', e.mistake),
            _p('Breathing', e.breath),
            if (e.lowImpact.isNotEmpty) _p('Low impact', e.lowImpact),
            _p('Easier', e.regression),
            if (e.progression.isNotEmpty) _p('Harder', e.progression),
            if (edit) ...[
              const SizedBox(height: 12),
              Pill('Edit in library', block: true, onTap: () {
                Navigator.pop(ctx);
                openLibForm(context, id);
              }),
            ],
          ]));
}

// ================= swap =================
Future<void> openSwap(BuildContext context, String sec, int b, int i) {
  return showAppSheet(context, title: 'Swap exercise', builder: (ctx) => _SwapBody(sec: sec, b: b, i: i));
}

class _SwapBody extends StatefulWidget {
  final String sec;
  final int b, i;
  const _SwapBody({required this.sec, required this.b, required this.i});
  @override
  State<_SwapBody> createState() => _SwapBodyState();
}

class _SwapBodyState extends State<_SwapBody> {
  bool all = false;
  String q = '';

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final arr = st.slotList(widget.sec, widget.b);
    final cur = st.ex(arr[widget.i]);
    final sec = widget.sec;
    final type = sec == 'wu'
        ? 'warmup'
        : sec == 'cd'
            ? 'cooldown'
            : (sec == 'fin' || (sec == 'ex' && cur.type == 'cardio'))
                ? 'cardio'
                : 'resistance';
    final ep = st.E.p;
    final inWeek = ep.allIds.toSet();
    final rec = st.E.saved ? <String>{} : st.recentIds(ep.weekNo);
    var list = st.db.library
        .where((e) => e.type == type && e.id != cur.id && st.comboOK(e) && (all || st.avail(e) || type == 'warmup' || type == 'cooldown'))
        .toList();
    if (type == 'resistance' && !all) list = list.where((e) => e.regions.any(cur.regions.contains)).toList();
    if (q.isNotEmpty) list = list.where((e) => e.name.toLowerCase().contains(q.toLowerCase())).toList();
    int score(Exercise e) =>
        (inWeek.contains(e.id) ? 4 : 0) +
        (rec.contains(e.id) ? 2 : 0) +
        (type == 'resistance' && e.regions.isNotEmpty && cur.regions.isNotEmpty && e.regions[0] != cur.regions[0] ? 1 : 0);
    list.sort((a, c) {
      final d = score(a) - score(c);
      return d != 0 ? d : a.name.compareTo(c.name);
    });
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Replacing '),
            TextSpan(text: cur.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
            TextSpan(text: '${type == 'resistance' ? ' · same muscle region (${cur.regText})' : ''}${all ? ', all equipment' : ', your equipment'}.'),
          ]),
          style: const TextStyle(fontSize: 14, color: AppColors.muted)),
      const SizedBox(height: 10),
      TextField(
        decoration: fieldDeco(hint: 'Search').copyWith(prefixIcon: const Icon(Icons.search, color: AppColors.muted)),
        onChanged: (v) => setState(() => q = v),
      ),
      Row(children: [
        const Expanded(child: Text('Show all regions and equipment', style: TextStyle(fontSize: 14))),
        AppSwitch(value: all, onChanged: (v) => setState(() => all = v)),
      ]),
      if (list.isEmpty) const Muted('No matches. Try "show all" or add an exercise in the Library.', padding: EdgeInsets.only(top: 8)),
      for (var k = 0; k < list.length; k++)
        ExRow(
          e: list[k],
          first: k == 0,
          extraTags: [
            if (inWeek.contains(list[k].id)) const Tag('In this week', kind: 'warn'),
            if (rec.contains(list[k].id)) const Tag('Recent', kind: 'warn'),
          ],
          onInfo: () => openInfo(context, list[k].id, edit: false, back: true),
          action: RoundIconButton(Icons.check, tooltip: 'Use ${list[k].name}', onTap: () {
            Navigator.pop(context);
            st.doSwap(widget.sec, widget.b, widget.i, list[k].id);
          }),
        ),
    ]);
  }
}

// ================= workout sheet (accordions + briefing) =================
Future<void> openWorkoutSheet(BuildContext context, {bool auto = false}) async {
  final st = AppScope.read(context);
  if (st.workoutSheetOpen) return;
  st.workoutSheetOpen = true;
  try {
    await showAppSheet(context, title: auto ? 'Brief the next block' : 'Workout', builder: (ctx) => const _WorkoutBody());
  } finally {
    st.workoutSheetOpen = false;
  }
}

class _WorkoutBody extends StatefulWidget {
  const _WorkoutBody();
  @override
  State<_WorkoutBody> createState() => _WorkoutBodyState();
}

class _WorkoutBodyState extends State<_WorkoutBody> {
  int? openSec;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: st.segKey,
      builder: (context, _, _) {
        final g = st.seg;
        if (g == null) return const Muted('This plan has no exercises yet.');
        final t = st.t;
        final nx = g.secIdx + 1 < st.tl.sections.length ? st.tl.sections[g.secIdx + 1] : null;
        openSec ??= (g.kind == 'break' || t.waiting) && nx != null ? g.secIdx + 1 : g.secIdx;
        final showBrief = (t.waiting || g.kind == 'break') && nx != null && (nx.kind == 'block' || nx.kind == 'cooldown');
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (showBrief) _briefing(context, st, nx),
          for (var si = 0; si < st.tl.sections.length; si++)
            if (st.tl.sections[si].kind != 'break') _acc(context, st, st.tl.sections[si], si),
        ]);
      },
    );
  }

  void _info(BuildContext context, String? id) {
    if (id == null) return;
    openInfo(context, id, edit: false, back: true);
  }

  Widget _card(List<Widget> children, {EdgeInsets margin = EdgeInsets.zero}) => Container(
        margin: margin,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(kLg)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  Widget _lv(String label, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text.rich(
            TextSpan(children: [TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)), TextSpan(text: text)]),
            style: const TextStyle(fontSize: 14, color: Color(0xFF3B403D), height: 1.35)),
      );

  Widget _briefing(BuildContext context, AppState st, Section sec) {
    final k = st.K, s = k.s, p = k.p;
    if (sec.kind == 'cooldown') {
      return _card(margin: const EdgeInsets.only(bottom: 10), [
        const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text('Next: Cool-down', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: AppColors.ink))),
        for (var i = 0; i < p.cooldown.length; i++)
          TaskRow(
            first: i == 0,
            icon: Icons.self_improvement,
            name: st.ex(p.cooldown[i]).name,
            sub: '${s.cdSec} s${st.ex(p.cooldown[i]).sides ? ', switch sides at the beep' : ''}',
            onTap: () => _info(context, p.cooldown[i]),
          ),
      ]);
    }
    final b = p.blocks[sec.block];
    final timing = s.isTempo
        ? '${b.ex.length} tracks · ${fmtM(b.tempoSec)}'
        : s.isLadder
            ? 'Ladder ${s.ladder.join('-')} s, rest ${s.rest} s, ${b.ex.length} exercises'
            : '${b.work ?? s.work}/${b.rest ?? s.rest} · ${b.ex.length} exercises × ${s.rounds} rounds';
    return _card(margin: const EdgeInsets.only(bottom: 10), [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Next: ${sec.label}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: AppColors.ink)),
          Text('${themeName(b.theme)} · $timing', style: const TextStyle(fontSize: 13, color: AppColors.inkMuted)),
        ]),
      ),
      for (var i = 0; i < b.ex.length; i++)
        Builder(builder: (_) {
          final e = st.ex(b.ex[i]);
          return TaskRow(
            first: i == 0,
            alignTop: true,
            icon: Icons.fitness_center,
            name: e.name,
            sub: '${s.isTempo ? '${b.trkText(i)} · ' : ''}${e.regText} · ${e.eqText}',
            extra: [
              _lv('Cue', e.cues.first),
              _lv('Easier', e.regression),
              if (e.progression.isNotEmpty) _lv('Harder', e.progression),
            ],
            onTap: () => _info(context, e.id),
          );
        }),
      if (b.fin.isNotEmpty) SubLabel('Finisher · ${fmtM(s.finSec)}', color: AppColors.inkMuted),
      for (final id in b.fin)
        TaskRow(
          icon: Icons.bolt,
          name: st.ex(id).name,
          sub: st.ex(id).lowImpact.isNotEmpty ? 'Low impact: ${st.ex(id).lowImpact}' : st.ex(id).cues.first,
          onTap: () => _info(context, id),
        ),
    ]);
  }

  Widget _acc(BuildContext context, AppState st, Section x, int si) {
    final accent = st.accent;
    final t = st.t, g = st.seg!;
    final items = <int>[for (var i = x.start; i <= x.end; i++) if (st.tl.segs[i].kind != 'rest' && st.tl.segs[i].kind != 'break') i];
    bool isDone(int i) => t.finished || i < t.idx || (t.waiting && i == t.idx);
    final curItem = t.waiting || t.finished ? -1 : items.indexOf(t.idx);
    final nextItem = curItem < 0 && !t.waiting && !t.finished ? items.indexWhere((i) => i > t.idx) : -1;
    final done = items.where(isDone).length;
    final open = openSec == si;
    final curSec = g.secIdx == si || (g.kind == 'break' && g.secIdx + 1 == si);
    final title = x.kind == 'block' ? '${x.label} · ${themeName(x.theme)}' : x.label;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(kLg),
        border: Border.all(color: curSec ? accent.withValues(alpha: .6) : AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
          child: Row(children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => openSec = open ? -1 : si),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 4, 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                        Text(fmtM(x.dur), style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                      ]),
                    ),
                    Text('$done/${items.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w300)),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                        turns: open ? .5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.expand_more, color: AppColors.muted)),
                  ]),
                ),
              ),
            ),
            Pill('Go to start', height: 44, fontSize: 14, padding: const EdgeInsets.symmetric(horizontal: 12), onTap: () {
              Navigator.pop(context);
              st.goTo(x.start, false);
            }),
          ]),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(kLg)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var n = 0; n < items.length; n++) _accRow(context, st, items[n], n, isDone(items[n]), curItem, nextItem),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _accRow(BuildContext context, AppState st, int i, int n, bool done, int curItem, int nextItem) {
    final sg = st.tl.segs[i], e = st.ex(sg.ex);
    final cls = done ? 'done' : (n == curItem ? 'cur' : (n == nextItem ? 'next pending' : 'pending'));
    final icon = switch (sg.kind) {
      'finisher' => Icons.bolt,
      'work' => Icons.fitness_center,
      'warmup' => Icons.directions_run,
      _ => Icons.self_improvement,
    };
    var sub = '${sg.dur} s';
    if (sg.kind == 'work') {
      sub = sg.tempo.isNotEmpty
          ? '${sg.dur} s · Tempo ${sg.tempo}${sg.note.isNotEmpty ? ' · ${sg.note}' : ''} · ${e.eqText}'
          : 'Round ${sg.r + 1}/${sg.R} · ${sg.dur} s · ${e.eqText}';
    }
    if (sg.kind == 'finisher') sub = '${sg.dur} s${e.lowImpact.isNotEmpty ? ' · Low: ${e.lowImpact}' : ''}';
    return TaskRow(first: n == 0, cls: cls, icon: icon, name: st.segName(sg), sub: sub, onTap: () => _info(context, sg.ex));
  }
}

// ================= library form =================
Future<void> openLibForm(BuildContext context, String? id, {String? type}) {
  return showAppSheet(context, title: id != null ? 'Edit exercise' : 'Add exercise', builder: (ctx) => _LibForm(id: id, type: type));
}

class _LibForm extends StatefulWidget {
  final String? id;
  final String? type;
  const _LibForm({this.id, this.type});
  @override
  State<_LibForm> createState() => _LibFormState();
}

class _LibFormState extends State<_LibForm> {
  late Exercise e;
  late final Map<String, TextEditingController> c;

  @override
  void initState() {
    super.initState();
    final st = AppScope.read(context);
    final src = widget.id != null ? st.ex(widget.id) : Exercise(id: '', name: '', type: widget.type ?? 'resistance', equip: ['bw'], cues: []);
    e = Exercise.fromJson(src.toJson());
    if (widget.id == null) e.cues = [];
    c = {
      'name': TextEditingController(text: e.name),
      'regression': TextEditingController(text: e.regression),
      'progression': TextEditingController(text: e.progression),
      'lowImpact': TextEditingController(text: e.lowImpact),
      'setup': TextEditingController(text: e.setup),
      'cues': TextEditingController(text: e.cues.where((x) => x.isNotEmpty).join('\n')),
      'mistake': TextEditingController(text: e.mistake),
      'breath': TextEditingController(text: e.breath),
    };
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  Widget _field(String key, String label, {int lines = 1}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Muted(label)),
          TextField(controller: c[key], maxLines: lines, minLines: lines > 1 ? 3 : 1, style: const TextStyle(fontSize: 17), decoration: fieldDeco()),
        ]),
      );

  Widget _chips(List<(String, String)> items, bool Function(String) isOn, void Function(String) toggle) {
    final accent = AppScope.of(context).accent;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final (k, l) in items)
        Material(
          color: isOn(k) ? accent : Colors.transparent,
          shape: StadiumBorder(side: BorderSide(color: isOn(k) ? Colors.transparent : AppColors.line)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => toggle(k)),
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(widthFactor: 1, child: Text(l, style: TextStyle(fontSize: 14, color: isOn(k) ? AppColors.accentInk : AppColors.muted))),
            ),
          ),
        ),
    ]);
  }

  Widget _group(String label, Widget child) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Muted(label)),
          child,
        ]),
      );

  void _save() {
    final st = AppScope.read(context);
    String g(String k) => c[k]!.text.trim();
    final regions = e.regions.toSet().toList();
    final out = Exercise(
      id: widget.id ?? 'u${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
      name: g('name'),
      type: e.type,
      regions: regions,
      equip: e.equip.isEmpty ? ['bw'] : e.equip,
      impact: e.impact,
      combo: e.combo,
      regression: g('regression'),
      progression: g('progression'),
      lowImpact: g('lowImpact'),
      setup: g('setup'),
      cues: g('cues').split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty).toList(),
      mistake: g('mistake'),
      breath: g('breath'),
    );
    if (out.name.isEmpty) return st.ui?.toast('Add a name');
    if (out.regions.isEmpty) return st.ui?.toast('Pick at least one region');
    if (out.regression.isEmpty) return st.ui?.toast('Add a regression');
    if (out.impact == 'high' && out.lowImpact.isEmpty) return st.ui?.toast('Jumps need a low-impact version');
    if (out.cues.isEmpty) out.cues = [''];
    if (out.type == 'warmup' || out.type == 'cooldown') {
      final old = widget.id != null ? st.ex(widget.id) : null;
      out.set = old?.set ?? 0;
      out.sides = old?.sides ?? false;
    }
    Navigator.pop(context);
    st.libSave(out, isNew: widget.id == null);
  }

  Future<void> _delete() async {
    final st = AppScope.read(context);
    final id = widget.id!;
    if (st.libInUse(id)) return st.ui?.toast('It is in the plan you are using. Swap it out first.');
    final nav = Navigator.of(context);
    if (!await st.ui!.confirm('Delete exercise?', 'Delete ${st.ex(id).name}?', 'Delete', danger: true)) return;
    nav.pop();
    st.libDelete(id);
  }

  @override
  Widget build(BuildContext context) {
    final allRegions = [...kResRegions, 'cardio', 'hips', 'mobility'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _field('name', 'Name'),
      _group(
          'Type',
          _chips(const [('resistance', 'Resistance'), ('cardio', 'Cardio'), ('warmup', 'Warm-up'), ('cooldown', 'Cool-down')], (k) => e.type == k,
              (k) => e.type = k)),
      _group(
          'Muscle region(s). The first one picked is the main region.',
          _chips([for (final r in allRegions) (r, kRegionLabel[r]!)], e.regions.contains,
              (k) => e.regions.contains(k) ? e.regions.remove(k) : e.regions.add(k))),
      _group(
        'Equipment (all must be available)',
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final grp in kEqGroups) ...[
            SubLabel(grp[1]),
            _chips([for (final q in eqByGroup(grp[0])) (q[0], q[1])], e.equip.contains,
                (k) => e.equip.contains(k) ? e.equip.remove(k) : e.equip.add(k)),
          ],
        ]),
      ),
      _group('Impact', _chips(const [('low', 'Low'), ('high', 'High (jump)')], (k) => e.impact == k, (k) => e.impact = k)),
      _group('Combo move', _chips(const [('1', 'Yes, combo')], (_) => e.combo, (_) => e.combo = !e.combo)),
      _field('regression', 'Regression (easier, same muscles)'),
      _field('progression', 'Progression (optional)'),
      _field('lowImpact', 'Low-impact version (required for jumps)'),
      _field('setup', 'Setup (one line)'),
      _field('cues', 'Coaching cues, one per line', lines: 4),
      _field('mistake', 'Most common mistake'),
      _field('breath', 'Breathing'),
      const SizedBox(height: 8),
      Pill('Save', kind: PillKind.primary, block: true, onTap: _save),
      if (widget.id != null) ...[const SizedBox(height: 10), Pill('Delete', kind: PillKind.danger, block: true, onTap: _delete)],
    ]);
  }
}
