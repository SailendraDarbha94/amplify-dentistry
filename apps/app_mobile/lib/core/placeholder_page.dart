import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_strings.dart';

/// Stand-in page for a feature that a later build fills in. Features
/// replace the routes that point here; this widget stays for anything that
/// is still pending.
class PlaceholderPage extends StatelessWidget {
  /// Creates a placeholder page titled [title].
  const PlaceholderPage({
    super.key,
    required this.title,
    this.icon = Icons.construction_outlined,
  });

  /// App bar title.
  final String title;

  /// Icon shown in the empty state.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(
        icon: icon,
        title: MobileStrings.comingInThisBuild,
        message: title,
        action: context.canPop()
            ? OutlinedButton(
                onPressed: () => context.pop(),
                child: Text(context.strings.back),
              )
            : null,
      ),
    );
  }
}

/// Builds a `GoRoute` that shows a [PlaceholderPage]; used by the feature
/// route files that are not implemented in this build.
GoRoute placeholderRoute(String path, String title, {IconData? icon}) =>
    GoRoute(
      path: path,
      builder: (context, state) => PlaceholderPage(
        title: title,
        icon: icon ?? Icons.construction_outlined,
      ),
    );
