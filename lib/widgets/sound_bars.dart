import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/constants.dart';

/// Les 14 barres arrondies de l'image d'origine.
/// Au repos elles gardent exactement la forme de l'image ; quand [active]
/// est vrai, chacune suit le niveau de sa bande de fréquences ([levels]).
class SoundBars extends StatefulWidget {
  const SoundBars({
    super.key,
    required this.levels,
    required this.active,
    this.color = Colors.white,
    this.aspect = 0.56,
  });

  /// Liste mutée en place par le contrôleur (lue à chaque image).
  final List<double> levels;
  final bool active;
  final Color color;

  /// Hauteur / largeur du dessin.
  final double aspect;

  @override
  State<SoundBars> createState() => _SoundBarsState();
}

class _SoundBarsState extends State<SoundBars>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final List<double> _display = List<double>.filled(kBarCount, 0);
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  double _mix = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(SoundBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  bool get _settled =>
      !widget.active && _mix < 0.002 && !_display.any((v) => v > 0.002);

  void _syncTicker() {
    if (!_settled && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration t) {
    final dt = ((t - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = t;
    final target = widget.active ? 1.0 : 0.0;
    _mix += (target - _mix) * (1 - math.exp(-dt / 0.12));
    for (var i = 0; i < kBarCount; i++) {
      final tv = widget.active ? widget.levels[i] : 0.0;
      // Attaque rapide, retombée plus douce : rendu net sur les pics.
      final tau = tv > _display[i] ? 0.035 : 0.14;
      _display[i] += (tv - _display[i]) * (1 - math.exp(-dt / tau));
    }
    if (_settled) {
      _mix = 0;
      _display.fillRange(0, kBarCount, 0);
      _ticker.stop();
    }
    _frame.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1 / widget.aspect,
      child: RepaintBoundary(
        child: CustomPaint(painter: _BarsPainter(this, widget.color)),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.s, this.color) : super(repaint: s._frame);

  final _SoundBarsState s;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pitch = size.width / (kBarCount - 1 + 0.507);
    final bw = pitch * 0.507;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    final cy = size.height / 2;
    // 0.86 : la plus haute barre de l'image occupe 48 % de la largeur.
    for (var i = 0; i < kBarCount; i++) {
      final rest = kRestShape[i] * 0.86;
      final live = math.max(rest * 0.45, s._display[i]);
      final f = rest + (live - rest) * s._mix;
      final h = math.max(bw, f * size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * pitch, cy - h / 2, bw, h),
          Radius.circular(bw / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.color != color;
}
