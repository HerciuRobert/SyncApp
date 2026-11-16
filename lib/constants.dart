import 'package:material_ui/material_ui.dart';

/// Colours from the original design tokens.
class AppColors {
  static const bg = Color(0xFF0C0F0E);
  static const glass = Color(0x0EFFFFFF); // rgba(255,255,255,.055)
  static const glass2 = Color(0x1AFFFFFF); // .10
  static const line = Color(0x1AFFFFFF);
  static const text = Color(0xFFF2F4F3);
  static const muted = Color(0xFFA3AAA6);
  static const dim = Color(0xFF646C68);
  static const card = Color(0xFFF2F3F2);
  static const card2 = Color(0xFFE6E8E7);
  static const ink = Color(0xFF121513);
  static const inkMuted = Color(0xFF7A807C);
  static const gray = Color(0xFF9B9E9C);
  static const accentInk = Color(0xFF04140C);
  static const warmup = Color(0xFFFFB547);
  static const rest = Color(0xFF6EC1FF);
  static const finisher = Color(0xFFFF6B8B);
  static const breakC = Color(0xFFB79CFF);
  static const cooldown = Color(0xFF5ED3E6);
  static const warn = Color(0xFFFFB547);
  static const danger = Color(0xFFFF5A5A);
  static const sheet = Color(0xFF171B19);
}

/// Equipment: key, label, group.
const List<List<String>> kEquip = [
  ['db', 'Dumbbells', 'common'],
  ['step', 'Steppers', 'common'],
  ['mat', 'Mats', 'common'],
  ['kb', 'Kettlebells', 'common'],
  ['disc', 'Weight discs', 'common'],
  ['bw', 'Bodyweight', 'common'],
  ['barbell', 'Barbell', 'other'],
  ['rower', 'Rowing machine', 'other'],
  ['treadmill', 'Treadmill', 'other'],
  ['medball', 'Medicine ball', 'other'],
  ['slamball', 'Slam ball', 'other'],
  ['skierg', 'Ski erg', 'other'],
  ['bike', 'Bicycle', 'other'],
  ['sled', 'Sled', 'other'],
  ['pullup', 'Pull-up bar', 'other'],
  ['bag', 'Punching bag', 'other'],
  ['rope', 'Skipping rope', 'other'],
  ['battlerope', 'Battle rope', 'other'],
];
const kEqGroups = [
  ['common', 'Common'],
  ['other', 'Other equipment'],
];
final Map<String, String> kEqLabel = {for (final e in kEquip) e[0]: e[1]};
List<List<String>> eqByGroup(String g) => kEquip.where((e) => e[2] == g).toList();

const Map<String, String> kRegionLabel = {
  'quads': 'Quads',
  'glutes': 'Glutes',
  'hamstrings': 'Hamstrings',
  'calves': 'Calves',
  'chest': 'Chest',
  'back': 'Back',
  'shoulders': 'Shoulders',
  'biceps': 'Biceps',
  'triceps': 'Triceps',
  'core': 'Core',
  'obliques': 'Obliques',
  'lowback': 'Lower back',
  'cardio': 'Cardio',
  'hips': 'Hips',
  'mobility': 'Mobility',
};
const kResRegions = [
  'quads', 'glutes', 'hamstrings', 'calves', 'chest', 'back', //
  'shoulders', 'biceps', 'triceps', 'core', 'obliques', 'lowback',
];

class ThemeDef {
  final String label;
  final List<List<String>> slots;
  const ThemeDef(this.label, this.slots);
}

