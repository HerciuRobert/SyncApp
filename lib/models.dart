import 'dart:convert';

import 'constants.dart';

int _i(dynamic v, int d) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? d : d);
double _d(dynamic v, double d) => v is num ? v.toDouble() : d;
bool _b(dynamic v, bool d) => v is bool ? v : d;
String _s(dynamic v, [String d = '']) => v == null ? d : v.toString();
List<String> _ls(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];
List<int>? _li(dynamic v) => v is List ? v.map((e) => _i(e, 0)).toList() : null;

class Exercise {
  String id, name, type, impact, regression, progression, lowImpact, setup, mistake, breath;
  List<String> regions, equip, cues;
  bool combo, sides;
  int set;

  Exercise({
    required this.id,
    required this.name,
    this.type = 'resistance',
    List<String>? regions,
    List<String>? equip,
    this.impact = 'low',
    this.combo = false,
    this.regression = '',
    this.progression = '',
    this.lowImpact = '',
    this.setup = '',
    List<String>? cues,
    this.mistake = '',
    this.breath = '',
    this.set = 0,
    this.sides = false,
  })  : regions = regions ?? [],
        equip = equip ?? [],
        cues = cues ?? [''];

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: _s(j['id']),
        name: _s(j['name']),
        type: _s(j['type'], 'resistance'),
        regions: _ls(j['regions']),
        equip: _ls(j['equip']),
        impact: _s(j['impact'], 'low'),
        combo: _b(j['combo'], false),
        regression: _s(j['regression']),
        progression: _s(j['progression']),
        lowImpact: _s(j['lowImpact']),
        setup: _s(j['setup']),
        cues: j['cues'] is List && (j['cues'] as List).isNotEmpty ? _ls(j['cues']) : [''],
        mistake: _s(j['mistake']),
        breath: _s(j['breath']),
        set: _i(j['set'], 0),
        sides: _b(j['sides'], false),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'regions': regions,
        'equip': equip,
        'impact': impact,
        'combo': combo,
        'regression': regression,
        'progression': progression,
        'lowImpact': lowImpact,
        'setup': setup,
        'cues': cues,
        'mistake': mistake,
        'breath': breath,
        if (type == 'warmup' || type == 'cooldown') 'set': set,
        if (type == 'warmup' || type == 'cooldown') 'sides': sides,
      };

  static Exercise missing(String id) => Exercise(id: id, name: '(deleted exercise)');

  String get eqText => equip.map((q) => kEqLabel[q] ?? q).join(' + ');
  String get regText => regions.map((r) => kRegionLabel[r] ?? r).join(', ');
  String get typeLabel => switch (type) {
        'cardio' => 'Cardio',
        'warmup' => 'Warm-up',
        'cooldown' => 'Cool-down',
        _ => 'Resistance',
      };
}

class Settings {
  String preset, format;
  int work, rest, exPerBlock, rounds, finWork, finMoves, finRounds, breakSec, wuMoves, wuSec, cdMoves, cdSec, blocks;
  List<int> ladder;
  bool keepLength;

  Settings({
    this.preset = 'base',
    this.format = 'standard',
    this.work = 45,
    this.rest = 15,
    this.exPerBlock = 4,
    this.rounds = 2,
    List<int>? ladder,
    this.finWork = 30,
    this.finMoves = 0,
    this.finRounds = 1,
    this.breakSec = 120,
    this.wuMoves = 6,
    this.wuSec = 50,
    this.cdMoves = 5,
    this.cdSec = 60,
    this.blocks = 4,
    this.keepLength = true,
  }) : ladder = ladder ?? [30, 45, 60];

  factory Settings.fromJson(Map<String, dynamic>? j) {
    final d = Settings();
    if (j == null) return d;
    return Settings(
      preset: _s(j['preset'], d.preset),
      format: _s(j['format'], d.format),
      work: _i(j['work'], d.work),
      rest: _i(j['rest'], d.rest),
      exPerBlock: _i(j['exPerBlock'], d.exPerBlock),
      rounds: _i(j['rounds'], d.rounds),
      ladder: _li(j['ladder']) ?? d.ladder,
      finWork: _i(j['finWork'], d.finWork),
      finMoves: _i(j['finMoves'], d.finMoves),
      finRounds: _i(j['finRounds'], d.finRounds),
      breakSec: _i(j['breakSec'], d.breakSec),
      wuMoves: _i(j['wuMoves'], d.wuMoves),
      wuSec: _i(j['wuSec'], d.wuSec),
      cdMoves: _i(j['cdMoves'], d.cdMoves),
      cdSec: _i(j['cdSec'], d.cdSec),
      blocks: _i(j['blocks'], d.blocks),
      keepLength: _b(j['keepLength'], d.keepLength),
    );
  }

