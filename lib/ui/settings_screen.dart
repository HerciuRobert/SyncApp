import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../constants.dart';
import '../models.dart';
import 'sheets.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final P = st.db.prefs;
    final mq = MediaQuery.of(context);
    final lb = P.lastBackup;
    final oldBackup = lb != null && (DateTime.tryParse(lb) ?? DateTime.now()).isBefore(DateTime.now().subtract(const Duration(days: 30)));

    Widget cueRow(String k, String label, bool hasText) {
      final c = P.cues[k]!;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KV(label: label, trailing: AppSwitch(value: c.on, onChanged: (v) => st.setPrefs((p) => p.cues[k]!.on = v))),
        Row(children: [
          const Text('Volume', style: TextStyle(fontSize: 14, color: AppColors.muted)),
          Expanded(
            child: Slider(
              value: c.vol.clamp(0, 1),
              divisions: 20,
              activeColor: st.accent,
              label: '${(c.vol * 100).round()}%',
              onChanged: (v) => st.setPrefs((p) => p.cues[k]!.vol = v),
            ),
          ),
          if (hasText)
            SizedBox(
              width: 104,
              child: LiveField(
                key: ValueKey('cue-$k'),
                initial: c.text,
                style: const TextStyle(fontSize: 16),
                onChanged: (v) {
                  c.text = v;
                  st.save();
                },
              ),
            ),
        ]),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Pill('Test ${label.toLowerCase()}', icon: Icons.volume_up_outlined, height: 44, fontSize: 14, onTap: () => st.testCue(k)),
          ),
        ),
      ]);
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, mq.padding.top + 10, 16, mq.padding.bottom + 120),
      children: [
        const PageTitle('Settings'),
        if (!st.storageOK)
          const InfoBanner(
              kind: 'danger',
              child: Text.rich(TextSpan(children: [
                TextSpan(text: 'Saving failed. ', style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: 'Your changes may not be kept. Export a backup below.'),
              ]))),
        if (oldBackup) InfoBanner(kind: 'warn', child: Text('Last backup was $lb. Export a new one below.')),
        GlassSection(title: 'Equipment at this gym', children: [
          for (final g in kEqGroups) ...[
            SubLabel(g[1]),
            for (final e in eqByGroup(g[0]))
              KV(label: e[1], trailing: AppSwitch(value: st.db.equipment[e[0]] == true, onChanged: (v) => st.setEquipment(e[0], v))),
          ],
          KV(
              label: 'Allow combo moves',
              hint: 'Thruster, lunge + curl and similar',
              trailing: AppSwitch(value: st.db.allowCombo, onChanged: st.setCombo)),
          const Muted(
              'Regenerate and swap suggestions only use equipment that\'s switched on. The starter library has no exercises for the "Other equipment" items yet: add your own in the Library and pick the equipment there.'),
        ]),
        GlassSection(title: 'Sound', children: [
          Pill('Test sound', icon: Icons.volume_up_outlined, kind: PillKind.primary, block: true, onTap: st.testSound),
          const SubLabel('With music playing'),
          SegCtl<String>(
            items: const [('ambient', 'Mix with music'), ('transient', 'Duck music'), ('playback', 'Over silent switch')],
            value: P.audioMode,
            onTap: st.setAudioMode,
          ),
          const Muted(
            'Mix is the default: beeps blend with your music, but the iPhone silent switch mutes them. Duck lowers the music under cues. Over silent switch makes cues audible even when the ringer is on silent, still mixed with your music. Test each with music playing.',
            padding: EdgeInsets.symmetric(vertical: 10),
          ),
          cueRow('half', 'Halfway beep', false),
          cueRow('count', 'Last 3 seconds beeps', false),
          cueRow('start', 'Spoken word at work start', true),
          cueRow('rest', 'Spoken word at rest start', true),
          KV(
              label: 'Screen flash',
              hint: 'Flashes at the same moments as the sounds',
              trailing: AppSwitch(value: P.flash, onChanged: (v) => st.setPrefs((p) => p.flash = v))),
          const SizedBox(height: 6),
          Pill('About sound and the silent switch', block: true, onTap: () => silentInfo(context)),
        ]),
        GlassSection(title: 'Display', children: [
          const SubLabel('Accent'),
          SegCtl<String>(
            items: [for (final e in kAccents.entries) (e.key, e.value.$1)],
            value: P.accent,
            onTap: (a) => st.setPrefs((p) => p.accent = a),
          ),
          const SubLabel('Timer digits'),
          SegCtl<int>(
            items: const [(200, 'Thin'), (400, 'Regular'), (600, 'Bold')],
            value: P.digitW,
            onTap: (w) => st.setPrefs((p) => p.digitW = w),
          ),
          const Muted('Check the digits from 2 m away in the gym. Regular or Bold may read better than Thin.', padding: EdgeInsets.only(top: 10)),
        ]),
        GlassSection(title: 'Screen', children: [
          KV(
            first: true,
            label: 'Keep screen on',
            hint: st.wlStatus == 'on'
                ? 'Active: the screen will stay on'
                : st.wlStatus == 'failed'
                    ? 'Could not be activated. Set Auto-Lock to Never in your phone settings.'
                    : 'Not active yet. It turns on when you press play.',
            trailing: Pill(st.wlStatus == 'on' ? 'Turn off' : 'Turn on',
                height: 44, onTap: () => st.wlStatus == 'on' ? st.releaseWake() : st.requestWake()),
          ),
        ]),
        GlassSection(title: 'Backup', children: [
          Muted(
              'Everything is saved on this device only. Export a backup now and then.${lb != null ? ' Last backup: $lb.' : ' No backup yet.'}'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Pill('Export backup', kind: PillKind.primary, onTap: () => _export(context, st)),
            Pill('Copy backup', onTap: () async {
              await Clipboard.setData(ClipboardData(text: st.exportJson()));
              st.markBackedUp();
              st.ui?.toast('Backup copied. Paste it into Notes or Files.');
            }),
            Pill('Import file', onTap: () => _importFile(context, st)),
            Pill('Paste backup', onTap: () => _paste(context, st)),
          ]),
          const SubLabel('Reset'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Pill('Reset library', kind: PillKind.danger, onTap: () async {
              if (await st.ui!.confirm('Reset library?', 'Reset the library to the starter exercises? Your own exercises will be removed.', 'Reset',
                  danger: true)) {
                st.resetLibrary();
              }
            }),
            Pill('Reset everything', kind: PillKind.danger, onTap: () async {
              if (await st.ui!.confirm('Reset everything?', 'Erase all data, including saved workouts, and start again from Week 1?', 'Erase',
                  danger: true)) {
                st.resetAll();
              }
            }),
          ]),
        ]),
        const GlassSection(title: 'Test before your first class', children: [
          _Bullet('Play music, start a test class, and check the beeps and voice play over the music (Mix and Duck).'),
          _Bullet('Check whether the spoken words pause or lower the music.'),
          _Bullet('Flip the silent switch and check what you still hear.'),
          _Bullet('Leave it running 5 minutes untouched and check the screen stays on.'),
          _Bullet('Lock the screen for 20 s, unlock, and check the time is still correct.'),
          _Bullet('Read the timer from 2 m away and pick the digit weight.'),
        ]),
      ],
    );
  }

  Future<void> _export(BuildContext context, AppState st) async {
    final data = st.exportJson();
    final name = 'circuit-coach-backup-${today()}.json';
    try {
      final box = context.findRenderObject() as RenderBox?;
      final r = await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(Uint8List.fromList(utf8.encode(data)), mimeType: 'application/json', name: name)],
        fileNameOverrides: [name],
        title: name,
        sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & const Size(1, 1) : null,
      ));
      if (r.status == ShareResultStatus.dismissed) return;
      st.markBackedUp();
      st.ui?.toast(kIsWeb ? 'Backup downloaded' : 'Backup shared. Save it to Files.');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: data));
      st.markBackedUp();
      st.ui?.toast('Sharing is not available here, so the backup was copied to the clipboard.');
    }
  }

  Future<void> _importFile(BuildContext context, AppState st) async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['json']);
      if (files.isEmpty) return;
      final text = utf8.decode(await files.first.xFile.readAsBytes());
      if (!context.mounted) return;
      await _confirmImport(context, st, text);
    } catch (e) {
      st.ui?.toast('Could not read that file');
    }
  }

  Future<void> _confirmImport(BuildContext context, AppState st, String text) async {
    final err = st.validateBackup(text);
    if (err != null) return st.ui?.toast(err);
    if (!await st.ui!.confirm('Import backup?', 'Replace everything on this device with this backup?', 'Replace', danger: true)) return;
    await st.importData(text);
  }

  Future<void> _paste(BuildContext context, AppState st) async {
    final c = TextEditingController();
    final text = await showAppSheet<String>(context,
        title: 'Paste backup',
        builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: c,
                minLines: 8,
                maxLines: 12,
                style: const TextStyle(fontSize: 14),
                decoration: fieldDeco(hint: 'Paste the backup text here'),
              ),
              const SizedBox(height: 10),
              Pill('Import', kind: PillKind.primary, block: true, onTap: () => Navigator.pop(ctx, c.text)),
            ]));
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    await _confirmImport(context, st, text);
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('•  ', style: TextStyle(fontSize: 14)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.35))),
        ]),
      );
}

Future<void> silentInfo(BuildContext context) {
  final st = AppScope.read(context);
  st.setPrefs((Prefs p) => p.seenSilent = true);
  return showAppSheet(context,
      title: 'Sound on your phone',
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text(
                'The ringer/silent switch and the volume buttons affect this app\'s sound. In "Mix with music" mode, the silent switch mutes the cues. Choose "Over silent switch" to hear them anyway.',
                style: TextStyle(fontSize: 15, height: 1.45)),
            const SizedBox(height: 10),
            const Text(
                'The app can\'t be louder than the phone\'s volume, and your music uses the same volume. If the beeps get lost in the music, lower the loudness in the music app, not the phone volume.',
                style: TextStyle(fontSize: 15, height: 1.45)),
            const SizedBox(height: 10),
            const Text(
                'Cues only play while this app is on screen. The timer keeps correct time in the background and catches up when you come back.',
                style: TextStyle(fontSize: 15, height: 1.45)),
            const SizedBox(height: 14),
            Pill('Test sound', icon: Icons.volume_up_outlined, kind: PillKind.primary, block: true, onTap: st.testSound),
          ]));
}
