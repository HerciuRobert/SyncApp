// ignore_for_file: non_constant_identifier_names
import 'models.dart';

/// One timed segment of the class.
class Seg {
  final String kind; // warmup | work | rest | finisher | break | cooldown
  int dur;
  int start = 0;
  final String? ex;
  final String note;
  final String tempo;
  final int secIdx;
  final int k, M; // warm-up / cool-down / finisher index and count
  final int block;
  final int r, R, i, n; // round / exercise counters
  final int fr, FR; // finisher round
  final bool wu; // a pause inside the warm-up
  bool waitAfter;

  Seg({
    required this.kind,
    required this.dur,
    this.ex,
    this.note = '',
    this.tempo = '',
    required this.secIdx,
    this.k = 0,
    this.M = 0,
    this.block = 0,
    this.r = 0,
    this.R = 1,
    this.i = 0,
    this.n = 0,
    this.fr = 0,
    this.FR = 1,
    this.wu = false,
    this.waitAfter = false,
  });

  bool get hasHalf => const ['work', 'rest', 'finisher', 'cooldown'].contains(kind) && dur >= 8;
}

class Section {
  final String key, label, kind;
  final int start;
  int end = 0, dur = 0;
  final int block;
  final String? theme;
  Section({required this.key, required this.label, required this.kind, required this.start, this.block = 0, this.theme});
}

class Timeline {
  final List<Seg> segs;
  final List<Section> sections;
  int total;
  final String sig;
  Timeline(this.segs, this.sections, this.total, this.sig);
  static Timeline empty() => Timeline([], [], 0, '');

  void rebuildStarts() {
    var t = 0;
    for (final g in segs) {
      g.start = t;
      t += g.dur;
    }
    total = t;
    for (final x in sections) {
      x.dur = segs.sublist(x.start, x.end + 1).fold(0, (a, g) => a + g.dur);
    }
  }
}

Timeline buildTimelineFor(Settings s, Plan p, String sig) {
  final segs = <Seg>[];
  final sections = <Section>[];
  var t = 0;
  int sec(String key, String label, String kind, {int block = 0, String? theme}) {
    sections.add(Section(key: key, label: label, kind: kind, start: segs.length, block: block, theme: theme));
    return sections.length - 1;
  }

  void push(Seg o) {
    o.start = t;
    t += o.dur;
    segs.add(o);
  }

  var si = 0;
  if (p.warmup.isNotEmpty) {
    si = sec('wu', 'Warm-up', 'warmup');
    final m = p.warmup.length;
    for (var k = 0; k < m; k++) {
      push(Seg(kind: 'warmup', dur: p.wuDur(s, k), note: p.wuNoteAt(k), ex: p.warmup[k], secIdx: si, k: k, M: m));
      if (p.wuRestSec > 0 && k < m - 1) {
        push(Seg(kind: 'rest', dur: p.wuRestSec, ex: p.warmup[k + 1], secIdx: si, wu: true, k: k + 1, M: m));
      }
    }
    if (!s.isTempo) segs.last.waitAfter = true;
  }
  for (var bi = 0; bi < p.blocks.length; bi++) {
    final b = p.blocks[bi];
    si = sec('b$bi', 'Block ${bi + 1}', 'block', block: bi, theme: b.theme);
    if (s.isTempo) {
      // continuous: one track after another, no rests or breaks
      for (var i = 0; i < b.ex.length; i++) {
        final q = b.trk(i);
        push(Seg(kind: 'work', dur: q.dur, ex: b.ex[i], secIdx: si, block: bi, r: 0, R: 1, i: i, n: b.ex.length, tempo: q.tempo, note: q.note));
      }
      continue;
    }
    final n = b.ex.length, ladder = s.isLadder, rr = ladder ? s.ladder.length : s.rounds;
    for (var r = 0; r < rr; r++) {
      for (var i = 0; i < n; i++) {
        final w = ladder ? s.ladder[r] : (b.work ?? s.work);
        push(Seg(kind: 'work', dur: w, ex: b.ex[i], secIdx: si, block: bi, r: r, R: rr, i: i, n: n));
        final nextId = i < n - 1 ? b.ex[i + 1] : (r < rr - 1 ? b.ex[0] : (b.fin.isNotEmpty ? b.fin[0] : null));
        push(Seg(kind: 'rest', dur: b.rest ?? s.rest, ex: nextId, secIdx: si, block: bi, r: r, R: rr, i: i, n: n));
      }
    }
    for (var fr = 0; fr < s.finRounds; fr++) {
      for (var k = 0; k < b.fin.length; k++) {
        push(Seg(kind: 'finisher', dur: s.finWork, ex: b.fin[k], secIdx: si, block: bi, k: k, M: b.fin.length, fr: fr, FR: s.finRounds));
      }
    }
    if (bi < p.blocks.length - 1) {
      final bs = sec('br$bi', 'Break', 'break', block: bi);
      push(Seg(kind: 'break', dur: s.breakSec, secIdx: bs, block: bi, waitAfter: true));
    } else if (segs.isNotEmpty) {
      segs.last.waitAfter = true;
    }
  }
  if (p.cooldown.isNotEmpty) si = sec('cd', 'Cool-down', 'cooldown');
  for (var k = 0; k < p.cooldown.length; k++) {
    push(Seg(kind: 'cooldown', dur: s.cdSec, ex: p.cooldown[k], secIdx: si, k: k, M: p.cooldown.length));
  }
  // Drop sections that ended up empty (e.g. a block with no exercises).
  for (var i = 0; i < sections.length; i++) {
    final x = sections[i];
    x.end = (i < sections.length - 1 ? sections[i + 1].start : segs.length) - 1;
    x.dur = x.end >= x.start ? segs.sublist(x.start, x.end + 1).fold(0, (a, g) => a + g.dur) : 0;
  }
  return Timeline(segs, sections, t, sig);
}