  Map<String, dynamic> toJson() => {
        'preset': preset,
        'format': format,
        'work': work,
        'rest': rest,
        'exPerBlock': exPerBlock,
        'rounds': rounds,
        'ladder': ladder,
        'finWork': finWork,
        'finMoves': finMoves,
        'finRounds': finRounds,
        'breakSec': breakSec,
        'wuMoves': wuMoves,
        'wuSec': wuSec,
        'cdMoves': cdMoves,
        'cdSec': cdSec,
        'blocks': blocks,
        'keepLength': keepLength,
      };

  int getInt(String key) => toJson()[key] as int;

  void setInt(String key, int v) {
    switch (key) {
      case 'work':
        work = v;
      case 'rest':
        rest = v;
      case 'exPerBlock':
        exPerBlock = v;
      case 'rounds':
        rounds = v;
      case 'finWork':
        finWork = v;
      case 'finMoves':
        finMoves = v;
      case 'finRounds':
        finRounds = v;
      case 'breakSec':
        breakSec = v;
      case 'wuMoves':
        wuMoves = v;
      case 'wuSec':
        wuSec = v;
      case 'cdMoves':
        cdMoves = v;
      case 'cdSec':
        cdSec = v;
      case 'blocks':
        blocks = v;
    }
  }

  bool get isTempo => format == 'tempo';
  bool get isLadder => format == 'ladder';
  int get finSec => finMoves * finWork * finRounds;
}

class Block {
  String theme;
  List<String> ex, fin;
  int? work, rest;
  List<int>? dur;
  List<String>? tempo, note;

  Block({required this.theme, List<String>? ex, List<String>? fin, this.work, this.rest, this.dur, this.tempo, this.note})
      : ex = ex ?? [],
        fin = fin ?? [];

  factory Block.fromJson(Map<String, dynamic> j) => Block(
        theme: _s(j['theme'], 'full'),
        ex: _ls(j['ex']),
        fin: _ls(j['fin']),
        work: j['work'] is num && (j['work'] as num) > 0 ? _i(j['work'], 0) : null,
        rest: j['rest'] is num && (j['rest'] as num) > 0 ? _i(j['rest'], 0) : null,
        dur: _li(j['dur']),
        tempo: j['tempo'] is List ? _ls(j['tempo']) : null,
        note: j['note'] is List ? _ls(j['note']) : null,
      );

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'ex': ex,
        'fin': fin,
        if (work != null) 'work': work,
        if (rest != null) 'rest': rest,
        if (dur != null) 'dur': dur,
        if (tempo != null) 'tempo': tempo,
        if (note != null) 'note': note,
      };

  /// Track info for tempo blocks.
  ({int dur, String tempo, String note}) trk(int i) => (
        dur: (dur != null && i < dur!.length && dur![i] > 0) ? dur![i] : 60,
        tempo: (tempo != null && i < tempo!.length) ? tempo![i] : '',
        note: (note != null && i < note!.length) ? note![i] : '',
      );

  String trkText(int i) {
    final q = trk(i);
    return '${q.dur} s · Tempo ${q.tempo.isEmpty ? 'free' : q.tempo}${q.note.isNotEmpty ? ' · ${q.note}' : ''}';
  }

  int get tempoSec {
    var a = 0;
    for (var i = 0; i < ex.length; i++) {
      a += trk(i).dur;
    }
    return a;
  }

  /// Make sure the per-track arrays exist and match the number of exercises.
  void normTracks() {
    dur ??= [];
    tempo ??= [];
    note ??= [];
    while (dur!.length < ex.length) {
      dur!.add(60);
    }
    while (tempo!.length < ex.length) {
      tempo!.add('');
    }
    while (note!.length < ex.length) {
      note!.add('');
    }
    if (dur!.length > ex.length) dur!.length = ex.length;
    if (tempo!.length > ex.length) tempo!.length = ex.length;
    if (note!.length > ex.length) note!.length = ex.length;
  }
}

class Plan {
  int weekNo;
  String status;
  List<Block> blocks;
  List<String> warmup, cooldown, notes;
  List<int>? wuSec;
  List<String>? wuNote;
  int wuRest;

