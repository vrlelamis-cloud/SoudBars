import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants.dart';
import '../../core/spectrum.dart';
import '../../data/recordings_repository.dart';
import '../../data/wav.dart';

/// Lecture d'un enregistrement, avec barres synchronisées sur le son joué.
class PlaybackController extends ChangeNotifier {
  PlaybackController() {
    _posSub = _player.onPositionChanged.listen(_onPosition);
    _doneSub = _player.onPlayerComplete.listen((_) => _finish());
  }

  final AudioPlayer _player = AudioPlayer();
  final SpectrumAnalyzer _analyzer = SpectrumAnalyzer(sampleRate: kSampleRate);
  final List<double> levels = List<double>.filled(kBarCount, 0);
  final Int16List _buf = Int16List(1024);
  final Stopwatch _sw = Stopwatch();

  Recording? current;
  bool playing = false;

  RandomAccessFile? _raf;
  Timer? _timer;
  Duration _base = Duration.zero;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<void>? _doneSub;

  bool isPlaying(Recording r) => playing && current?.path == r.path;

  Future<void> toggle(Recording r) async {
    if (current?.path == r.path) {
      if (playing) {
        await _pause();
      } else {
        await _resume();
      }
      return;
    }
    await stop();
    try {
      _raf = File(r.path).openSync();
      current = r;
      _base = Duration.zero;
      _sw
        ..reset()
        ..start();
      await _player.play(DeviceFileSource(r.path));
      playing = true;
      _startTimer();
    } catch (_) {
      await stop();
    }
    notifyListeners();
  }

  Future<void> _pause() async {
    await _player.pause();
    _timer?.cancel();
    _sw.stop();
    playing = false;
    levels.fillRange(0, levels.length, 0);
    notifyListeners();
  }

  Future<void> _resume() async {
    await _player.resume();
    _sw.start();
    playing = true;
    _startTimer();
    notifyListeners();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _sw
      ..stop()
      ..reset();
    try {
      await _player.stop();
    } catch (_) {}
    try {
      _raf?.closeSync();
    } catch (_) {}
    _raf = null;
    current = null;
    playing = false;
    levels.fillRange(0, levels.length, 0);
    notifyListeners();
  }

  void _finish() {
    _timer?.cancel();
    _sw
      ..stop()
      ..reset();
    try {
      _raf?.closeSync();
    } catch (_) {}
    _raf = null;
    current = null;
    playing = false;
    levels.fillRange(0, levels.length, 0);
    notifyListeners();
  }

  void _onPosition(Duration p) {
    final estimated = _base + _sw.elapsed;
    if ((p - estimated).inMilliseconds.abs() > 120) {
      _base = p;
      _sw
        ..reset()
        ..start();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) => _tick());
  }

  void _tick() {
    final raf = _raf;
    if (raf == null) return;
    final pos = _base + _sw.elapsed;
    final sample = pos.inMicroseconds * kSampleRate ~/ 1000000;
    final start = (sample - _buf.length).clamp(0, 1 << 40);
    try {
      raf.setPositionSync(kWavHeaderSize + start * 2);
      final bytes = raf.readSync(_buf.length * 2);
      final bd = ByteData.sublistView(bytes);
      final n = bytes.length ~/ 2;
      for (var i = 0; i < _buf.length; i++) {
        _buf[i] = i < n ? bd.getInt16(i * 2, Endian.little) : 0;
      }
      _analyzer.analyze(_buf, levels);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _posSub?.cancel();
    _doneSub?.cancel();
    try {
      _raf?.closeSync();
    } catch (_) {}
    _player.dispose();
    super.dispose();
  }
}
