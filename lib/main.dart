import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'constants.dart';
import 'ui/class_screen.dart';
import 'ui/library_screen.dart';
import 'ui/plan_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/sheets.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final state = AppState();
  await state.boot();
  runApp(CircuitCoachApp(state: state));
}

final navKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

class CircuitCoachApp extends StatelessWidget {
  final AppState state;
  const CircuitCoachApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: Builder(builder: (context) {
        final accent = AppScope.of(context).accent;
        return MaterialApp(
          title: 'Circuit Coach',
          debugShowCheckedModeBanner: false,
          navigatorKey: navKey,
          scaffoldMessengerKey: messengerKey,
          theme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.bg,
            colorScheme: ColorScheme.dark(primary: accent, onPrimary: AppColors.accentInk, surface: AppColors.sheet, onSurface: AppColors.text),
            textTheme: ThemeData.dark().textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
            sliderTheme: SliderThemeData(activeTrackColor: accent, thumbColor: Colors.white, inactiveTrackColor: const Color(0xFF3A3F3C)),
            textSelectionTheme: TextSelectionThemeData(cursorColor: accent, selectionColor: accent.withValues(alpha: .35)),
          ),
          home: const Shell(),
        );
      }),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with SingleTickerProviderStateMixin implements UiHooks {
  int tab = 0;
  late final AnimationController flashCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  Color flashColor = Colors.transparent;
  late AppState st;

  @override
  void initState() {
    super.initState();
    st = AppScope.read(context);
    st.ui = this;
    if (st.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => toast('Class resumed where you left off'));
    }
  }

  @override
  void dispose() {
    flashCtl.dispose();
    super.dispose();
  }

  // ---- UiHooks ----
  @override
  void toast(String msg) {
    final m = messengerKey.currentState;
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.ink, fontSize: 15)),
      backgroundColor: Colors.white,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2400),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 92),
    ));
  }

  @override
  Future<bool> confirm(String title, String msg, String yesLabel, {bool danger = false}) {
    final ctx = navKey.currentContext;
    if (ctx == null) return Future.value(false);
    return askSheet(ctx, title, msg, yesLabel, danger: danger);
  }

  @override
  void openWorkout({required bool auto}) {
    final ctx = navKey.currentContext;
    if (ctx == null || tab != 0) return;
    openWorkoutSheet(ctx, auto: auto);
  }

  @override
  void flash(Color c) {
    if (MediaQuery.of(context).disableAnimations) return;
    setState(() => flashColor = c);
    flashCtl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final screens = [
      const ClassScreen(),
      PlanScreen(goToClass: () => setState(() => tab = 0)),
      const LibraryScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: false,
      body: Stack(children: [
        Positioned.fill(child: _Backdrop(accent: st.accent)),
        Positioned.fill(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: IndexedStack(index: tab, children: screens),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.of(context).padding.bottom + 10,
          child: Center(child: _BottomNav(tab: tab, onTap: (i) => setState(() => tab = i))),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: flashCtl,
              builder: (context, _) =>
                  ColoredBox(color: flashCtl.isAnimating ? flashColor.withValues(alpha: .5 * (1 - flashCtl.value)) : Colors.transparent),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Backdrop extends StatelessWidget {
  final Color accent;
  const _Backdrop({required this.accent});
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: ColoredBox(color: AppColors.bg)),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -1.16),
              radius: 1.1,
              colors: [accent.withValues(alpha: .16), accent.withValues(alpha: 0)],
              stops: const [0, .62],
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.2, 1.1),
              radius: .8,
              colors: [accent.withValues(alpha: .08), accent.withValues(alpha: 0)],
              stops: const [0, .6],
            ),
          ),
        ),
      ),
    ]);
  }
}

class _BottomNav extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.tab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = AppScope.of(context).accent;
    const items = [
      (Icons.timer_outlined, 'Class'),
      (Icons.calendar_month_outlined, 'Plan'),
      (Icons.fitness_center, 'Library'),
      (Icons.settings_outlined, 'Settings'),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xB81C201E),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Semantics(
                button: true,
                selected: tab == i,
                label: items[i].$2,
                child: Material(
                  color: tab == i ? accent : Colors.transparent,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: SizedBox(
                      width: 60,
                      height: 56,
                      child: Icon(items[i].$1, size: 24, color: tab == i ? AppColors.accentInk : AppColors.muted),
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
