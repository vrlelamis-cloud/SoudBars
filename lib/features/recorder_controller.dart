import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:record/record.dart';

import '../../core/constants.dart';
import '../../core/spectrum.dart';
import '../../data/recordings_repository.dart';
import '../../data/wav.dart';

enum RecorderStatus { idle, recording }

/// Capture le micro, écrit un fichier WAV et calcule le spectre en direct.
class RecorderController extends ChangeNotifier with WidgetsBindingObserver {
  RecorderController(this._repo) {
    WidgetsBinding.instance.addObserver(this);
  }

  final RecordingsRepository _repo;
  final AudioRecorder _rec = AudioRecorder();
  final SpectrumAnalyzer _analyzer = SpectrumAnalyzer(sampleRate: kSampleRate);

  /// Niveaux (0..1) de chaque barre, mis à jour en place à chaque bloc audio.
  final List<double> levels = List<double>.filled(kBarCount, 0);
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);

  RecorderStatus status = RecorderStatus.idle;
  bool micDenied = false;
  bool autoStopped = false;
  String? error;

  StreamSubscription<Uint8List>? _sub;
  RandomAccessFile? _raf;
  String? _path;
  int _dataBytes = 0;
  final Int16List _window = Int16List(1024);
  Completer<void>? _streamDone;

  bool get isRecording => status == RecorderStatus.recording;

  Future<void> start() async {
    if (status != RecorderStatus.idle) return;
    error = null;
    autoStopped = false;
    try {
      if (!await _rec.hasPermission()) {
        micDenied = true;
        notifyListeners();
        return;
      }
      micDenied = false;
      final file = await _repo.newFile();
      _path = file.path;
      _raf = await file.open(mode: FileMode.write);
      _raf!.writeFromSync(wavHeader(dataBytes: 0, sampleRate: kSampleRate));
      _dataBytes = 0;
      elapsed.value = Duration.zero;
      _window.fillRange(0, _window.length, 0);

      final stream = await _rec.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: kSampleRate,
        numChannels: 1,
      ));
      _streamDone = Completer<void>();
      _sub = stream.listen(
        _onChunk,
        onDone: () {
          final c = _streamDone;
          if (c != null && !c.isCompleted) c.complete();
        },
        onError: (_) {},
      );
      status = RecorderStatus.recording;
      notifyListeners();
    } catch (_) {
      error = "Impossible de démarrer le micro.";
      await _discardFile();
      notifyListeners();
    }
  }

  void _onChunk(Uint8List chunk) {
    final raf = _raf;
    if (raf == null) return;
    raf.writeFromSync(chunk);
    _dataBytes += chunk.length;

    final n = chunk.length ~/ 2;
    if (n > 0) {
      final bd = ByteData.sublistView(chunk);
      final size = _window.length;
      if (n >= size) {
        for (var i = 0; i < size; i++) {
          _window[i] = bd.getInt16((n - size + i) * 2, Endian.little);
        }
      } else {
        _window.setRange(0, size - n, _window, n);
        for (var i = 0; i < n; i++) {
          _window[size - n + i] = bd.getInt16(i * 2, Endian.little);
        }
      }
      _analyzer.analyze(_window, levels);
    }

    final t = Duration(milliseconds: _dataBytes * 1000 ~/ (kSampleRate * 2));
    if (t.inMilliseconds ~/ 100 != elapsed.value.inMilliseconds ~/ 100) {
      elapsed.value = t;
    }
  }

  Future<Recording?> stop() async {
    if (status != RecorderStatus.recording) return null;
    status = RecorderStatus.idle;
    notifyListeners();

    try {
      await _rec.stop();
    } catch (_) {}
    await _streamDone?.future
        .timeout(const Duration(milliseconds: 400), onTimeout: () {});
    await _sub?.cancel();
    _sub = null;

    final raf = _raf;
    _raf = null;
    if (raf != null) {
      try {
        raf.setPositionSync(0);
        raf.writeFromSync(
          wavHeader(dataBytes: _dataBytes, sampleRate: kSampleRate),
        );
        raf.closeSync();
      } catch (_) {}
    }

    Recording? saved;
    final path = _path;
    _path = null;
    if (path != null) {
      if (_dataBytes < kSampleRate * 2 ~/ 4) {
        // Moins d'un quart de seconde : on ignore.
        try {
          File(path).deleteSync();
        } catch (_) {}
      } else {
        saved = Recording(
          path: path,
          createdAt: DateTime.now(),
          duration: Duration(
            milliseconds: _dataBytes * 1000 ~/ (kSampleRate * 2),
          ),
          sizeBytes: _dataBytes + kWavHeaderSize,
        );
      }
    }
    levels.fillRange(0, levels.length, 0);
    notifyListeners();
    return saved;
  }

  Future<void> _discardFile() async {
    await _sub?.cancel();
    _sub = null;
    try {
      _raf?.closeSync();
    } catch (_) {}
    _raf = null;
    final p = _path;
    _path = null;
    if (p != null) {
      try {
        File(p).deleteSync();
      } catch (_) {}
    }
    status = RecorderStatus.idle;
  }

  /// Android coupe le micro quand l'app passe en arrière-plan :
  /// on sauvegarde proprement ce qui a été enregistré.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && isRecording) {
      autoStopped = true;
      stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    try {
      _raf?.closeSync();
    } catch (_) {}
    _rec.dispose();
    elapsed.dispose();
    super.dispose();
  }
}
