import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/format.dart';
import 'wav.dart';

class Recording {
  Recording({
    required this.path,
    required this.createdAt,
    required this.duration,
    required this.sizeBytes,
  });

  final String path;
  final DateTime createdAt;
  final Duration duration;
  final int sizeBytes;

  String get title => 'Enregistrement ${formatDate(createdAt)}';
}

class RecordingsRepository {
  Future<Directory> directory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/recordings');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> newFile() async {
    final dir = await directory();
    final n = DateTime.now();
    final stamp = '${n.year}${two(n.month)}${two(n.day)}_'
        '${two(n.hour)}${two(n.minute)}${two(n.second)}';
    return File('${dir.path}/rec_$stamp.wav');
  }

  Future<List<Recording>> list() async {
    final dir = await directory();
    final out = <Recording>[];
    await for (final e in dir.list()) {
      if (e is! File || !e.path.endsWith('.wav')) continue;
      final stat = await e.stat();
      final dataBytes = stat.size - kWavHeaderSize;
      if (dataBytes <= 0) continue;
      out.add(Recording(
        path: e.path,
        createdAt: _parseDate(e.path) ?? stat.modified,
        duration: Duration(
          milliseconds: (dataBytes * 1000 / (kSampleRate * 2)).round(),
        ),
        sizeBytes: stat.size,
      ));
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<void> delete(Recording r) async {
    final f = File(r.path);
    if (await f.exists()) await f.delete();
  }

  DateTime? _parseDate(String path) {
    final m = RegExp(r'rec_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})')
        .firstMatch(path);
    if (m == null) return null;
    int g(int i) => int.parse(m.group(i)!);
    return DateTime(g(1), g(2), g(3), g(4), g(5), g(6));
  }
}
