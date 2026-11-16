import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../constants.dart';
import '../models.dart';

/// Gives widgets access to [AppState] and rebuilds them on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

const kXl = 30.0, kLg = 22.0;

class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin = EdgeInsets.zero, this.radius = kXl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: AppColors.line),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A glass card with a heading, used for every settings / plan section.
class GlassSection extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final List<Widget> children;
  const GlassSection({super.key, this.title, this.trailing, required this.children});

  @override
  Widget build(BuildContext context) {
    return Glass(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Expanded(child: Text(title!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w300))),
                ?trailing,
              ]),
            ),
          ...children,
        ],
      ),
    );
  }
}

enum PillKind { normal, primary, white, danger, on }

class Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final PillKind kind;
  final bool block;
  final double height;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  const Pill(this.label,
      {super.key,
      this.icon,
      this.onTap,
      this.kind = PillKind.normal,
      this.block = false,
      this.height = 46,
      this.fontSize = 15,
      this.padding = const EdgeInsets.symmetric(horizontal: 18)});

  @override
  Widget build(BuildContext context) {
    final accent = AppScope.of(context).accent;
    final (bg, fg, border) = switch (kind) {
      PillKind.primary || PillKind.on => (accent, AppColors.accentInk, Colors.transparent),
      PillKind.white => (Colors.white, AppColors.ink, Colors.transparent),
      PillKind.danger => (AppColors.glass2, const Color(0xFFFF7A7A), const Color(0x66FF5A5A)),
      PillKind.normal => (AppColors.glass2, AppColors.text, AppColors.line),
    };
    final content = Row(
      mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontSize: fontSize, fontWeight: kind == PillKind.primary ? FontWeight.w600 : FontWeight.w400)),
        ),
      ],
    );
    return Opacity(
      opacity: onTap == null ? .4 : 1,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: BorderSide(color: border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: height),
            padding: padding,
            alignment: block ? Alignment.center : null,
            child: content,
          ),
        ),
      ),
    );
  }
}

class Tag extends StatelessWidget {
  final String text;
  final String kind; // '', warn, hi
  final double fontSize;
  const Tag(this.text, {super.key, this.kind = '', this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      'warn' => (const Color(0x2EFFB547), const Color(0xFFFFC877)),
      'hi' => (const Color(0x2EFF6B8B), const Color(0xFFFF9AB0)),
      _ => (AppColors.glass2, AppColors.muted),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize > 11 ? 10 : 8, vertical: fontSize > 11 ? 4 : 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: fontSize, color: fg)),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;
  const RoundIconButton(this.icon, {super.key, this.onTap, this.size = 44, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final b = Material(
      color: AppColors.glass2,
      shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: size, height: size, child: Icon(icon, size: 20, color: AppColors.text)),
      ),
    );
    return tooltip == null ? b : Tooltip(message: tooltip!, child: b);
  }
}

/// Label + hint on the left, a control on the right, with a hairline above.
class KV extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget? trailing;
  final bool first;
  const KV({super.key, required this.label, this.hint, this.trailing, this.first = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.line))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            if (hint != null && hint!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(hint!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
          ]),
        ),
        const SizedBox(width: 10),
        ?trailing,
      ]),
    );
  }
}

class StepperRow extends StatelessWidget {
  final String label;
  final String? hint;
  final String value;
  final VoidCallback onDec, onInc;
  const StepperRow({super.key, required this.label, this.hint, required this.value, required this.onDec, required this.onInc});

  @override
  Widget build(BuildContext context) {
    return KV(label: label, hint: hint, trailing: MiniStepper(value: value, onDec: onDec, onInc: onInc));
  }
}

class MiniStepper extends StatelessWidget {
  final String value;
  final VoidCallback onDec, onInc;
  const MiniStepper({super.key, required this.value, required this.onDec, required this.onInc});

  Widget _btn(String t, VoidCallback f, String label) => Semantics(
        button: true,
        label: label,
        child: Material(
          color: AppColors.glass2,
          shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: f,
              child: SizedBox(width: 44, height: 44, child: Center(child: Text(t, style: const TextStyle(fontSize: 22, height: 1))))),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _btn('−', onDec, 'Decrease'),
      SizedBox(
        width: 66,
        child: Text(value,
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontFeatures: [FontFeature.tabularFigures()])),
      ),
      _btn('+', onInc, 'Increase'),
    ]);
  }
}

