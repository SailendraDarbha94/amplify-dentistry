import 'package:flutter/widgets.dart';

import 'app_strings.dart';

/// Injects an [AppStrings] table below it; absent, [AppStrings.of] returns
/// English. Wrap the app in this once locale selection exists.
class AppStringsScope extends InheritedWidget {
  /// Creates a scope.
  const AppStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  /// The active string table.
  final AppStrings strings;

  /// Nearest scope's strings, or null.
  static AppStrings? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStringsScope>()?.strings;

  @override
  bool updateShouldNotify(AppStringsScope oldWidget) =>
      oldWidget.strings != strings;
}
