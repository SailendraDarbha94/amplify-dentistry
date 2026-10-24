import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

/// Wraps [child] in a themed MaterialApp for widget tests.
Widget testApp(Widget child, {bool dark = false}) => MaterialApp(
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: Scaffold(body: child),
);
