import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'audio.dart';
import 'constants.dart';
import 'models.dart';
import 'timeline.dart';

/// Hooks the UI layer provides so state logic can talk to the user.
abstract class UiHooks {
  void toast(String msg);
  Future<bool> confirm(String title, String msg, String yesLabel, {bool danger = false});
  void openWorkout({required bool auto});
  void flash(Color c);
}

/// Edit context: settings + plan being shown / run.
class Ctx {
  final Settings s;
  final Plan p;
  final String name;
  final bool saved;
  Ctx(this.s, this.p, this.name, this.saved);
}

class _GenCtx {
  final Set<String> used;
  final Set<String> recent;
  final Set<String> last;
  final List<String> notes = [];
  _GenCtx(this.used, this.recent, this.last);
}

class TimerState {
  int idx = 0;
  bool running = false;
  double startAt = 0; // ms since epoch
  double paused = 0; // seconds
  bool waiting = false;
  double waitAt = 0;
  bool finished = false;
  Set<String> fired = {};

  void reset() {
    idx = 0;
    running = false;
    waiting = false;
    paused = 0;
    finished = false;
    fired = {};
  }
}

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  static const lsKey = 'circuitCoach.v1';
  static const lsSession = 'circuitCoach.session';

  late DB db;
  late List<Exercise> _starterLibrary;
  late Map<String, dynamic> _seeds;
  Map<String, Exercise> lib = {};
  Timeline tl = Timeline.empty();
  final TimerState t = TimerState();
  final CueAudio audio = CueAudio();
  final math.Random _rnd = math.Random();
  SharedPreferences? _sp;
  bool storageOK = true;
  bool resumed = false;
  UiHooks? ui;

  /// Set to false in tests, where the audio plugins are not available.
  final bool platformAudio;
  AppState({this.platformAudio = true});

  /// 'week' or 'saved': which plan the Plan tab is editing.
  String planMode = 'week';

  /// Fires on every timer tick (for the ring and digits).
  final ValueNotifier<int> tick = ValueNotifier(0);

  /// Changes only when the current segment / waiting / finished state changes.
  final ValueNotifier<String> segKey = ValueNotifier('');

  /// Wake lock status: off | on | failed
  String wlStatus = 'off';
  bool wlWanted = false;

  Timer? _ticker;
  Timer? _saveT;
  bool _autoBrief = false;
  bool workoutSheetOpen = false;

  // ================= boot & storage =================
  Future<void> boot() async {
    final libJson = jsonDecode(await rootBundle.loadString('assets/data/library.json')) as List;
    _starterLibrary = libJson.map((e) => Exercise.fromJson((e as Map).cast<String, dynamic>())).toList();
    _seeds = jsonDecode(await rootBundle.loadString('assets/data/seeds.json')) as Map<String, dynamic>;
    try {
      _sp = await SharedPreferences.getInstance();
    } catch (_) {
      storageOK = false;
    }
    _load();
    lib = _libMap();
    buildTimeline();
    resumed = _restoreSession();
    planMode = db.wk != null ? 'saved' : 'week';
    if (platformAudio) await audio.init(db.prefs.audioMode);
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tick();
      if (wlWanted) requestWake();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      saveSession();
      save(now: true);
    }
  }

  List<Exercise> starterLibrary() => _starterLibrary.map((e) => Exercise.fromJson(e.toJson())).toList();
  Plan _week1() => Plan.fromJson((_seeds['week1'] as Map).cast<String, dynamic>());

  DB freshDB() {
    final d = DB(
      settings: Settings(),
      equipment: {for (final e in kEquip) e[0]: e[2] == 'common'},
      prefs: Prefs(),
      library: starterLibrary(),
      plan: _week1(),
    );
    _seedSaved(d);
    return d;
  }

  void _seedSaved(DB d) {
    if (d.seedV >= 8) return;
    for (final s in (_seeds['seeds'] as List)) {
      final m = (s as Map).cast<String, dynamic>();
      final name = m['name'] as String;
      if (d.saved.any((w) => w.name == name)) continue;
      d.saved.add(SavedWorkout(
        id: newId(),
        name: name,
        saved: today(),
        snap: Snapshot(Settings.fromJson((m['settings'] as Map).cast<String, dynamic>()),
            Plan.fromJson((m['plan'] as Map).cast<String, dynamic>())),
      ));
    }
    d.seedV = 8;
  }

  String newId() =>
      'w${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(1000).toRadixString(36)}';

  /// Builds a DB from stored / imported JSON, filling gaps from a fresh DB.
  DB _fromJson(Map<String, dynamic> d) {
    final f = freshDB();
    final eq = Map<String, bool>.from(f.equipment);
    if (d['equipment'] is Map) {
      (d['equipment'] as Map).forEach((k, v) => eq[k.toString()] = v == true);
    }
    List<T> list<T>(dynamic v, T Function(Map<String, dynamic>) fn) {
      if (v is! List) return [];
      final out = <T>[];
      for (final x in v) {
        try {
          if (x is Map) out.add(fn(x.cast<String, dynamic>()));
        } catch (_) {}
      }
      return out;
    }

    final library = list(d['library'], Exercise.fromJson);
    ActiveWorkout? wk;
    try {
      if (d['wk'] is Map) wk = ActiveWorkout.fromJson((d['wk'] as Map).cast<String, dynamic>());
    } catch (_) {}
    return DB(
      settings: Settings.fromJson(d['settings'] is Map ? (d['settings'] as Map).cast<String, dynamic>() : null),
      equipment: eq,
      allowCombo: d['allowCombo'] == true,
      prefs: Prefs.fromJson(d['prefs'] is Map ? (d['prefs'] as Map).cast<String, dynamic>() : null),
      library: library.isEmpty ? f.library : library,
      plan: d['plan'] is Map ? Plan.fromJson((d['plan'] as Map).cast<String, dynamic>()) : f.plan,
      history: list(d['history'], HistoryEntry.fromJson),
      saved: d['saved'] is List ? list(d['saved'], SavedWorkout.fromJson) : f.saved,
      activeId: d['activeId'] as String?,
      wk: wk,
      seedV: d['seedV'] is num ? (d['seedV'] as num).toInt() : (d['saved'] is List ? 0 : 8),
    );
  }

  void _normDB() {
    if (db.activeId == null || db.wk == null || db.wk!.id != db.activeId) {
      db.activeId = null;
      db.wk = null;
    }
    for (final e in kEquip) {
      db.equipment.putIfAbsent(e[0], () => false);
    }
    _seedSaved(db);
    final have = db.library.map((e) => e.id).toSet();
    final re = RegExp(r'^(u[1234]|bp)');
    for (final e in starterLibrary()) {
      if (re.hasMatch(e.id) && !have.contains(e.id)) db.library.add(e);
    }
  }

  void _load() {
    try {
      final raw = _sp?.getString(lsKey);
      if (raw != null) {
        db = _fromJson(jsonDecode(raw) as Map<String, dynamic>);
        _normDB();
        return;
      }
    } catch (_) {
      storageOK = false;
    }
    db = freshDB();
  }

  void save({bool now = false}) {
    _saveT?.cancel();
    void go() {
      try {
        _sp?.setString(lsKey, jsonEncode(db.toJson()));
        storageOK = _sp != null;
      } catch (_) {
        storageOK = false;
      }
    }

    if (now) {
      go();
    } else {
      _saveT = Timer(const Duration(milliseconds: 250), go);
    }
  }

  Map<String, Exercise> _libMap() => {for (final e in db.library) e.id: e};
  Exercise ex(String? id) => (id != null ? lib[id] : null) ?? Exercise.missing(id ?? '');

  // ================= contexts =================
  /// K: what the Class tab runs.
  Ctx get K => (db.activeId != null && db.wk != null)
      ? Ctx(db.wk!.settings, db.wk!.plan, db.wk!.name, true)
      : Ctx(db.settings, db.plan, '', false);

  /// E: what the Plan tab is editing.
  Ctx get E =>
      (planMode == 'saved' && db.wk != null) ? Ctx(db.wk!.settings, db.wk!.plan, db.wk!.name, true) : Ctx(db.settings, db.plan, '', false);

  String presetLabel([Settings? s]) {
    s ??= K.s;
    if (s.isTempo) return 'Tempo blocks';
    return s.preset == 'custom' ? 'Custom timing' : (kPresets[s.preset] ?? kPresets['base']!).label;
  }

  String weekLabel([int? w]) {
    w ??= K.p.weekNo;
    return 'Week $w · Cycle ${(w / 4).ceil()}';
  }

  // ================= timeline =================
  void buildTimeline() {
    final k = K;
    final sig = jsonEncode([k.p.toJson(), k.s.toJson(), db.activeId]);
    final changed = tl.sig.isNotEmpty && tl.sig != sig;
    final next = buildTimelineFor(k.s, k.p, sig);
    tl = next;
    if (tl.segs.isEmpty) {
      t.reset();
      saveSession();
      return;
    }
    if (changed && t.idx > 0) {
      final si = math.min(tl.segs[math.min(t.idx, tl.segs.length - 1)].secIdx, tl.sections.length - 1);
      t.idx = tl.sections[si].start;
      t.running = false;
      t.waiting = false;
      t.paused = 0;
      t.fired = {};
      ui?.toast('Plan changed: timer moved to the start of ${tl.sections[si].label}');
    }
    if (t.idx >= tl.segs.length) t.idx = 0;
    saveSession();
  }

  // ================= timer engine (timestamp based) =================
  double get _now => DateTime.now().millisecondsSinceEpoch.toDouble();
  Seg? get seg => tl.segs.isEmpty ? null : tl.segs[math.min(t.idx, tl.segs.length - 1)];
  double get elapsed {
    final g = seg;
    if (g == null) return 0;
    if (t.waiting || t.finished) return g.dur.toDouble();
    return t.running ? (_now - t.startAt) / 1000 : t.paused;
  }

  bool get timerBusy => !t.finished && (t.running || t.idx > 0 || t.paused > 0);

  Color get accent => kAccents[db.prefs.accent]?.$2 ?? kAccents['mint']!.$2;

  CueCfg cue(String k) => db.prefs.cues[k]!;

  void _flash() {
    if (!db.prefs.flash) return;
    final g = seg;
    ui?.flash(g == null ? accent : stateColor(g.kind, accent));
  }

  void cueHalf() {
    if (cue('half').on) {
      audio.tone(660, .16, cue('half').vol);
      audio.tone(660, .16, cue('half').vol, .22);
    }
    _flash();
  }

  void cueCount(int n) {
    if (cue('count').on) audio.tone(n == 1 ? 1320 : 990, n == 1 ? .32 : .16, cue('count').vol);
    _flash();
  }

  void cueStart() {
    if (cue('start').on) audio.speak(cue('start').text, cue('start').vol);
    _flash();
  }

  void cueRest() {
    if (cue('rest').on) audio.speak(cue('rest').text, cue('rest').vol);
    _flash();
  }

  void testSound() {
    audio.tone(990, .16, 1);
    audio.tone(990, .16, 1, .35);
    audio.tone(1320, .32, 1, .7);
    Timer(const Duration(milliseconds: 1200), () => audio.speak(cue('start').text.isEmpty ? 'Start' : cue('start').text, 1));
    ui?.toast('Playing 3 beeps, then the voice');
  }

  void testCue(String k) {
    if (k == 'half') {
      cueHalf();
    } else if (k == 'count') {
      cueCount(3);
      Timer(const Duration(seconds: 1), () => cueCount(2));
      Timer(const Duration(seconds: 2), () => cueCount(1));
    } else if (k == 'start') {
      cueStart();
    } else {
      cueRest();
    }
  }

  void _onSegStart(Seg g) {
    if (g.kind == 'work' && g.tempo.isNotEmpty) {
      if (cue('start').on) {
        audio.speak(RegExp(r'^\d').hasMatch(g.tempo) ? 'Tempo ${g.tempo.replaceAll('-', ' ')}' : g.tempo, cue('start').vol);
      }
      _flash();
    } else if (g.kind == 'work' || g.kind == 'finisher') {
      cueStart();
    } else if (g.kind == 'rest') {
      cueRest();
    }
  }

  void _tick() {
    if (tl.segs.isEmpty) return;
    if (t.running) {
      var g = seg!;
      var e = (_now - t.startAt) / 1000;
      while (e >= g.dur) {
        if (g.waitAfter || t.idx >= tl.segs.length - 1) {
          t.running = false;
          t.paused = g.dur.toDouble();
          if (t.idx >= tl.segs.length - 1) {
            t.finished = true;
            ui?.toast('Class complete. Nice work!');
          } else {
            t.waiting = true;
            t.waitAt = t.startAt + g.dur * 1000;
            if (g.kind == 'warmup') _autoBrief = true;
          }
          saveSession();
          break;
        }
        t.startAt += g.dur * 1000;
        t.idx++;
        t.fired = {};
        g = seg!;
        e = (_now - t.startAt) / 1000;
        if (e < 1.5) _onSegStart(g);
        if (g.kind == 'break' && e < 5) _autoBrief = true;
        saveSession();
      }
      if (t.running) {
        final half = g.dur / 2;
        if (g.hasHalf && half < g.dur - 3.5 && !t.fired.contains('h') && e >= half) {
          t.fired.add('h');
          if (e - half < 1.5) cueHalf();
        }
        if (g.dur > 4) {
          for (final n in const [3, 2, 1]) {
            final th = g.dur - n;
            if (!t.fired.contains('c$n') && e >= th) {
              t.fired.add('c$n');
              if (e - th < 1.2) cueCount(n);
            }
          }
        }
      }
    }
    _bumpTick();
    if (_autoBrief) {
      _autoBrief = false;
      if (!workoutSheetOpen) ui?.openWorkout(auto: true);
    }
  }

  void _bumpTick() {
    tick.value++;
    segKey.value = '${t.idx}|${t.waiting}|${t.finished}|${t.running}|${tl.sig.hashCode}';
  }

  void goTo(int i, bool keepRunning) {
    if (tl.segs.isEmpty) return;
    i = clampT(i, 0, tl.segs.length - 1);
    final run = keepRunning && !t.finished;
    t.idx = i;
    t.waiting = false;
    t.finished = false;
    t.fired = {};
    t.paused = 0;
    t.running = run;
    if (run) {
      t.startAt = _now;
      _onSegStart(seg!);
    }
    saveSession();
    _changedTimer();
  }

  void play() {
    if (tl.segs.isEmpty) return;
    if (!wlWanted) requestWake();
    if (t.finished) return goTo(0, false);
    if (t.waiting) return goTo(t.idx + 1, true);
    if (t.running) {
      t.paused = (_now - t.startAt) / 1000;
      t.running = false;
    } else {
      final fresh = t.paused == 0;
      t.startAt = _now - t.paused * 1000;
      t.running = true;
      if (fresh) _onSegStart(seg!);
    }
    saveSession();
    _changedTimer();
  }

  void back() {
    final e = elapsed;
    if (t.waiting) return goTo(t.idx, false);
    if (e > 3) {
      goTo(t.idx, t.running);
    } else {
      goTo(t.idx - 1, t.running);
    }
  }

  void skip() {
    if (t.idx < tl.segs.length - 1) goTo(t.idx + 1, t.running || t.waiting);
  }

  void resetEx() => goTo(t.idx, t.running);
  void resetBlock() {
    final g = seg;
    if (g != null) goTo(tl.sections[g.secIdx].start, false);
  }

  void plus30() {
    final g = seg;
    if (g == null || g.kind != 'break') return;
    if (t.waiting) {
      final old = g.dur;
      g.dur += 30;
      t.waiting = false;
      t.running = true;
      t.startAt = _now - old * 1000;
    } else {
      g.dur += 30;
    }
    tl.rebuildStarts();
    saveSession();
    _changedTimer();
    ui?.toast('Break +30 s');
  }

  void _changedTimer() {
    _bumpTick();
    notifyListeners();
  }

  void resetTimer() => t.reset();

  void saveSession() {
    try {
      _sp?.setString(
          lsSession,
          jsonEncode({
            'sig': tl.sig,
            'idx': t.idx,
            'running': t.running,
            'startAt': t.startAt,
            'paused': t.paused,
            'waiting': t.waiting,
            'waitAt': t.waitAt,
            'at': _now,
            'durs': tl.segs.map((g) => g.dur).toList(),
          }));
    } catch (_) {}
  }

  bool _restoreSession() {
    try {
      final raw = _sp?.getString(lsSession);
      if (raw == null) return false;
      final s = jsonDecode(raw) as Map<String, dynamic>;
      final idx = (s['idx'] as num).toInt();
      final paused = (s['paused'] as num).toDouble();
      if (s['sig'] != tl.sig || _now - (s['at'] as num) > 3 * 3600e3 || !(idx > 0 || s['running'] == true || paused > 0)) {
        return false;
      }
      if (idx >= tl.segs.length) return false;
      final durs = s['durs'];
      if (durs is List && durs.length == tl.segs.length) {
        for (var i = 0; i < durs.length; i++) {
          tl.segs[i].dur = (durs[i] as num).toInt();
        }
        tl.rebuildStarts();
      }
      t
        ..idx = idx
        ..running = s['running'] == true
        ..startAt = (s['startAt'] as num).toDouble()
        ..paused = paused
        ..waiting = s['waiting'] == true
        ..waitAt = (s['waitAt'] as num? ?? 0).toDouble()
        ..fired = {};
      return true;
    } catch (_) {
      return false;
    }
  }

  // ================= wake lock =================
  Future<void> requestWake() async {
    wlWanted = true;
    try {
      await WakelockPlus.enable();
      wlStatus = await WakelockPlus.enabled ? 'on' : 'failed';
    } catch (_) {
      wlStatus = 'failed';
    }
    notifyListeners();
  }

  Future<void> releaseWake() async {
    wlWanted = false;
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    wlStatus = 'off';
    notifyListeners();
  }

  // ================= class view helpers =================
  String captionFor(Seg g) {
    switch (g.kind) {
      case 'work':
        if (g.tempo.isNotEmpty) return 'Tempo ${g.tempo}${g.note.isNotEmpty ? ' · ${g.note}' : ''} · ${g.i + 1}/${g.n}';
        return 'Round ${g.r + 1}/${g.R} · Exercise ${g.i + 1}/${g.n}';
      case 'rest':
        if (g.wu) return 'Warm-up move ${g.k + 1}/${g.M} next';
        return 'Round ${g.r + 1}/${g.R} · Exercise ${g.i + 1}/${g.n}';
      case 'finisher':
        return 'Move ${g.k + 1}/${g.M}${g.FR > 1 ? ' · Round ${g.fr + 1}/${g.FR}' : ''}';
      case 'warmup':
        return 'Warm-up move ${g.k + 1}/${g.M}';
      case 'cooldown':
        return 'Stretch ${g.k + 1}/${g.M}${ex(g.ex).sides ? ' · switch sides at the beep' : ''}';
      case 'break':
        return 'Brief Block ${g.block + 2}';
    }
    return '';
  }

  String caption() {
    final g = seg;
    if (g == null) return '';
    final nxs = g.secIdx + 1 < tl.sections.length ? tl.sections[g.secIdx + 1] : null;
    if (t.finished) return 'Class complete';
    if (t.waiting) return nxs != null ? 'Tap play to start ${nxs.label}' : 'Tap play';
    if (!t.running && t.paused == 0 && t.idx == 0) return 'Tap play to start';
    return captionFor(g);
  }

  String segName(Seg g) => ex(g.ex).name + (g.kind == 'warmup' && g.note.isNotEmpty ? ' · ${g.note}' : '');

  ({String text, String? id}) nextInfo(int idx) {
    final g = tl.segs[idx];
    for (var j = idx + 1; j < tl.segs.length; j++) {
      final n = tl.segs[j];
      if (n.kind == 'rest') continue;
      if (n.kind == 'break') return (text: 'Break', id: null);
      if (n.kind == 'cooldown' && g.kind != 'cooldown') return (text: 'Cool-down', id: null);
      return (text: segName(n) + (n.tempo.isNotEmpty ? ' · ${n.tempo}' : ''), id: n.ex);
    }
    return (text: 'Class complete', id: null);
  }

  /// name: big label; act: exercise id, 'brief' or null; next: next-up info
  ({String name, String? act, ({String text, String? id})? next}) nowView() {
    final g = seg;
    if (g == null) return (name: 'No exercises in this plan', act: null, next: null);
    final nx = g.secIdx + 1 < tl.sections.length ? tl.sections[g.secIdx + 1] : null;
    if (t.finished) return (name: 'Class complete', act: null, next: null);
    if (t.waiting) {
      final name = nx != null && nx.kind == 'block'
          ? 'Brief Block ${nx.block + 1}: ${themeName(nx.theme)}'
          : nx != null
              ? 'Get ready: ${nx.label}'
              : 'Ready';
      return (name: name, act: 'brief', next: nextInfo(t.idx));
    }
    if (g.kind == 'break') {
      return (
        name: 'Break: brief Block ${g.block + 2}${nx != null && nx.theme != null ? ' · ${themeName(nx.theme)}' : ''}',
        act: 'brief',
        next: nextInfo(t.idx)
      );
    }
    if (g.kind == 'rest') return (name: 'Rest', act: null, next: nextInfo(t.idx));
    return (name: segName(g), act: g.ex, next: nextInfo(t.idx));
  }

  String classTitle() {
    final k = K;
    return k.saved ? '${k.name} · ${presetLabel()}' : '${weekLabel()} · ${presetLabel()}';
  }

  // ================= generator =================
  bool avail(Exercise e) => e.equip.every((q) => db.equipment[q] == true);
  bool isBW(Exercise e) => e.equip.every((q) => q == 'bw' || q == 'mat');
  bool comboOK(Exercise e) => db.allowCombo || !e.combo;
  List<Exercise> byType(String t) => db.library.where((e) => e.type == t).toList();
  T _pick<T>(List<T> a) => a[_rnd.nextInt(a.length)];

  Set<String> lastIds(int w) => {for (final h in db.history) if (h.weekNo == w - 1) ...h.ids};
  Set<String> recentIds(int w) => {for (final h in db.history) if (h.weekNo >= w - 2 && h.weekNo < w) ...h.ids};
  List<String> themeRegions(String t) => (kThemes[t] ?? kThemes['full']!).slots.expand((x) => x).toSet().toList();
  bool cardioSlot(Settings s, String t, int i, int n) => s.finMoves == 0 && n >= 4 && i == n - 1 && t != 'core';
  List<List<String>> slotsFor(String t, int n) {
    final sl = (kThemes[t] ?? kThemes['full']!).slots;
    return List.generate(n, (i) => sl[i % sl.length]);
  }

  String? _pickResistance(List<String> group, String theme, _GenCtx ctx, String where) {
    final tr = themeRegions(theme);
    bool prim(Exercise e) => e.regions.isNotEmpty && group.contains(e.regions[0]);
    bool inT(Exercise e) => e.regions.isNotEmpty && tr.contains(e.regions[0]);
    bool fresh(Exercise e) => !ctx.recent.contains(e.id);
    final pool = byType('resistance').where((e) => comboOK(e) && !ctx.used.contains(e.id)).toList();
    final gl = group.map((r) => kRegionLabel[r] ?? r).join('/');
    final tiers = <(bool Function(Exercise), String)>[
      ((e) => prim(e) && avail(e) && fresh(e), ''),
      ((e) => prim(e) && isBW(e) && fresh(e), 'bw'),
      ((e) => inT(e) && avail(e) && fresh(e), ''),
      ((e) => inT(e) && isBW(e) && fresh(e), 'bw'),
      ((e) => prim(e) && (avail(e) || isBW(e)), 'repeat'),
      ((e) => inT(e) && (avail(e) || isBW(e)), 'repeat'),
      ((e) => true, 'any'),
    ];
    for (final (f, kind) in tiers) {
      final c = pool.where(f).toList();
      if (c.isEmpty) continue;
      final e = _pick(c);
      ctx.used.add(e.id);
      if (kind == 'bw') ctx.notes.add('$where: not enough $gl exercises for your equipment, so bodyweight was used: ${e.name}.');
      if (kind == 'repeat') ctx.notes.add('$where: ${e.name} repeats from the last 2 weeks (not enough fresh $gl options).');
      if (kind == 'any') ctx.notes.add('$where: no suitable $gl exercise, so ${e.name} was picked. Add more in the Library.');
      return e.id;
    }
    ctx.notes.add('$where: the library has no resistance exercises left.');
    return null;
  }

  int _matLast(String a, String b) => (ex(a).equip.contains('mat') ? 1 : 0) - (ex(b).equip.contains('mat') ? 1 : 0);

  List<String> _pickFinisher(int n, _GenCtx ctx, String where) {
    final ids = <String>[];
    var rec = 0;
    for (var i = 0; i < n; i++) {
      final pool = byType('cardio').where((e) => !ctx.used.contains(e.id)).toList();
      bool fresh(Exercise e) => !ctx.recent.contains(e.id);
      bool notLast(Exercise e) => !ctx.last.contains(e.id);
      final tiers = <(bool Function(Exercise), String)>[
        ((e) => avail(e) && fresh(e), ''),
        ((e) => avail(e) && notLast(e) && rec < 2, 'ok'),
        ((e) => avail(e) && rec < 2, 'ok'),
        ((e) => isBW(e) && fresh(e), 'bw'),
        ((e) => avail(e) && notLast(e), 'repeat'),
        ((e) => avail(e) || isBW(e), 'repeat'),
        ((e) => true, 'any'),
      ];
      Exercise? got;
      for (final (f, kind) in tiers) {
        final c = pool.where(f).toList();
        if (c.isEmpty) continue;
        final e = _pick(c);
        got = e;
        ctx.used.add(e.id);
        if (ctx.recent.contains(e.id)) rec++;
        if (kind == 'bw') ctx.notes.add('$where: not enough cardio moves for your equipment, so bodyweight was used: ${e.name}.');
        if (kind == 'repeat' || kind == 'any') {
          ctx.notes.add('$where: ${e.name} repeats from recent weeks (not enough fresh cardio moves).');
        }
        break;
      }
      if (got != null) {
        ids.add(got.id);
      } else {
        ctx.notes.add('$where: ran out of cardio moves.');
      }
    }
    ids.sort(_matLast);
    return ids;
  }

  void _pickFinishersRR(List<Block> blocks, int n, _GenCtx ctx) {
    // round-robin so fresh moves spread evenly; repeats come from last week first
    final rec = List.filled(blocks.length, 0);
    for (var k = 0; k < n; k++) {
      for (var bi = 0; bi < blocks.length; bi++) {
        final b = blocks[bi];
        final pool = byType('cardio').where((e) => !ctx.used.contains(e.id)).toList();
        bool fresh(Exercise e) => !ctx.recent.contains(e.id);
        bool inLast(Exercise e) => ctx.last.contains(e.id);
        final tiers = <(bool Function(Exercise), String)>[
          ((e) => avail(e) && fresh(e), ''),
          ((e) => avail(e) && inLast(e) && rec[bi] < 2, ''),
          ((e) => avail(e) && rec[bi] < 2, ''),
          ((e) => isBW(e) && fresh(e), 'bw'),
          ((e) => avail(e) || isBW(e), 'repeat'),
          ((e) => true, 'repeat'),
        ];
        for (final (f, kind) in tiers) {
          final c = pool.where(f).toList();
          if (c.isEmpty) continue;
          final e = _pick(c);
          ctx.used.add(e.id);
          if (ctx.recent.contains(e.id)) rec[bi]++;
          b.fin.add(e.id);
          if (kind == 'bw') ctx.notes.add('Finisher ${bi + 1}: not enough cardio moves for your equipment, so bodyweight was used: ${e.name}.');
          if (kind == 'repeat') ctx.notes.add('Finisher ${bi + 1}: ${e.name} repeats from recent weeks (not enough fresh cardio moves).');
          break;
        }
      }
    }
    for (final b in blocks) {
      b.fin.sort(_matLast);
    }
  }

  List<String> _pickWuCd(String type, int n, int w) {
    final set = ((w - 1) % 3) + 1, all = byType(type);
    final main = all.where((e) => e.set == set), rest = all.where((e) => e.set != set);
    return [...main, ...rest].take(n).map((e) => e.id).toList();
  }

  List<String> themesFor(int w, int n) {
    final c = (w / 4).ceil(), set = kThemeSets[(c - 1) % kThemeSets.length], cw = (w - 1) % 4;
    final non = set.where((t) => t != 'core').toList(), hasCore = set.contains('core');
    final rot = List.generate(non.length, (i) => non[(i + cw) % non.length]);
    var arr = hasCore ? [...rot, 'core'] : [...rot];
    if (n < arr.length) arr = hasCore ? [...rot.take(n - 1), 'core'] : rot.take(n).toList();
    while (arr.length < n) {
      arr.insert(hasCore ? arr.length - 1 : arr.length, 'full');
    }
    return arr;
  }

  Plan _generate(int w, List<String> themes) {
    final s = db.settings, ctx = _GenCtx({}, recentIds(w), lastIds(w));
    final blocks = <Block>[];
    for (var bi = 0; bi < themes.length; bi++) {
      final t = themes[bi];
      final slots = slotsFor(t, s.exPerBlock);
      final exs = <String>[];
      for (var i = 0; i < slots.length; i++) {
        final id = cardioSlot(s, t, i, s.exPerBlock)
            ? (_pickFinisher(1, ctx, 'Block ${bi + 1}').firstOrNull)
            : _pickResistance(slots[i], t, ctx, 'Block ${bi + 1}');
        if (id != null) exs.add(id);
      }
      blocks.add(Block(theme: t, ex: exs));
    }
    _pickFinishersRR(blocks, s.finMoves, ctx);
    return Plan(
      weekNo: w,
      blocks: blocks,
      warmup: _pickWuCd('warmup', s.wuMoves, w),
      cooldown: _pickWuCd('cooldown', s.cdMoves, w),
      notes: ctx.notes,
    );
  }

  /// Grows / shrinks the edited plan to match its settings.
  void ensureShape() {
    final e = E, s = e.s, p = e.p;
    final ctx = _GenCtx(p.ids.toSet(), e.saved ? {} : recentIds(p.weekNo), e.saved ? {} : lastIds(p.weekNo));
    if (p.blocks.length > s.blocks) p.blocks.length = s.blocks;
    if (p.blocks.length < s.blocks) {
      final th = themesFor(p.weekNo, s.blocks);
      for (var i = p.blocks.length; i < s.blocks; i++) {
        p.blocks.add(Block(theme: th[i]));
      }
    }
    for (var bi = 0; bi < p.blocks.length; bi++) {
      final b = p.blocks[bi];
      final sl = slotsFor(b.theme, s.exPerBlock);
      if (b.ex.length > s.exPerBlock) b.ex.length = s.exPerBlock;
      for (var i = b.ex.length; i < s.exPerBlock; i++) {
        final id = cardioSlot(s, b.theme, i, s.exPerBlock)
            ? _pickFinisher(1, ctx, 'Block ${bi + 1}').firstOrNull
            : _pickResistance(sl[i], b.theme, ctx, 'Block ${bi + 1}');
        if (id == null) break;
        b.ex.add(id);
      }
      if (b.fin.length > s.finMoves) b.fin.length = s.finMoves;
      if (b.fin.length < s.finMoves) b.fin.addAll(_pickFinisher(s.finMoves - b.fin.length, ctx, 'Finisher ${bi + 1}'));
      if (s.isTempo) b.normTracks();
    }
    void fill(List<String> arr, String type, int n) {
      if (arr.length > n) arr.length = n;
      final extra = byType(type).where((e) => !arr.contains(e.id)).toList();
      while (arr.length < n && extra.isNotEmpty) {
        arr.add(extra.removeAt(0).id);
      }
    }

    fill(p.warmup, 'warmup', s.wuMoves);
    fill(p.cooldown, 'cooldown', s.cdMoves);
    if (ctx.notes.isNotEmpty) p.notes = [...p.notes, ...ctx.notes];
  }

  // ================= plan editing =================
  void changedQuiet() {
    if (!E.saved) db.plan.status = 'draft';
    buildTimeline();
    save();
  }

  void changed([String? msg]) {
    if (!E.saved) db.plan.status = 'draft';
    lib = _libMap();
    buildTimeline();
    save();
    _changedTimer();
    if (msg != null) ui?.toast(msg);
  }

  void notify() => notifyListeners();

  void stepSetting(String key, int d, int min, int max) {
    final s = E.s;
    if (key.startsWith('ladder')) {
      final i = int.parse(key.substring(6));
      s.ladder[i] = clampT(s.ladder[i] + d, min, max);
      s.preset = 'custom';
      return changed();
    }
    final old = s.getInt(key), nv = clampT(old + d, min, max);
    if (nv == old) return;
    if (const ['finMoves', 'finWork', 'finRounds'].contains(key)) {
      final tmp = Settings.fromJson(s.toJson())..setInt(key, nv);
      if (tmp.finSec > 450) return ui?.toast('Finisher maximum is 7:30');
    }
    if (key == 'exPerBlock' && s.keepLength && !s.isLadder && !s.isTempo) {
      final r0 = s.rounds * old * (s.work + s.rest), slot = (r0 / (s.rounds * nv)).round(), ratio = s.work / s.rest;
      var w = ((slot * ratio / (ratio + 1)) / 5).round() * 5, r = slot - w;
      if (r <= 0 || w / r < 2.95 || w / r > 4.05) {
        w = (slot * ratio / (ratio + 1)).round();
        r = slot - w;
      }
      s.work = math.max(10, w);
      s.rest = math.max(5, r);
      ui?.toast('Work/rest is now ${s.work}/${s.rest} s to keep the block length');
    }
    s.setInt(key, nv);
    if (const ['work', 'rest', 'rounds'].contains(key)) s.preset = 'custom';
    ensureShape();
    changed();
  }

  void _applyPreset(Settings s, String k) {
    final pr = kPresets[k]!;
    s.preset = k;
    s.format = pr.format;
    s.rest = pr.rest;
    s.exPerBlock = pr.exPerBlock;
    if (pr.work != null) s.work = pr.work!;
    if (pr.rounds != null) s.rounds = pr.rounds!;
    if (pr.ladder != null) s.ladder = [...pr.ladder!];
  }

  void setPreset(String k) {
    _applyPreset(E.s, k);
    ensureShape();
    changed('${kPresets[k]!.label} applied');
  }

  Future<void> regenerate() async {
    if (db.plan.status == 'saved' &&
        !(await ui!.confirm('Replace this week?', 'This week is saved. Replace it with a new draft?', 'Replace'))) {
      return;
    }
    final th = db.plan.blocks.map((b) => b.theme).toList();
    while (th.length < db.settings.blocks) {
      th.add('full');
    }
    db.plan = _generate(db.plan.weekNo, th.take(db.settings.blocks).toList());
    changed(db.plan.notes.isNotEmpty ? 'New draft with notes, review below' : 'New draft created, review and save');
  }

  void saveWeek({bool quiet = false}) {
    final p = db.plan;
    db.history.removeWhere((h) => h.weekNo == p.weekNo);
    db.history.add(HistoryEntry(p.weekNo, p.ids, today()));
    db.history.sort((a, b) => a.weekNo - b.weekNo);
    if (db.history.length > 60) db.history = db.history.sublist(db.history.length - 60);
    p.status = 'saved';
    save();
    if (!quiet) ui?.toast('Week ${p.weekNo} saved');
    notifyListeners();
  }

  void nextWeek() {
    if (db.plan.status != 'saved') saveWeek(quiet: true);
    final w = db.plan.weekNo + 1, k = kCyclePreset[(w - 1) % 4], s = db.settings;
    _applyPreset(s, k);
    db.plan = _generate(w, themesFor(w, s.blocks));
    if (!K.saved) t.reset();
    changed('Week $w drafted (${kPresets[k]!.label}). Review and save.');
  }

  void setWeek(int v) {
    db.plan.weekNo = v;
    changed('Now Week $v');
  }

  void dismissNotes() {
    E.p.notes = [];
    save();
    notifyListeners();
  }

  Future<void> setTheme(int bi, String theme) async {
    final b = E.p.blocks[bi];
    b.theme = theme;
    if (await ui!.confirm('Refill block?', 'Refill Block ${bi + 1} with ${kThemes[theme]!.label} exercises?', 'Refill')) {
      b.ex = [];
      b.dur = null;
      b.tempo = null;
      b.note = null;
      ensureShape();
    }
    changed();
  }

  void trkSet(int bi, int i, String key, Object val) {
    if (bi >= E.p.blocks.length) return;
    final b = E.p.blocks[bi];
    b.normTracks();
    if (i >= b.ex.length) return;
    switch (key) {
      case 'dur':
        b.dur![i] = val as int;
      case 'tempo':
        b.tempo![i] = val as String;
      case 'note':
        b.note![i] = val as String;
    }
  }

  void trkDur(int bi, int i, int d) {
    if (bi >= E.p.blocks.length) return;
    final b = E.p.blocks[bi];
    trkSet(bi, i, 'dur', clampT(b.trk(i).dur + d, 15, 300));
    changed();
  }

  List<String> slotList(String sec, int b) {
    final p = E.p;
    return switch (sec) {
      'wu' => p.warmup,
      'cd' => p.cooldown,
      'ex' => p.blocks[b].ex,
      _ => p.blocks[b].fin,
    };
  }

  void doSwap(String sec, int b, int i, String id) {
    slotList(sec, b)[i] = id;
    changed('Swapped in ${ex(id).name}');
  }

  List<String> missingIn(Plan p) => p.allIds.where((id) => !lib.containsKey(id)).toList();

  // ================= library =================
  void libSave(Exercise e, {required bool isNew}) {
    final i = db.library.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      db.library[i] = e;
    } else {
      db.library.add(e);
    }
    changed(isNew ? 'Exercise added' : 'Exercise updated');
  }

  bool libInUse(String id) => [db.plan, db.wk?.plan].whereType<Plan>().any((p) => p.allIds.contains(id));

  void libDelete(String id) {
    db.library.removeWhere((e) => e.id == id);
    changed('Deleted');
  }

  void resetLibrary() {
    db.library = starterLibrary();
    lib = _libMap();
    ensureShape();
    changed('Library reset');
  }

  void resetAll() {
    db = freshDB();
    planMode = 'week';
    save(now: true);
    lib = _libMap();
    resetTimer();
    tl = Timeline.empty();
    buildTimeline();
    _changedTimer();
    ui?.toast('Everything reset');
  }

  // ================= saved workouts =================
  Snapshot snapOf(Ctx c) {
    final p = c.p.clone()
      ..notes = []
      ..status = 'draft';
    return Snapshot(Settings.fromJson(c.s.toJson()), p);
  }

  SavedWorkout? savedRec(String id) => db.saved.where((w) => w.id == id).firstOrNull;

  bool wkDirty() {
    final wk = db.wk;
    final r = wk != null ? savedRec(wk.id) : null;
    if (r == null) return false;
    return jsonEncode(snapOf(Ctx(wk!.settings, wk.plan, '', true)).toJson()) != jsonEncode(r.snap.toJson());
  }

  Future<bool> guardLoad(String label) async {
    final d = wkDirty(), b = timerBusy;
    if (!d && !b) return true;
    final msg = [
      if (d) 'The loaded workout has unsaved changes that will be discarded.',
      if (b) 'The class timer will go back to the start.',
    ].join(' ');
    return ui!.confirm(label, msg, 'Continue');
  }

  void saveNew(String name) {
    db.saved.add(SavedWorkout(id: newId(), name: name, saved: today(), snap: snapOf(E)));
    save(now: true);
    ui?.toast('Saved "$name"');
    notifyListeners();
  }

  void applyActive(String? id) {
    final r = id != null ? savedRec(id) : null;
    if (r == null) {
      db.activeId = null;
      db.wk = null;
    } else {
      final sn = r.snap.clone();
      db.activeId = r.id;
      db.wk = ActiveWorkout(id: r.id, name: r.name, settings: sn.settings, plan: sn.plan);
    }
    resetTimer();
    lib = _libMap();
    buildTimeline();
    save(now: true);
    _changedTimer();
  }

  Future<void> swLoad(String id) async {
    final r = savedRec(id);
    if (r == null) return;
    if (db.activeId == id && !wkDirty() && !timerBusy) {
      planMode = 'saved';
      notifyListeners();
      return;
    }
    if (!await guardLoad('Load "${r.name}"?')) return;
    applyActive(id);
    planMode = 'saved';
    final miss = missingIn(r.snap.plan).length;
    ui?.toast(miss > 0 ? 'Loaded. $miss exercise${miss > 1 ? 's are' : ' is'} no longer in the library.' : 'Loaded "${r.name}"');
    notifyListeners();
  }

  /// Returns true if the class tab should be shown.
  Future<bool> quickPick(String id) async {
    final r = savedRec(id);
    if (r == null) return false;
    final d = wkDirty(), b = timerBusy, same = db.activeId == id;
    final extra = [
      if (d && !same) 'The loaded workout has unsaved changes that will be discarded.',
      if (b && !same) 'The class timer will go back to the start.',
    ].join(' ');
    final ok = await ui!.confirm(
        "Update today's workout?",
        'Use "${r.name}" (${fmtM(planTotal(r.snap.settings, r.snap.plan))}) as today\'s workout and go to the timer.${extra.isNotEmpty ? ' $extra' : ''}',
        'Yes, use this workout');
    if (!ok) return false;
    if (!same) applyActive(id);
    ui?.toast('"${r.name}" is ready. Tap play to start');
    return true;
  }

  void swRename(String id, String name) {
    final r = savedRec(id);
    if (r == null) return;
    r.name = name;
    if (db.wk?.id == id) db.wk!.name = name;
    save(now: true);
    notifyListeners();
  }

  void swDup(String id) {
    final r = savedRec(id);
    if (r == null) return;
    db.saved.add(SavedWorkout(id: newId(), name: '${r.name} copy', saved: today(), snap: r.snap.clone()));
    save(now: true);
    ui?.toast('Duplicated');
    notifyListeners();
  }

  Future<void> swOver(String id) async {
    final r = savedRec(id);
    if (r == null) return;
    final c = E;
    if (!await ui!.confirm('Overwrite?', 'Overwrite "${r.name}" with ${c.saved ? 'the loaded workout' : 'the weekly draft'} as it is now?', 'Overwrite')) {
      return;
    }
    if (db.wk?.id == id && !c.saved) {
      if (timerBusy && !await ui!.confirm('Reset timer?', 'This resets the class timer. Continue?', 'Continue')) return;
      r.snap = snapOf(c);
      r.saved = today();
      applyActive(id);
    } else {
      r.snap = snapOf(c);
      r.saved = today();
    }
    save(now: true);
    ui?.toast('Saved "${r.name}"');
    notifyListeners();
  }

  Future<void> swDel(String id) async {
    final r = savedRec(id);
    if (r == null) return;
    if (!await ui!.confirm('Delete workout?', 'Delete "${r.name}"? This can\'t be undone.', 'Delete', danger: true)) return;
    if (db.activeId == id) {
      if (timerBusy && !await ui!.confirm('Reset timer?', 'It is active on the Class tab. Deleting it resets the timer. Continue?', 'Continue')) {
        return;
      }
      db.activeId = null;
      db.wk = null;
      resetTimer();
      planMode = 'week';
    }
    db.saved.removeWhere((w) => w.id == id);
    lib = _libMap();
    buildTimeline();
    save(now: true);
    ui?.toast('Deleted');
    _changedTimer();
  }

  Future<void> useWeekly() async {
    if (!await guardLoad('Run the weekly program?')) return;
    db.activeId = null;
    db.wk = null;
    planMode = 'week';
    resetTimer();
    buildTimeline();
    save(now: true);
    _changedTimer();
    ui?.toast('Class tab runs the weekly program');
  }

  // ================= prefs =================
  void setPrefs(void Function(Prefs p) fn) {
    fn(db.prefs);
    save();
    notifyListeners();
  }

  Future<void> setAudioMode(String m) async {
    db.prefs.audioMode = m;
    save();
    notifyListeners();
    await audio.setMode(m);
    ui?.toast('Now test with your music playing');
  }

  void setEquipment(String k, bool on) {
    db.equipment[k] = on;
    save();
    notifyListeners();
    ui?.toast('${kEqLabel[k]} ${on ? 'on' : 'off'}. Regenerate or swap to apply.');
  }

  void setCombo(bool on) {
    db.allowCombo = on;
    save();
    notifyListeners();
  }

  void setKeepLength(bool on) {
    E.s.keepLength = on;
    save();
    notifyListeners();
  }

  // ================= backup =================
  String exportJson() {
    final m = {'app': 'circuit-coach', 'exported': DateTime.now().toIso8601String(), ...db.toJson()};
    return const JsonEncoder.withIndent(' ').convert(m);
  }

  void markBackedUp() {
    db.prefs.lastBackup = today();
    save();
    notifyListeners();
  }

  /// Validates a backup. Returns an error message or null.
  String? validateBackup(String text) {
    dynamic d;
    try {
      d = jsonDecode(text);
    } catch (_) {
      return 'That file is not valid JSON';
    }
    if (d is! Map || d['library'] is! List || d['plan'] is! Map || (d['plan'] as Map)['blocks'] is! List) {
      return "That doesn't look like a Circuit Coach backup";
    }
    return null;
  }

  Future<void> importData(String text) async {
    final err = validateBackup(text);
    if (err != null) return ui?.toast(err);
    final d = (jsonDecode(text) as Map).cast<String, dynamic>();
    db = _fromJson(d);
    _normDB();
    save(now: true);
    lib = _libMap();
    resetTimer();
    planMode = db.wk != null ? 'saved' : 'week';
    tl = Timeline.empty();
    buildTimeline();
    await audio.setMode(db.prefs.audioMode);
    _changedTimer();
    ui?.toast('Backup imported');
  }
}
