import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../constants.dart';
import '../models.dart';
import 'sheets.dart';
import 'widgets.dart';

class PlanScreen extends StatelessWidget {
  final VoidCallback goToClass;
  const PlanScreen({super.key, required this.goToClass});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final saved = st.planMode == 'saved';
    final k = st.K;
    final title = saved ? (st.db.wk?.name ?? 'Saved workouts') : st.weekLabel(st.db.plan.weekNo);
    final mq = MediaQuery.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, mq.padding.top + 10, 16, mq.padding.bottom + 120),
      children: [
        PageTitle(title),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SegCtl<String>(
            expand: true,
            items: const [('week', 'Weekly program'), ('saved', 'Saved workouts')],
            value: st.planMode,
            onTap: (m) {
              st.planMode = m;
              st.notify();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Class tab runs: '),
              TextSpan(
                text: k.saved ? '${k.name} (saved workout)' : '${st.weekLabel(st.db.plan.weekNo)} (weekly program)',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
              ),
            ]),
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
          ),
        ),
        if (!saved) ..._weekly(context, st) else ..._saved(context, st),
      ],
    );
  }

  List<Widget> _weekly(BuildContext context, AppState st) {
    final p = st.db.plan;
    final quick = ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Tempo 50']
        .map((n) => st.db.saved.where((w) => w.name == n).firstOrNull)
        .whereType<SavedWorkout>()
        .toList();
    return [
      if (quick.isNotEmpty)
        GlassSection(title: 'Quick start', children: [
          AppDropdown<String>(
            value: '',
            expand: true,
            items: [
              ('', 'Choose a workout…'),
              for (final w in quick)
                (w.id, '${w.name} · ${fmtM(planTotal(w.snap.settings, w.snap.plan))}${st.db.activeId == w.id ? ' · loaded' : ''}'),
            ],
            onChanged: (id) async {
              if (id == null || id.isEmpty) return;
              if (await st.quickPick(id)) goToClass();
            },
          ),
          const Muted('Pick a workout, confirm, and the Class tab opens with it ready to start.', size: 12, padding: EdgeInsets.only(top: 8)),
        ]),
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Tag(p.status == 'saved' ? 'Saved' : 'Draft, not saved', kind: p.status == 'saved' ? '' : 'warn', fontSize: 13),
          Muted('${st.presetLabel(st.db.settings)} · total ${fmt(planTotal(st.db.settings, p))}'),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          Pill('Regenerate', icon: Icons.replay, onTap: st.regenerate),
          Pill('Save week', icon: Icons.check, kind: PillKind.primary, onTap: st.saveWeek),
          Pill('Next week ›', onTap: st.nextWeek),
          Pill('Set week #', onTap: () async {
            final v = await nameSheet(context, 'Set week number', '${st.db.plan.weekNo}', 'Set',
                label: 'Week number (1-520)', keyboard: TextInputType.number, maxLength: 3);
            final n = int.tryParse(v?.trim() ?? '');
            if (n != null && n >= 1 && n <= 520) st.setWeek(n);
          }),
        ]),
      ),
      Pill('Save as new workout', icon: Icons.add, kind: PillKind.white, block: true, onTap: () => _saveNew(context, st)),
      if (st.K.saved) ...[
        InfoBanner(
          child: Text.rich(TextSpan(children: [
            const TextSpan(text: 'The Class tab is running the saved workout '),
            TextSpan(text: st.K.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            const TextSpan(text: ". Edits to the weekly program don't change it."),
          ])),
        ),
        Pill('Run the weekly program on the Class tab', block: true, onTap: st.useWeekly),
      ],
      const SizedBox(height: 6),
      ...PlanEditor.build(context, st, st.E),
      const Muted(
        'Save week records these exercises so Regenerate avoids them for the next 2 weeks. Next week saves this week first, then drafts the next one with the next format in the 4-week cycle. Saved workouts are separate: Regenerate and Next week never touch them.',
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      ),
    ];
  }

  Future<void> _saveNew(BuildContext context, AppState st) async {
    final c = st.E;
    final def = c.saved ? '${c.name} copy' : 'Week ${st.db.plan.weekNo} workout';
    final name = await nameSheet(context, 'Save as new workout', def, 'Save');
    if (name == null) return;
    if (name.trim().isEmpty) return st.ui?.toast('Add a name');
    st.saveNew(name.trim());
  }

  List<Widget> _saved(BuildContext context, AppState st) {
    final wk = st.db.wk;
    return [
      GlassSection(title: 'Saved workouts', children: [
        Pill('Save as new workout', icon: Icons.add, kind: PillKind.white, block: true, onTap: () => _saveNew(context, st)),
        Muted('Saves ${wk != null ? 'the loaded workout as you have it now' : 'the weekly draft as it is now'}.',
            size: 12, padding: const EdgeInsets.only(top: 8, bottom: 6)),
        if (st.db.saved.isEmpty)
          const Muted('No saved workouts yet. Adapt the weekly draft or any loaded workout, then save it with the button above.'),
        for (var i = 0; i < st.db.saved.length; i++) _savedRow(context, st, st.db.saved[i], i == 0),
      ]),
      if (wk != null) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Tag(st.wkDirty() ? 'Unsaved changes' : 'Matches saved version', kind: st.wkDirty() ? 'warn' : '', fontSize: 13),
            Muted('${st.presetLabel(wk.settings)} · total ${fmt(planTotal(wk.settings, wk.plan))}'),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            Pill('Save changes', icon: Icons.check, kind: PillKind.primary, onTap: () => st.swOver(wk.id)),
            Pill('Run the weekly program instead', onTap: st.useWeekly),
          ]),
        ),
        ...PlanEditor.build(context, st, st.E),
      ] else
        const InfoBanner(child: Text('Load a saved workout to edit it here. Until then, the Class tab runs the weekly program.')),
    ];
  }

  Widget _savedRow(BuildContext context, AppState st, SavedWorkout w, bool first) {
    final act = st.db.activeId == w.id, miss = st.missingIn(w.snap.plan).length;
    Widget sp(String l, VoidCallback f, {PillKind kind = PillKind.normal}) =>
        Pill(l, kind: kind, onTap: f, height: 44, fontSize: 14, padding: const EdgeInsets.symmetric(horizontal: 14));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(w.name, style: const TextStyle(fontSize: 17)),
        const SizedBox(height: 2),
        Wrap(spacing: 4, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('${fmt(planTotal(w.snap.settings, w.snap.plan))} · saved ${w.saved} · ${w.snap.plan.blocks.length} blocks',
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          if (act) const Tag('Active on Class'),
          if (miss > 0) Tag('$miss deleted', kind: 'warn'),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          sp(act ? 'Loaded' : 'Load', () => st.swLoad(w.id), kind: act ? PillKind.on : PillKind.primary),
          sp('Rename', () async {
            final name = await nameSheet(context, 'Rename workout', w.name, 'Rename');
            if (name == null) return;
            if (name.trim().isEmpty) return st.ui?.toast('Add a name');
            st.swRename(w.id, name.trim());
          }),
          sp('Duplicate', () => st.swDup(w.id)),
          sp('Overwrite', () => st.swOver(w.id)),
          sp('Delete', () => st.swDel(w.id), kind: PillKind.danger),
        ]),
      ]),
    );
  }
}