class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const AppSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final accent = AppScope.of(context).accent;
    return Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: accent,
      activeThumbColor: Colors.white,
      inactiveTrackColor: const Color(0xFF3A3F3C),
      inactiveThumbColor: Colors.white,
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }
}

Widget _maybeCenter(bool expanded, Widget child) => expanded ? child : Center(widthFactor: 1, child: child);

/// Row of rounded toggle buttons; the selected one is white.
class SegCtl<T> extends StatelessWidget {
  final List<(T, String)> items;
  final T? value;
  final ValueChanged<T> onTap;
  final bool expand;
  const SegCtl({super.key, required this.items, required this.value, required this.onTap, this.expand = false});

  @override
  Widget build(BuildContext context) {
    Widget btn((T, String) it) {
      final on = it.$1 == value;
      return Material(
        color: on ? Colors.white : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: on ? Colors.white : AppColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(it.$1),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: expand ? Alignment.center : null,
            child: _maybeCenter(expand, Text(it.$2,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: expand ? 15 : 14,
                    color: on ? AppColors.ink : AppColors.muted,
                    fontWeight: on && expand ? FontWeight.w600 : FontWeight.w400))),
          ),
        ),
      );
    }

    if (expand) {
      return Row(children: [
        for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(width: 6), Expanded(child: btn(items[i]))],
      ]);
    }
    return Wrap(spacing: 6, runSpacing: 6, children: items.map(btn).toList());
  }
}

class InfoBanner extends StatelessWidget {
  final Widget child;
  final String kind; // info | warn | danger
  final VoidCallback? onClose;
  const InfoBanner({super.key, required this.child, this.kind = 'info', this.onClose});

  @override
  Widget build(BuildContext context) {
    final (bg, border) = switch (kind) {
      'warn' => (const Color(0x24FFB547), const Color(0x59FFB547)),
      'danger' => (const Color(0x24FF5A5A), const Color(0x66FF5A5A)),
      _ => (AppColors.glass, AppColors.line),
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(kLg), border: Border.all(color: border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 14, height: 1.35), child: child))),
        if (onClose != null)
          IconButton(onPressed: onClose, icon: const Icon(Icons.close, size: 20), color: AppColors.text, tooltip: 'Dismiss'),
      ]),
    );
  }
}

class Muted extends StatelessWidget {
  final String text;
  final double size;
  final EdgeInsetsGeometry padding;
  const Muted(this.text, {super.key, this.size = 14, this.padding = EdgeInsets.zero});
  @override
  Widget build(BuildContext context) =>
      Padding(padding: padding, child: Text(text, style: TextStyle(fontSize: size, color: AppColors.muted, height: 1.4)));
}

class SubLabel extends StatelessWidget {
  final String text;
  final Color color;
  const SubLabel(this.text, {super.key, this.color = AppColors.muted});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(text.toUpperCase(), style: TextStyle(fontSize: 13, color: color, letterSpacing: .8)),
      );
}

class PageTitle extends StatelessWidget {
  final String text;
  const PageTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
        child: Text(text, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w300, letterSpacing: -.3)),
      );
}

/// Exercise row: name, regions/equipment, tags, info + an action button.
class ExRow extends StatelessWidget {
  final Exercise e;
  final List<Widget> extraTags;
  final VoidCallback? onInfo;
  final Widget? action;
  final bool first;
  const ExRow({super.key, required this.e, this.extraTags = const [], this.onInfo, this.action, this.first = false});

  @override
  Widget build(BuildContext context) {
    final sub = '${e.type == 'cardio' ? (e.lowImpact.isNotEmpty ? 'Low impact: ${e.lowImpact}' : 'Low impact') : e.regText} · ${e.eqText}';
    final tags = [
      if (e.combo) const Tag('Combo'),
      if (e.impact == 'high') const Tag('Jump', kind: 'hi'),
      ...extraTags,
    ];
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.line))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.name, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Wrap(spacing: 4, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ...tags,
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        if (onInfo != null) RoundIconButton(Icons.info_outline, onTap: onInfo, tooltip: 'Details'),
        if (action != null) ...[const SizedBox(width: 8), action!],
      ]),
    );
  }
}

