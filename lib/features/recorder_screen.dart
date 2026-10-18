import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/recordings_repository.dart';
import '../../widgets/sound_bars.dart';
import '../library/library_screen.dart';
import 'recorder_controller.dart';

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  final _repo = RecordingsRepository();
  late final RecorderController _c = RecorderController(_repo);
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChange);
    _refreshCount();
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _c.dispose();
    super.dispose();
  }

  Future<void> _refreshCount() async {
    final list = await _repo.list();
    if (mounted) setState(() => _count = list.length);
  }

  void _onChange() {
    if (_c.autoStopped && !_c.isRecording) {
      _c.autoStopped = false;
      _refreshCount();
      _snack("Enregistrement arrêté et sauvegardé : l'app est passée "
          "en arrière-plan.");
    }
  }

  void _snack(String text, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action));
  }

  Future<void> _toggle() async {
    HapticFeedback.mediumImpact();
    if (!_c.isRecording) {
      await _c.start();
      return;
    }
    final saved = await _c.stop();
    await _refreshCount();
    if (saved != null) {
      _snack(
        'Enregistrement sauvegardé (${formatDuration(saved.duration)})',
        action: SnackBarAction(label: 'Écouter', onPressed: _openLibrary),
      );
    }
  }

  Future<void> _openLibrary() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LibraryScreen(repo: _repo)),
    );
    _refreshCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            final rec = _c.isRecording;
            return Column(
              children: [
                const SizedBox(height: 24),
                _Header(controller: _c),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Semantics(
                        button: true,
                        label: rec
                            ? "Arrêter l'enregistrement"
                            : "Démarrer l'enregistrement",
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _toggle,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 48,
                            ),
                            child: ExcludeSemantics(
                              child: SoundBars(levels: _c.levels, active: rec),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _Message(controller: _c),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: rec ? null : _openLibrary,
                  icon: const Icon(Icons.library_music_outlined, size: 24),
                  label: Text('Mes enregistrements ($_count)'),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});
  final RecorderController controller;

  @override
  Widget build(BuildContext context) {
    final rec = controller.isRecording;
    return SizedBox(
      height: 88,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rec)
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.recording,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  rec ? 'Enregistrement en cours' : 'Prêt',
                  style: TextStyle(
                    fontSize: 16,
                    color: rec ? Colors.white : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<Duration>(
            valueListenable: controller.elapsed,
            builder: (_, d, __) => Text(
              formatDuration(d),
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w300,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.controller});
  final RecorderController controller;

  @override
  Widget build(BuildContext context) {
    String text;
    var isError = false;
    if (controller.micDenied) {
      text = 'Micro refusé. Autorise-le dans Réglages › Applications › '
          'SoundBars › Autorisations.';
      isError = true;
    } else if (controller.error != null) {
      text = controller.error!;
      isError = true;
    } else if (controller.isRecording) {
      text = 'Touchez les barres pour arrêter';
    } else {
      text = 'Touchez les barres pour enregistrer';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          height: 1.5,
          color: isError ? AppColors.recording : AppColors.secondaryText,
        ),
      ),
    );
  }
}
