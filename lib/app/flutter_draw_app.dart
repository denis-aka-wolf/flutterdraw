import 'package:flutter/material.dart';

import '../features/workspace/presentation/workspace_screen.dart';

class FlutterDrawApp extends StatelessWidget {
  const FlutterDrawApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF6750A4);

    return MaterialApp(
      title: 'FlutterDraw',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F3F6),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const WorkspaceScreen(),
    );
  }
}