/// Row in the white task-list card (workout sheet / briefing).
class TaskRow extends StatelessWidget {
  final String cls; // done | cur | next pending | pending | ''
  final IconData icon;
  final String name, sub;
  final List<Widget> extra;
  final VoidCallback? onTap;
  final bool first;
  final bool alignTop;
  const TaskRow(
      {super.key,
      this.cls = '',
      required this.icon,
      required this.name,
      required this.sub,
      this.extra = const [],
      this.onTap,
      this.first = false,
      this.alignTop = false});

  @override
  Widget build(BuildContext context) {
    final accent = AppScope.of(context).accent;
    final done = cls.contains('done'), cur = cls.contains('cur'), next = cls.contains('next'), pending = cls.contains('pending');
    Widget ck;
    if (done) {
      ck = Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 16, color: AppColors.accentInk));
    } else if (cur) {
      ck = Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: 3)));
    } else if (next) {
      ck = Container(
          width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF9AA09C), width: 2)));
    } else {
      ck = Container(width: 30, height: 30, decoration: const BoxDecoration(color: Color(0xFFC9CCCA), shape: BoxShape.circle));
    }
    final row = Row(crossAxisAlignment: alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
      Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(color: AppColors.card2, shape: BoxShape.circle),
        child: Icon(icon, size: 22, color: const Color(0xFF5C625F)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                height: 1.2,
                color: done ? AppColors.inkMuted : AppColors.ink,
                decoration: done ? TextDecoration.lineThrough : null,
              )),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 13, color: AppColors.inkMuted, height: 1.3)),
          ...extra,
        ]),
      ),
      const SizedBox(width: 12),
      ck,
    ]);
    return Opacity(
      opacity: pending && !cur ? .5 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: cur ? accent.withValues(alpha: .16) : null,
          borderRadius: cur ? BorderRadius.circular(16) : null,
          border: first || cur ? null : const Border(top: BorderSide(color: Color(0x0F000000))),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(padding: EdgeInsets.symmetric(vertical: 10, horizontal: cur ? 10 : 4), child: row),
        ),
      ),
    );
  }
}

class AppDropdown<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;
  final bool expand;
  const AppDropdown({super.key, required this.value, required this.items, required this.onChanged, this.expand = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.glass2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: expand,
          dropdownColor: AppColors.sheet,
          borderRadius: BorderRadius.circular(14),
          style: const TextStyle(fontSize: 15, color: AppColors.text),
          iconEnabledColor: AppColors.muted,
          items: items.map((it) => DropdownMenuItem<T>(value: it.$1, child: Text(it.$2, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

InputDecoration fieldDeco({String? hint, String? label}) => InputDecoration(
      hintText: hint,
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: const Color(0x0AFFFFFF),
      hintStyle: const TextStyle(color: AppColors.dim),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0x38FFFFFF))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0x38FFFFFF))),
    );

/// Text field that keeps its own controller so rebuilds don't reset the cursor.
class LiveField extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int? maxLength;
  final int maxLines;
  final TextStyle? style;
  final InputDecoration? decoration;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  const LiveField(
      {super.key,
      required this.initial,
      required this.onChanged,
      this.hint,
      this.maxLength,
      this.maxLines = 1,
      this.style,
      this.decoration,
      this.onSubmitted,
      this.autofocus = false});

  @override
  State<LiveField> createState() => _LiveFieldState();
}

class _LiveFieldState extends State<LiveField> {
  late final TextEditingController c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: c,
      autofocus: widget.autofocus,
      maxLength: widget.maxLength,
      maxLines: widget.maxLines,
      minLines: 1,
      style: widget.style ?? const TextStyle(fontSize: 17, color: AppColors.text),
      decoration: (widget.decoration ?? fieldDeco(hint: widget.hint)).copyWith(counterText: ''),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}
