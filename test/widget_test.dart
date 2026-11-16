import 'dart:convert';
import 'dart:io';

import 'package:circuit_coach/app_state.dart';
import 'package:circuit_coach/main.dart';
import 'package:circuit_coach/models.dart';
import 'package:circuit_coach/timeline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _seeds() => jsonDecode(File('assets/data/seeds.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('timeline', () {
    // Totals computed with the original HTML app's planTotal().
    const expected = {'Week 1': 2880, 'Week 2': 2280, 'Tempo 50': 3000, 'Week 3': 2670, 'Week 4': 2530};

    for (final entry in expected.entries) {
      test('${entry.key} total matches the web version', () {
        final m = (_seeds()['seeds'] as List).cast<Map<String, dynamic>>().firstWhere((s) => s['name'] == entry.key);
        final s = Settings.fromJson((m['settings'] as Map).cast<String, dynamic>());
        final p = Plan.fromJson((m['plan'] as Map).cast<String, dynamic>());
        expect(planTotal(s, p), entry.value);
        final tl = buildTimelineFor(s, p, 'x');
        expect(tl.total, entry.value);
        expect(tl.sections.first.start, 0);
        expect(tl.sections.last.end, tl.segs.length - 1);
        expect(tl.segs.last.waitAfter || tl.segs.last.kind == 'cooldown', isTrue);
      });
    }

    test('tempo blocks run straight through with no rests or breaks', () {
      final m = (_seeds()['seeds'] as List).cast<Map<String, dynamic>>().firstWhere((s) => s['name'] == 'Tempo 50');
      final s = Settings.fromJson((m['settings'] as Map).cast<String, dynamic>());
      final p = Plan.fromJson((m['plan'] as Map).cast<String, dynamic>());
      final tl = buildTimelineFor(s, p, 'x');
      expect(tl.segs.where((g) => g.kind == 'rest' || g.kind == 'break'), isEmpty);
      expect(tl.segs.firstWhere((g) => g.kind == 'work').tempo, '2-2');
    });
  });

  testWidgets('app boots, runs the timer controls and switches tabs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late AppState st;
    await tester.runAsync(() async {
      st = AppState(platformAudio: false);
      await st.boot();
    });
    await tester.pumpWidget(CircuitCoachApp(state: st));
    await tester.pump();

    expect(find.text('WARM-UP'), findsOneWidget);
    expect(find.text('Tap play to start'), findsOneWidget);
    expect(st.db.saved.map((w) => w.name), containsAll(['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Tempo 50']));
    expect(st.tl.total, 2880);

    // play / pause / skip
    st.play();
    expect(st.t.running, isTrue);
    st.play();
    expect(st.t.running, isFalse);
    st.skip();
    expect(st.t.idx, 1);
    st.back();
    expect(st.t.idx, 0);
    await tester.pump();

    for (final label in ['Plan', 'Library', 'Settings', 'Class']) {
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('WARM-UP'), findsOneWidget);

    // regenerate and next week keep a sensible shape
    st.nextWeek();
    expect(st.db.plan.weekNo, 2);
    expect(st.db.plan.blocks.length, st.db.settings.blocks);
    expect(st.db.history.single.weekNo, 1);

    // backup round-trip
    final json = st.exportJson();
    expect(st.validateBackup(json), isNull);
    await tester.runAsync(() => st.importData(json));
    expect(st.db.plan.weekNo, 2);

    st.dispose();
    await tester.pump(const Duration(seconds: 3));
  });
}