/// The timing + exercise editor shared by the weekly draft and a loaded saved workout.
class PlanEditor {
  static List<Widget> build(BuildContext context, AppState st, Ctx c) {
    final s = c.s, p = c.p, total = planTotal(s, p), diff = total - 3000;
    final miss = st.missingIn(p);
    final rec = c.saved ? <String>{} : st.recentIds(p.weekNo);
    Widget swap(String sec, int b, int i) => RoundIconButton(Icons.swap_horiz, tooltip: 'Swap', onTap: () => openSwap(context, sec, b, i));
    void info(String id) => openInfo(context, id);

    return [
      if (miss.isNotEmpty)
        InfoBanner(
          kind: 'warn',
          child: Text.rich(TextSpan(children: [
            TextSpan(
                text: '${miss.length} exercise${miss.length > 1 ? 's' : ''} no longer in the library. ',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const TextSpan(text: 'They show as "(deleted exercise)". Swap them for other exercises before class.'),
          ])),
        ),
      if (p.notes.isNotEmpty)
        InfoBanner(
          kind: 'warn',
          onClose: st.dismissNotes,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Regenerate notes', style: TextStyle(fontWeight: FontWeight.w600)),
            for (final n in p.notes) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $n')),
          ]),
        ),
      if (s.isTempo) _tempoTiming(st, s, total, diff) else _timing(st, s, p, total, diff),
      if (p.warmup.isNotEmpty)
        GlassSection(title: 'Warm-up', children: [
          if (p.wuRestSec > 0) Muted('${p.wuRestSec} s pause between moves', padding: const EdgeInsets.only(bottom: 6)),
          for (var i = 0; i < p.warmup.length; i++)
            ExRow(
              first: i == 0,
              e: st.ex(p.warmup[i]),
              extraTags: [Tag('${p.wuDur(s, i)} s${p.wuNoteAt(i).isNotEmpty ? ' · ${p.wuNoteAt(i)}' : ''}')],
              onInfo: () => info(p.warmup[i]),
              action: swap('wu', 0, i),
            ),
        ]),
      for (var bi = 0; bi < p.blocks.length; bi++)
        Builder(builder: (context) {
          final b = p.blocks[bi];
          return GlassSection(
            title: 'Block ${bi + 1}',
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (b.work != null || b.rest != null) ...[Tag('${b.work ?? s.work}/${b.rest ?? s.rest} s'), const SizedBox(width: 8)],
              AppDropdown<String>(
                value: kThemes.containsKey(b.theme) ? b.theme : 'full',
                items: [for (final e in kThemes.entries) (e.key, e.value.label)],
                onChanged: (v) {
                  if (v != null) st.setTheme(bi, v);
                },
              ),
            ]),
            children: [
              for (var i = 0; i < b.ex.length; i++) ...[
                ExRow(
                  first: i == 0,
                  e: st.ex(b.ex[i]),
                  extraTags: [if (rec.contains(b.ex[i])) const Tag('Recent', kind: 'warn')],
                  onInfo: () => info(b.ex[i]),
                  action: swap('ex', bi, i),
                ),
                if (s.isTempo) _TrackCtl(key: ValueKey('trk-${st.planMode}-$bi-$i-${b.ex[i]}'), bi: bi, i: i),
              ],
              if (b.fin.isNotEmpty) SubLabel('Finisher · ${fmtM(s.finSec)}'),
              for (var i = 0; i < b.fin.length; i++)
                ExRow(
                  e: st.ex(b.fin[i]),
                  extraTags: [if (rec.contains(b.fin[i])) const Tag('Recent', kind: 'warn')],
                  onInfo: () => info(b.fin[i]),
                  action: swap('fin', bi, i),
                ),
            ],
          );
        }),
      if (p.cooldown.isNotEmpty)
        GlassSection(title: 'Cool-down', children: [
          for (var i = 0; i < p.cooldown.length; i++)
            ExRow(first: i == 0, e: st.ex(p.cooldown[i]), onInfo: () => info(p.cooldown[i]), action: swap('cd', 0, i)),
        ]),
    ];
  }

  static Widget _step(AppState st, String key, int val, String label, String? hint, int step, int min, int max, [String unit = '']) =>
      StepperRow(
        label: label,
        hint: hint,
        value: '$val$unit',
        onDec: () => st.stepSetting(key, -step, min, max),
        onInc: () => st.stepSetting(key, step, min, max),
      );

  static Widget _total(AppState st, int total, int diff) {
    final col = diff == 0 ? st.accent : AppColors.warn;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(fmt(total), style: TextStyle(fontSize: 44, fontWeight: FontWeight.w200, color: col, fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            diff == 0 ? 'Exactly 50:00 ✓' : '${diff > 0 ? '${fmtM(diff)} over' : '${fmtM(-diff)} under'} 50:00',
            style: TextStyle(color: col),
          ),
        ),
      ]),
    );
  }

  static Widget _wuCd(AppState st, Settings s) => Column(children: [
        _step(st, 'wuMoves', s.wuMoves, 'Warm-up moves', s.wuMoves > 0 ? '' : 'None: the timer starts at Block 1', 1, 0, 12),
        _step(st, 'wuSec', s.wuSec, 'Warm-up move length', '', 15, 30, 90, ' s'),
        _step(st, 'cdMoves', s.cdMoves, 'Cool-down stretches', s.cdMoves > 0 ? '' : 'None: the class ends after the last block', 1, 0, 8),
        _step(st, 'cdSec', s.cdSec, 'Cool-down stretch length', '', 15, 30, 90, ' s'),
      ]);

  static Widget _tempoTiming(AppState st, Settings s, int total, int diff) => GlassSection(title: 'Timing', children: [
        const Muted(
          'Tempo blocks: every track has its own length and tempo, and the timer runs straight through with no rests or breaks. Tempo is seconds down, seconds up, then an optional hold at the hardest point (1-1-2).',
          padding: EdgeInsets.only(bottom: 8),
        ),
        _step(st, 'exPerBlock', s.exPerBlock, 'Tracks per block', '', 1, 1, 8),
        _step(st, 'blocks', s.blocks, 'Blocks', '', 1, 1, 10),
        _wuCd(st, s),
        _total(st, total, diff),
        const SizedBox(height: 10),
        Pill('Switch to circuit timing (45/15)', block: true, onTap: () => st.setPreset('base')),
      ]);

  static Widget _timing(AppState st, Settings s, Plan p, int total, int diff) {
    final ladder = s.isLadder;
    final ratio = s.rest > 0 ? s.work / s.rest : 0.0;
    final ratioWarn = !ladder && (ratio < 2.95 || ratio > 4.05);
    final fs = s.finSec;
    return GlassSection(title: 'Timing', children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SegCtl<String>(
          items: [for (final e in kPresets.entries) (e.key, e.value.label)],
          value: s.preset,
          onTap: st.setPreset,
        ),
      ),
      if (ladder) ...[
        for (var i = 0; i < s.ladder.length; i++) _step(st, 'ladder$i', s.ladder[i], 'Ladder round ${i + 1} work', '', 5, 10, 120, ' s'),
        _step(st, 'rest', s.rest, 'Rest', '', 1, 5, 60, ' s'),
      ] else ...[
        _step(st, 'work', s.work, 'Work', '', 1, 10, 120, ' s'),
        _step(st, 'rest', s.rest, 'Rest', 'Ratio ${ratio.toStringAsFixed(1)}:1${ratioWarn ? ' (outside 3:1 to 4:1)' : ''}', 1, 5, 60, ' s'),
      ],
      _step(st, 'exPerBlock', s.exPerBlock, 'Exercises per block', s.keepLength && !ladder ? 'Work/rest adjusts to keep block length' : '', 1, 1, 6),
      if (!ladder) _step(st, 'rounds', s.rounds, 'Rounds', '', 1, 1, 4),
      _step(st, 'finMoves', s.finMoves, 'Finisher moves', s.finMoves > 0 ? '' : 'None: the cardio move sits inside the block', 1, 0, 8),
      _step(st, 'finWork', s.finWork, 'Finisher move length', '', 5, 15, 60, ' s'),
      _step(st, 'finRounds', s.finRounds, 'Finisher rounds', 'Finisher ${fmtM(fs)} (max 7:30)', 1, 1, 3),
      _step(st, 'breakSec', s.breakSec, 'Break between blocks', '', 15, 30, 300, ' s'),
      _step(st, 'blocks', s.blocks, 'Blocks', '', 1, 3, 5),
      _wuCd(st, s),
      KV(
        label: 'Keep block length',
        hint: 'When exercises per block changes',
        trailing: AppSwitch(value: s.keepLength, onChanged: st.setKeepLength),
      ),
      _total(st, total, diff),
      Muted(
        'Each block: ${fmtM(blockResSec(s, s.exPerBlock) + fs)}${p.blocks.any((b) => b.rest != null || b.work != null) ? ' (some blocks have their own timing)' : ''}. Untimed waits for your tap are not counted.',
        size: 12,
        padding: const EdgeInsets.only(top: 4),
      ),
    ]);
  }
}

