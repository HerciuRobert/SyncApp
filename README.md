# Circuit Coach (Flutter)

A Flutter port of the **Circuit Coach** web app: a gym-class interval timer and weekly workout planner.
It runs on iOS, Android and the web.

## Features

- **Class**: progress ring timer with work / rest / warm-up / finisher / break / cool-down states, a segmented class
  progress bar, "now" and "next" exercises, back / play / skip, reset exercise / block, and +30 s on breaks.
  Halfway beeps, last-3-second beeps, spoken "Start" / "Break" (and tempo call-outs), plus an optional screen flash.
  The timer is timestamp based, so it stays correct after the screen locks, and a class in progress is restored
  if the app is closed (for up to 3 hours).
- **Workout sheet**: every section as an accordion with done / current / next markers, "Go to start", and an
  automatic briefing of the next block at each break.
- **Plan**: the weekly program (presets Base 45/15, Density 48/12, Ladder 30-45-60, Choose your level; tempo blocks),
  all timing steppers with the 50:00 target, block themes, swap exercises, Regenerate / Save week / Next week
  (4-week cycle that avoids exercises from the last 2 weeks), and saved workouts (load, rename, duplicate,
  overwrite, delete). Seeded with Week 1–4 and Tempo 50.
- **Library**: 228 starter exercises, search / filter by type and region, add / edit / delete your own.
- **Settings**: gym equipment, combo moves, audio mode (mix / duck / over the silent switch), per-cue volume and words,
  accent colour, digit weight, keep-screen-on, and JSON backup export / import (compatible with the web version's backups).

## Run

```bash
flutter pub get
flutter run
```

Tests: `flutter test`.

## Layout

- `lib/models.dart` – data model (JSON-compatible with the web app's storage and backups)
- `lib/timeline.dart` – turns a plan + settings into timed segments and sections
- `lib/app_state.dart` – storage, timer engine, cues, workout generator, plan and saved-workout actions
- `lib/audio.dart` – synthesised beeps (`audioplayers`) and speech (`flutter_tts`)
- `lib/ui/` – screens and bottom sheets
- `assets/data/` – starter exercise library and seeded workouts, extracted from the original HTML
