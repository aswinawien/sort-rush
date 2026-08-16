import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait, one-thumb play is a non-negotiable in CLAUDE.md.
  SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  runApp(const SortRushApp());
}
