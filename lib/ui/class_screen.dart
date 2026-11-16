import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../constants.dart';
import 'sheets.dart';
import 'widgets.dart';

class ClassScreen extends StatelessWidget {
  const ClassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return LayoutBuilder(builder: (context, box) {
      final mq = MediaQuery.of(context);
      final h = box.maxHeight;
      final ring = math.max(180.0, math.min(math.min(box.maxWidth * .66, h * .29), 270.0));
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, mq.padding.top + 4, 16, mq.padding.bottom + 96),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ValueListenableBuilder<int>(
            valueListenable: st.tick,
            builder: (context, _, _) => _ClassBody(st: st, ring: ring),
          ),
        ),
      );
    });
  }
}

class _ClassBody extends StatelessWidget {
  final AppState st;
  final double ring;
  const _ClassBody({required this.st, required this.ring});

  @override
  Widget build(BuildContext context) {
    final g = st.seg;
    if (g == null) {
      return Column(children: [
        const SizedBox(height: 80),
        const Text('This plan has no exercises yet.', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 8),
        const Muted('Open the Plan tab and regenerate or load a workout.'),
      ]);
    }
    final t = st.t;
    final accent = st.accent;
    final color = stateColor(g.kind, accent);
    final e = math.min(st.elapsed, g.dur.toDouble());
    final rem = math.max(0.0, g.dur - e);
    final frac = g.dur > 0 ? rem / g.dur : 0.0;
    final done = g.start + e;
    final v = st.nowView();
    final digitW = switch (st.db.prefs.digitW) { 400 => FontWeight.w400, 600 => FontWeight.w600, _ => FontWeight.w200 };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // top bar
      SizedBox(
        height: 48,
        child: Row(children: [
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(st.classTitle(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              Text('${fmt(done)} / ${fmt(st.tl.total)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w300, fontFeatures: [FontFeature.tabularFigures()])),
            ]),
          ),
          _Chip(
            label: st.audio.ready ? 'Audio ready' : 'Audio',
            ok: st.audio.ready,
            onTap: () {
              st.testSound();
            },
          ),
          const SizedBox(width: 6),
          _Chip(
            label: st.wlStatus == 'on' ? 'Screen on' : 'Screen',
            ok: st.wlStatus == 'on',
            warn: st.wlStatus == 'failed',
            onTap: () async {
              if (st.wlStatus == 'on') {
                await st.releaseWake();
                st.ui?.toast('Screen can turn off again');
              } else {
                await st.requestWake();
                st.ui?.toast(st.wlStatus == 'on' ? 'The screen will stay on' : 'Could not keep the screen on');
              }
            },
          ),
        ]),
      ),
      const SizedBox(height: 4),
      // segmented progress
      SizedBox(
        height: 12,
        child: Row(children: [
          for (var i = 0; i < st.tl.sections.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              flex: math.max(1, st.tl.sections[i].dur),
              child: _SegPiece(
                state: i < g.secIdx ? 2 : (i == g.secIdx ? 1 : 0),
                fill: i == g.secIdx && st.tl.sections[i].dur > 0
                    ? ((done - st.tl.segs[st.tl.sections[i].start].start) / st.tl.sections[i].dur).clamp(0.0, 1.0)
                    : 0,
                accent: accent,
              ),
            ),
          ],
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(st.presetLabel(), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          Text('${st.K.p.blocks.length} blocks', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      ),
      // timer card
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kXl),
          boxShadow: [BoxShadow(color: color.withValues(alpha: .45), blurRadius: 40, spreadRadius: -6, blurStyle: BlurStyle.outer)],
        ),
        child: Glass(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Center(
            child: SizedBox(
              width: ring,
              height: ring,
              child: Stack(alignment: Alignment.center, children: [
                Positioned.fill(child: CustomPaint(painter: _RingPainter(frac: frac, color: color))),
                SizedBox(
                  width: ring * .74,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(kStateLabel[g.kind]!, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: color)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        fmt((rem - 0.001).ceil()),
                        style: TextStyle(
                          fontSize: ring * .26,
                          height: 1.05,
                          fontWeight: digitW,
                          color: color,
                          letterSpacing: -1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Text(st.caption(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, height: 1.2, color: AppColors.muted)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      // now / next
      _TextButton(
        onTap: v.act == null
            ? null
            : () => v.act == 'brief' ? openWorkoutSheet(context) : openInfo(context, v.act!, edit: false),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: Text(v.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, height: 1.1)),
          ),
          if (v.act != null) ...[const SizedBox(width: 8), const Icon(Icons.info_outline, size: 22, color: AppColors.muted)],
        ]),
      ),
      Visibility(
        visible: v.next != null,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: _TextButton(
          onTap: v.next?.id == null ? null : () => openInfo(context, v.next!.id!, edit: false),
          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Next: ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic, color: AppColors.muted)),
            Flexible(
              child: Text(v.next?.text ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic, color: AppColors.muted, height: 1.15)),
            ),
            if (v.next?.id != null) ...[const SizedBox(width: 6), const Icon(Icons.info_outline, size: 16, color: AppColors.muted)],
          ]),
        ),
      ),
      // controls
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _CircleBtn(icon: Icons.skip_previous_rounded, size: 56, onTap: st.back, label: 'Back'),
          const SizedBox(width: 24),
          _PlayButton(running: t.running, waiting: t.waiting, accent: accent, onTap: st.play),
          const SizedBox(width: 24),
          _CircleBtn(icon: Icons.skip_next_rounded, size: 56, onTap: st.skip, label: 'Skip'),
        ]),
      ),
      const SizedBox(height: 4),
      _Secondary(isBreak: g.kind == 'break'),
    ]);
  }
}

