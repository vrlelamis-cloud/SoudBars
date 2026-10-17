import 'dart:math' as math;
import 'dart:typed_data';

/// Analyse FFT du son : renvoie [bands] valeurs entre 0 et 1,
/// des graves (gauche) aux aigus (droite).
class SpectrumAnalyzer {
  SpectrumAnalyzer({
    required this.sampleRate,
    this.size = 1024,
    this.bands = 14,
  })  : _re = Float64List(size),
        _im = Float64List(size),
        _window = Float64List(size),
        _rev = Int32List(size),
        _cos = Float64List(size ~/ 2),
        _sin = Float64List(size ~/ 2),
        _edges = List<int>.filled(bands + 1, 0) {
    for (var i = 0; i < size; i++) {
      _window[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / (size - 1));
    }
    final levels = (math.log(size) / math.ln2).round();
    for (var i = 0; i < size; i++) {
      var x = i, r = 0;
      for (var b = 0; b < levels; b++) {
        r = (r << 1) | (x & 1);
        x >>= 1;
      }
      _rev[i] = r;
    }
    for (var i = 0; i < size ~/ 2; i++) {
      _cos[i] = math.cos(2 * math.pi * i / size);
      _sin[i] = -math.sin(2 * math.pi * i / size);
    }
    // Bandes en échelle logarithmique de 60 Hz à 8 kHz.
    const lo = 60.0;
    final hi = math.min(8000.0, sampleRate / 2 - 1);
    for (var i = 0; i <= bands; i++) {
      final f = lo * math.pow(hi / lo, i / bands);
      var bin = (f * size / sampleRate).round();
      if (i > 0 && bin <= _edges[i - 1]) bin = _edges[i - 1] + 1;
      _edges[i] = bin;
    }
  }

  final int sampleRate;
  final int size;
  final int bands;

  final Float64List _re, _im, _window, _cos, _sin;
  final Int32List _rev;
  final List<int> _edges;
  double _peak = 0;

  /// [s] contient exactement [size] échantillons (les plus récents en dernier).
  void analyze(Int16List s, List<double> out) {
    for (var i = 0; i < size; i++) {
      _re[_rev[i]] = s[i] / 32768.0 * _window[i];
      _im[i] = 0;
    }
    for (var len = 2; len <= size; len <<= 1) {
      final half = len >> 1;
      final step = size ~/ len;
      for (var i = 0; i < size; i += len) {
        for (var j = 0, k = 0; j < half; j++, k += step) {
          final a = i + j, b = a + half;
          final tr = _re[b] * _cos[k] - _im[b] * _sin[k];
          final ti = _re[b] * _sin[k] + _im[b] * _cos[k];
          _re[b] = _re[a] - tr;
          _im[b] = _im[a] - ti;
          _re[a] += tr;
          _im[a] += ti;
        }
      }
    }

    var frameMax = 0.0;
    for (var band = 0; band < bands; band++) {
      var m = 0.0;
      for (var b = _edges[band]; b < _edges[band + 1] && b < size ~/ 2; b++) {
        final mag = math.sqrt(_re[b] * _re[b] + _im[b] * _im[b]) * 4 / size;
        if (mag > m) m = mag;
      }
      // Décibels + léger relèvement des aigus (moins riches en énergie).
      final db = 20 * math.log(m + 1e-9) / math.ln10 + band * 0.7;
      final v = ((db + 75) / 55).clamp(0.0, 1.0);
      out[band] = v;
      if (v > frameMax) frameMax = v;
    }

    // Gain automatique : les sons faibles restent bien visibles.
    _peak = math.max(frameMax, _peak * 0.985);
    final gain = 0.9 / math.max(_peak, 0.5);
    for (var i = 0; i < bands; i++) {
      // Petite porte de bruit : le souffle du micro ne fait pas bouger les barres.
      out[i] = ((out[i] * gain - 0.08) / 0.92).clamp(0.0, 1.0);
    }
  }
}