const Map<String, ThemeDef> kThemes = {
  'legs': ThemeDef('Legs', [['quads'], ['quads', 'glutes'], ['glutes', 'quads', 'calves']]),
  'upper': ThemeDef('Upper body', [['chest'], ['back'], ['shoulders']]),
  'postarms': ThemeDef('Posterior chain & arms', [['hamstrings', 'glutes'], ['biceps'], ['triceps']]),
  'core': ThemeDef('Core', [['core'], ['obliques'], ['lowback', 'core']]),
  'push': ThemeDef('Push', [['chest'], ['shoulders'], ['triceps']]),
  'pull': ThemeDef('Pull', [['back'], ['biceps'], ['back', 'lowback']]),
  'quads': ThemeDef('Quads', [['quads'], ['quads'], ['quads', 'calves']]),
  'glutes': ThemeDef('Glutes', [['glutes'], ['glutes'], ['glutes', 'hamstrings']]),
  'hams': ThemeDef('Hamstrings', [['hamstrings'], ['hamstrings', 'glutes'], ['hamstrings', 'lowback']]),
  'full': ThemeDef('Full body', [['quads', 'glutes', 'hamstrings'], ['chest', 'back', 'shoulders'], ['core', 'obliques']]),
  'chest': ThemeDef('Chest', [['chest'], ['chest'], ['chest', 'triceps']]),
  'back': ThemeDef('Back', [['back'], ['back'], ['back', 'shoulders']]),
  'biceps': ThemeDef('Biceps', [['biceps'], ['biceps'], ['biceps']]),
  'triceps': ThemeDef('Triceps', [['triceps'], ['triceps'], ['triceps', 'chest']]),
  'shoulders': ThemeDef('Shoulders', [['shoulders'], ['shoulders'], ['shoulders']]),
};
String themeName(String? t) => kThemes[t]?.label ?? '';

const kThemeSets = [
  ['legs', 'upper', 'postarms', 'core'],
  ['push', 'pull', 'legs', 'core'],
  ['quads', 'glutes', 'hams', 'core'],
  ['full', 'full', 'full', 'full'],
];

class PresetDef {
  final String label, format;
  final int? work, rounds;
  final int rest, exPerBlock;
  final List<int>? ladder;
  const PresetDef(this.label, this.format,
      {this.work, this.rounds, required this.rest, required this.exPerBlock, this.ladder});
}

const Map<String, PresetDef> kPresets = {
  'base': PresetDef('Base 45/15', 'standard', work: 45, rest: 15, exPerBlock: 4, rounds: 2),
  'density': PresetDef('Density 48/12', 'standard', work: 48, rest: 12, exPerBlock: 4, rounds: 2),
  'ladder': PresetDef('Ladder 30-45-60', 'ladder', ladder: [30, 45, 60], rest: 15, exPerBlock: 2),
  'choose': PresetDef('Choose your level', 'choose', work: 45, rest: 15, exPerBlock: 4, rounds: 2),
};
const kCyclePreset = ['base', 'density', 'ladder', 'choose'];

const Map<String, (String, Color)> kAccents = {
  'mint': ('Radioactive mint', Color(0xFF3DF5A3)),
  'classic': ('Soft mint', Color(0xFF4CC38A)),
  'lime': ('Lime', Color(0xFFB8F55A)),
};

const Map<String, String> kStateLabel = {
  'warmup': 'WARM-UP',
  'work': 'WORK',
  'rest': 'REST',
  'finisher': 'FINISHER',
  'break': 'BREAK',
  'cooldown': 'COOL-DOWN',
};

Color stateColor(String kind, Color accent) {
  switch (kind) {
    case 'warmup':
      return AppColors.warmup;
    case 'rest':
      return AppColors.rest;
    case 'finisher':
      return AppColors.finisher;
    case 'break':
      return AppColors.breakC;
    case 'cooldown':
      return AppColors.cooldown;
    default:
      return accent;
  }
}

String pad2(int n) => n.toString().padLeft(2, '0');

/// mm:ss
String fmt(num s) {
  final v = s.round() < 0 ? 0 : s.round();
  return '${pad2(v ~/ 60)}:${pad2(v % 60)}';
}

/// m:ss
String fmtM(num s) {
  final v = s.round() < 0 ? 0 : s.round();
  return '${v ~/ 60}:${pad2(v % 60)}';
}

String today() => DateTime.now().toIso8601String().substring(0, 10);

T clampT<T extends num>(T v, T a, T b) => v < a ? a : (v > b ? b : v);
