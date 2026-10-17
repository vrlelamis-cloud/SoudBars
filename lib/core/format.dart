String two(int n) => n.toString().padLeft(2, '0');

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

String formatDate(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${two(d.hour)}:${two(d.minute)}';

String formatSize(int bytes) {
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).round()} Ko';
  }
  return '${(bytes / 1048576).toStringAsFixed(1).replaceAll('.', ',')} Mo';
}