  Plan({
    this.weekNo = 1,
    this.status = 'draft',
    List<Block>? blocks,
    List<String>? warmup,
    List<String>? cooldown,
    List<String>? notes,
    this.wuSec,
    this.wuNote,
    this.wuRest = 0,
  })  : blocks = blocks ?? [],
        warmup = warmup ?? [],
        cooldown = cooldown ?? [],
        notes = notes ?? [];

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        weekNo: _i(j['weekNo'], 1),
        status: _s(j['status'], 'draft'),
        blocks: j['blocks'] is List
            ? (j['blocks'] as List).whereType<Map>().map((b) => Block.fromJson(b.cast<String, dynamic>())).toList()
            : [],
        warmup: _ls(j['warmup']),
        cooldown: _ls(j['cooldown']),
        notes: _ls(j['notes']),
        wuSec: _li(j['wuSec']),
        wuNote: j['wuNote'] is List ? _ls(j['wuNote']) : null,
        wuRest: _i(j['wuRest'], 0),
      );

  Map<String, dynamic> toJson() => {
        'weekNo': weekNo,
        'status': status,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'warmup': warmup,
        'cooldown': cooldown,
        'notes': notes,
        if (wuSec != null) 'wuSec': wuSec,
        if (wuNote != null) 'wuNote': wuNote,
        if (wuRest > 0) 'wuRest': wuRest,
      };

  Plan clone() => Plan.fromJson(jsonDecode(jsonEncode(toJson())) as Map<String, dynamic>);

  List<String> get ids => [for (final b in blocks) ...b.ex, for (final b in blocks) ...b.fin];
  List<String> get allIds => [...ids, ...warmup, ...cooldown];

  int wuDur(Settings s, int k) => (wuSec != null && k < wuSec!.length && wuSec![k] > 0) ? wuSec![k] : s.wuSec;
  int get wuRestSec => wuRest > 0 ? wuRest : 0;
  String wuNoteAt(int k) => (wuNote != null && k < wuNote!.length) ? wuNote![k] : '';
  int wuTotal(Settings s) {
    var t = 0;
    for (var k = 0; k < warmup.length; k++) {
      t += wuDur(s, k);
    }
    return t + wuRestSec * (warmup.isEmpty ? 0 : warmup.length - 1);
  }
}

int blockResSec(Settings s, int nEx, [Block? b]) {
  final wk = b?.work ?? s.work, rs = b?.rest ?? s.rest;
  if (s.isLadder) return nEx * s.ladder.fold<int>(0, (a, w) => a + w + rs);
  return nEx * s.rounds * (wk + rs);
}

int planTotal(Settings s, Plan p) {
  var t = p.wuTotal(s) + s.cdMoves * s.cdSec + (s.isTempo ? 0 : (p.blocks.length - 1) * s.breakSec);
  for (final b in p.blocks) {
    t += (s.isTempo ? b.tempoSec : blockResSec(s, b.ex.length, b)) + s.finSec;
  }
  return t;
}

class CueCfg {
  bool on;
  double vol;
  String text;
  CueCfg({this.on = true, this.vol = 1, this.text = ''});
  factory CueCfg.fromJson(Map<String, dynamic>? j, CueCfg d) =>
      j == null ? d : CueCfg(on: _b(j['on'], d.on), vol: _d(j['vol'], d.vol), text: _s(j['text'], d.text));
  Map<String, dynamic> toJson() => {'on': on, 'vol': vol, if (text.isNotEmpty) 'text': text};
}

class Prefs {
  String audioMode, accent;
  bool flash, seenSilent;
  int digitW;
  String? lastBackup;
  Map<String, CueCfg> cues;

  Prefs({
    this.audioMode = 'ambient',
    this.accent = 'mint',
    this.flash = true,
    this.seenSilent = false,
    this.digitW = 200,
    this.lastBackup,
    Map<String, CueCfg>? cues,
  }) : cues = cues ?? defaultCues();

  static Map<String, CueCfg> defaultCues() => {
        'half': CueCfg(on: true, vol: .8),
        'count': CueCfg(on: true, vol: .9),
        'start': CueCfg(on: true, vol: 1, text: 'Start'),
        'rest': CueCfg(on: true, vol: 1, text: 'Break'),
      };

