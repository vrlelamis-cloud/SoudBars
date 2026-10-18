import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/recordings_repository.dart';
import '../../widgets/sound_bars.dart';
import 'playback_controller.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.repo});
  final RecordingsRepository repo;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _player = PlaybackController();
  List<Recording>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await widget.repo.list();
    if (mounted) setState(() => _items = list);
  }

  Future<void> _share(Recording r) async {
    await Share.shareXFiles(
      [XFile(r.path, mimeType: 'audio/wav')],
      text: r.title,
    );
  }

  Future<void> _delete(Recording r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet enregistrement ?'),
        content: Text('${r.title} sera supprimé définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.recording),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (_player.current?.path == r.path) await _player.stop();
    await widget.repo.delete(r);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Mes enregistrements')),
      body: SafeArea(
        child: Column(
          children: [
            ListenableBuilder(
              listenable: _player,
              builder: (_, __) => Padding(
                padding: const EdgeInsets.fromLTRB(40, 16, 40, 24),
                child: ExcludeSemantics(
                  child: SoundBars(
                    levels: _player.levels,
                    active: _player.playing,
                    aspect: 0.4,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: items == null
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              "Aucun enregistrement pour l'instant.\n"
                              'Touchez les barres sur l\'écran principal '
                              'pour commencer.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) => _tile(items[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(Recording r) {
    return ListenableBuilder(
      listenable: _player,
      builder: (_, __) {
        final playing = _player.isPlaying(r);
        return ListTile(
          minVerticalPadding: 12,
          leading: IconButton(
            tooltip: playing ? 'Mettre en pause' : 'Écouter',
            iconSize: 40,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => _player.toggle(r),
            icon: Icon(
              playing
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
            ),
          ),
          title: Text(r.title, style: const TextStyle(fontSize: 16)),
          subtitle: Text(
            '${formatDuration(r.duration)} · ${formatSize(r.sizeBytes)}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.secondaryText,
            ),
          ),
          trailing: PopupMenuButton<String>(
            tooltip: "Plus d'options",
            onSelected: (v) => v == 'share' ? _share(r) : _delete(r),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'share', child: Text('Partager')),
              PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        );
      },
    );
  }
}
