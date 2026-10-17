import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/recorder/recorder_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SoundBarsApp());
}

class SoundBarsApp extends StatelessWidget {
  const SoundBarsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoundBars',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      themeMode: ThemeMode.dark,
      home: const RecorderScreen(),
    );
  }
}