  factory Prefs.fromJson(Map<String, dynamic>? j) {
    if (j == null) return Prefs();
    final dc = defaultCues();
    final jc = j['cues'] is Map ? (j['cues'] as Map).cast<String, dynamic>() : <String, dynamic>{};
    return Prefs(
      audioMode: _s(j['audioMode'], 'ambient'),
      accent: kAccents.containsKey(j['accent']) ? j['accent'] as String : 'mint',
      flash: _b(j['flash'], true),
      seenSilent: _b(j['seenSilent'], false),
      digitW: _i(j['digitW'], 200),
      lastBackup: j['lastBackup'] as String?,
      cues: {
        for (final k in dc.keys)
          k: CueCfg.fromJson(jc[k] is Map ? (jc[k] as Map).cast<String, dynamic>() : null, dc[k]!),
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'audioMode': audioMode,
        'accent': accent,
        'flash': flash,
        'seenSilent': seenSilent,
        'digitW': digitW,
        'lastBackup': lastBackup,
        'cues': cues.map((k, v) => MapEntry(k, v.toJson())),
      };
}

class Snapshot {
  Settings settings;
  Plan plan;
  Snapshot(this.settings, this.plan);
  factory Snapshot.fromJson(Map<String, dynamic> j) => Snapshot(
      Settings.fromJson((j['settings'] as Map).cast<String, dynamic>()),
      Plan.fromJson((j['plan'] as Map).cast<String, dynamic>()));
  Map<String, dynamic> toJson() => {'settings': settings.toJson(), 'plan': plan.toJson()};
  Snapshot clone() => Snapshot.fromJson(jsonDecode(jsonEncode(toJson())) as Map<String, dynamic>);
}

class SavedWorkout {
  String id, name, saved;
  Snapshot snap;
  SavedWorkout({required this.id, required this.name, required this.saved, required this.snap});
  factory SavedWorkout.fromJson(Map<String, dynamic> j) => SavedWorkout(
      id: _s(j['id']),
      name: _s(j['name']),
      saved: _s(j['saved']),
      snap: Snapshot.fromJson((j['snap'] as Map).cast<String, dynamic>()));
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'saved': saved, 'snap': snap.toJson()};
}

/// The saved workout currently loaded for the Class tab (an editable copy).
class ActiveWorkout {
  String id, name;
  Settings settings;
  Plan plan;
  ActiveWorkout({required this.id, required this.name, required this.settings, required this.plan});
  factory ActiveWorkout.fromJson(Map<String, dynamic> j) => ActiveWorkout(
      id: _s(j['id']),
      name: _s(j['name']),
      settings: Settings.fromJson((j['settings'] as Map).cast<String, dynamic>()),
      plan: Plan.fromJson((j['plan'] as Map).cast<String, dynamic>()));
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'settings': settings.toJson(), 'plan': plan.toJson()};
}

class HistoryEntry {
  int weekNo;
  List<String> ids;
  String saved;
  HistoryEntry(this.weekNo, this.ids, this.saved);
  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(_i(j['weekNo'], 0), _ls(j['ids']), _s(j['saved']));
  Map<String, dynamic> toJson() => {'weekNo': weekNo, 'ids': ids, 'saved': saved};
}

/// Everything the app stores. JSON-compatible with the web version's backups.
class DB {
  Settings settings;
  Map<String, bool> equipment;
  bool allowCombo;
  Prefs prefs;
  List<Exercise> library;
  Plan plan;
  List<HistoryEntry> history;
  List<SavedWorkout> saved;
  String? activeId;
  ActiveWorkout? wk;
  int seedV;

  DB({
    required this.settings,
    required this.equipment,
    this.allowCombo = false,
    required this.prefs,
    required this.library,
    required this.plan,
    List<HistoryEntry>? history,
    List<SavedWorkout>? saved,
    this.activeId,
    this.wk,
    this.seedV = 0,
  })  : history = history ?? [],
        saved = saved ?? [];

  Map<String, dynamic> toJson() => {
        'v': 1,
        'settings': settings.toJson(),
        'equipment': equipment,
        'allowCombo': allowCombo,
        'prefs': prefs.toJson(),
        'library': library.map((e) => e.toJson()).toList(),
        'plan': plan.toJson(),
        'history': history.map((h) => h.toJson()).toList(),
        'saved': saved.map((w) => w.toJson()).toList(),
        'activeId': activeId,
        'wk': wk?.toJson(),
        'seedV': seedV,
      };
}
