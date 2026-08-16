import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'theme.dart';

class SortRushApp extends StatelessWidget {
  const SortRushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sort Rush',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