/// Tempo / note / length controls for one track of a tempo block.
class _TrackCtl extends StatelessWidget {
  final int bi, i;
  const _TrackCtl({super.key, required this.bi, required this.i});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    if (bi >= st.E.p.blocks.length) return const SizedBox.shrink();
    final b = st.E.p.blocks[bi];
    final q = b.trk(i);
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: AppColors.glass2,
          hintStyle: const TextStyle(color: AppColors.dim),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
        );
    const lbl = TextStyle(fontSize: 13, color: AppColors.muted);
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 0, 0, 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(14)),
      child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Tempo ', style: lbl),
          SizedBox(
            width: 78,
            child: LiveField(
              initial: q.tempo,
              maxLength: 12,
              style: const TextStyle(fontSize: 15),
              decoration: deco('2-2'),
              onChanged: (v) {
                st.trkSet(bi, i, 'tempo', v.trim());
                st.changedQuiet();
              },
            ),
          ),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Note ', style: lbl),
          SizedBox(
            width: 150,
            child: LiveField(
              initial: q.note,
              maxLength: 40,
              style: const TextStyle(fontSize: 15),
              decoration: deco('optional'),
              onChanged: (v) {
                st.trkSet(bi, i, 'note', v.trim());
                st.changedQuiet();
              },
            ),
          ),
        ]),
        MiniStepper(value: '${q.dur} s', onDec: () => st.trkDur(bi, i, -15), onInc: () => st.trkDur(bi, i, 15)),
      ]),
    );
  }
}
