import 'package:flutter/material.dart';

import '../theme.dart';
import 'status_screen.dart';

class GameApp extends StatelessWidget {
  const GameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panzergefecht skeleton',
      debugShowCheckedModeBanner: false,
      theme: buildBundeswehrTheme(),
      home: const Scaffold(
        backgroundColor: BwColors.background,
        // Swap this for a GameWidget with your game.
        body: StatusScreen(),
      ),
    );
  }
}