class _Secondary extends StatelessWidget {
  final bool isBreak;
  const _Secondary({required this.isBreak});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.read(context);
    final pad = EdgeInsets.symmetric(horizontal: isBreak ? 10 : 12);
    final fs = isBreak ? 13.0 : 14.0;
    Widget p(String l, IconData ic, VoidCallback f) =>
        Flexible(child: Pill(l, icon: isBreak ? null : ic, onTap: f, padding: pad, fontSize: fs));
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      p('Exercise', Icons.replay, st.resetEx),
      SizedBox(width: isBreak ? 4 : 6),
      p('Block', Icons.replay, st.resetBlock),
      SizedBox(width: isBreak ? 4 : 6),
      p('Workout', Icons.format_list_bulleted, () => openWorkoutSheet(context)),
      if (isBreak) ...[const SizedBox(width: 4), p('+30 s', Icons.add, st.plus30)],
    ]);
  }
}

class _TextButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _TextButton({required this.onTap, required this.child});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          alignment: Alignment.center,
          child: child,
        ),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool ok, warn;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.ok, this.warn = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = AppScope.of(context).accent;
    return Material(
      color: AppColors.glass,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(shape: BoxShape.circle, color: ok ? accent : (warn ? AppColors.warn : AppColors.danger)),
            ),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
      ),
    );
  }
}

class _SegPiece extends StatelessWidget {
  final int state; // 0 pending, 1 current, 2 done
  final double fill;
  final Color accent;
  const _SegPiece({required this.state, required this.fill, required this.accent});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        color: state == 2 ? accent : (state == 1 ? Colors.white : AppColors.gray.withValues(alpha: .45)),
        child: state == 1
            ? Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: fill, heightFactor: 1, child: Container(color: accent)))
            : null,
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final String label;
  const _CircleBtn({required this.icon, required this.size, required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Material(
          color: AppColors.glass2,
          shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: SizedBox(width: size, height: size, child: Icon(icon, size: 28, color: AppColors.text))),
        ),
      );
}

class _PlayButton extends StatefulWidget {
  final bool running, waiting;
  final Color accent;
  final VoidCallback onTap;
  const _PlayButton({required this.running, required this.waiting, required this.accent, required this.onTap});
  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didUpdateWidget(covariant _PlayButton old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    final reduce = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (widget.waiting && !reduce) {
      if (!pulse.isAnimating) pulse.repeat(reverse: true);
    } else if (pulse.isAnimating || pulse.value != 0) {
      pulse.stop();
      pulse.value = 0;
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.06).animate(CurvedAnimation(parent: pulse, curve: Curves.easeInOut)),
      child: Semantics(
        button: true,
        label: widget.running ? 'Pause' : 'Play',
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: widget.accent.withValues(alpha: .55), blurRadius: 30, offset: const Offset(0, 10), spreadRadius: -8)],
          ),
          child: Material(
            color: widget.accent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              child: SizedBox(
                width: 76,
                height: 76,
                child: Icon(widget.running ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 40, color: AppColors.accentInk),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Progress ring with 72 tick marks, drawn in a 320×320 coordinate space.
class _RingPainter extends CustomPainter {
  final double frac;
  final Color color;
  _RingPainter({required this.frac, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 320;
    canvas.scale(k);
    const c = Offset(160, 160);
    final on = (frac * 72).round();
    for (var i = 0; i < 72; i++) {
      final a = i / 72 * 2 * math.pi - math.pi / 2;
      final r1 = i % 6 != 0 ? 147.0 : 144.0, r2 = 154.0;
      final paint = Paint()
        ..color = i < on ? color : Colors.white.withValues(alpha: .28)
        ..strokeWidth = i % 6 != 0 ? 1.6 : 2.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(c + Offset(r1 * math.cos(a), r1 * math.sin(a)), c + Offset(r2 * math.cos(a), r2 * math.sin(a)), paint);
    }
    canvas.drawCircle(
        c,
        128,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..color = Colors.white.withValues(alpha: .08));
    if (frac > 0) {
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: 128),
          -math.pi / 2,
          2 * math.pi * frac,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 18
            ..strokeCap = StrokeCap.round
            ..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.frac != frac || old.color != color;
}
