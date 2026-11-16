import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Beeps (synthesised sine tones) and spoken cues.
///
/// Audio modes mirror the web version:
///  * `ambient`   – mix with music; respects the silent switch on iPhone.
///  * `transient` – duck (lower) other audio while cues play.
///  * `playback`  – play even with the silent switch on, still mixing with music.
class CueAudio {
  final List<AudioPlayer> _pool = [];
  int _poolI = 0;
  final Map<String, Uint8List> _wavCache = {};
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  String _mode = 'ambient';

  bool get ready => _ready;

  Future<void> init(String mode) async {
    try {
      for (var i = 0; i < 4; i++) {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.stop);
        _pool.add(p);
      }
      await setMode(mode);
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(kIsWeb ? 1.05 : 0.52);
      _ready = true;
    } catch (e) {
      debugPrint('Audio init failed: $e');
    }
  }

  Future<void> setMode(String mode) async {
    _mode = mode;
    if (kIsWeb || _pool.isEmpty) return;
    try {
      final ctx = switch (mode) {
        'transient' => AudioContext(
            android: const AudioContextAndroid(
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.assistanceSonification,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
            iOS: AudioContextIOS(category: AVAudioSessionCategory.playback, options: const {AVAudioSessionOptions.duckOthers}),
          ),
        'playback' => AudioContext(
            android: const AudioContextAndroid(
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.media,
              audioFocus: AndroidAudioFocus.none,
            ),
            iOS: AudioContextIOS(category: AVAudioSessionCategory.playback, options: const {AVAudioSessionOptions.mixWithOthers}),
          ),
        _ => AudioContext(
            android: const AudioContextAndroid(
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.assistanceSonification,
              audioFocus: AndroidAudioFocus.none,
            ),
            iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient, options: const {}),
          ),
      };
      await AudioPlayer.global.setAudioContext(ctx);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          _mode == 'ambient' ? IosTextToSpeechAudioCategory.ambient : IosTextToSpeechAudioCategory.playback,
          [
            if (_mode == 'transient') IosTextToSpeechAudioCategoryOptions.duckOthers,
            if (_mode != 'transient') IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      }
    } catch (e) {
      debugPrint('Audio mode failed: $e');
    }
  }

  /// 16-bit mono WAV with a short attack/release envelope. Volume is baked into the samples.
  Uint8List _wav(double freq, double dur, double amp) {
    amp = (math.max(0.05, math.min(1.0, amp)) * 20).round() / 20;
    final key = '$freq|$dur|$amp';
    final hit = _wavCache[key];
    if (hit != null) return hit;
    const sr = 22050;
    final n = (sr * dur).floor();
    final b = ByteData(44 + n * 2);
    void w(int o, String t) {
      for (var i = 0; i < t.length; i++) {
        b.setUint8(o + i, t.codeUnitAt(i));
      }
    }

    w(0, 'RIFF');
    b.setUint32(4, 36 + n * 2, Endian.little);
    w(8, 'WAVE');
    w(12, 'fmt ');
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little);
    b.setUint16(22, 1, Endian.little);
    b.setUint32(24, sr, Endian.little);
    b.setUint32(28, sr * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    w(36, 'data');
    b.setUint32(40, n * 2, Endian.little);
    for (var i = 0; i < n; i++) {
      final env = math.min(1.0, math.min(i / (sr * .012), (n - i) / (sr * .03)));
      b.setInt16(44 + i * 2, (math.sin(2 * math.pi * freq * i / sr) * env * amp * 32767).round(), Endian.little);
    }
    return _wavCache[key] = b.buffer.asUint8List();
  }

  void tone(double freq, double dur, double vol, [double at = 0]) {
    if (vol <= 0 || _pool.isEmpty) return;
    final bytes = _wav(freq, dur, vol);
    void fire() {
      final p = _pool[_poolI++ % _pool.length];
      p.stop().then((_) => p.play(BytesSource(bytes, mimeType: 'audio/wav'))).catchError((Object e) {
        debugPrint('Beep failed: $e');
      });
    }

    if (at > 0) {
      Timer(Duration(milliseconds: (at * 1000).round()), fire);
    } else {
      fire();
    }
  }

  Future<void> speak(String text, double vol) async {
    if (text.trim().isEmpty || vol <= 0) return;
    try {
      await _tts.stop();
      await _tts.setVolume(vol.clamp(0.0, 1.0));
      await _tts.speak(text);
    } catch (e) {
      debugPrint('Speech failed: $e');
    }
  }
}
