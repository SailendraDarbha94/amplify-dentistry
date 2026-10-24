import 'dart:typed_data';

import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';

/// Turns the drawn strokes into PNG bytes; null when nothing was drawn.
typedef SignatureExporter = Future<Uint8List?> Function(
  SignatureController controller,
);

/// The exporter the pages use. Rasterising needs a real engine, so widget
/// tests override this with a fake that hashes the stroke points.
final Provider<SignatureExporter> signatureExporterProvider =
    Provider<SignatureExporter>((ref) => exportSignaturePng);

/// Exports the drawn strokes as PNG, or null when the pad is empty.
Future<Uint8List?> exportSignaturePng(SignatureController controller) async {
  if (controller.isEmpty) return null;
  return controller.toPngBytes();
}

/// Creates a controller with the pen settings used across the app.
SignatureController newSignatureController() => SignatureController(
  penStrokeWidth: 3,
  penColor: Colors.black,
  exportBackgroundColor: Colors.white,
  exportPenColor: Colors.black,
);

/// Stylus/finger signature pad with a clear button. The parent owns the
/// [controller]; read `controller.isNotEmpty` to know whether a signature
/// exists and [exportSignaturePng] to get the image.
class SignaturePadField extends StatelessWidget {
  /// Creates the pad.
  const SignaturePadField({
    super.key,
    required this.controller,
    this.height = 160,
    this.caption = 'Sign here',
    this.padKey,
  });

  /// Stroke controller.
  final SignatureController controller;

  /// Canvas height in logical pixels.
  final double height;

  /// Placeholder text shown while the pad is empty.
  final String caption;

  /// Key for the drawable canvas (tests drag on it).
  final Key? padKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: AppRadii.mdAll,
          ),
          clipBehavior: Clip.antiAlias,
          child: Signature(
            key: padKey,
            controller: controller,
            height: height,
            backgroundColor: Colors.white,
            placeholder: Center(
              child: Text(
                caption,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.black38,
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey('signature-clear'),
            onPressed: controller.clear,
            icon: const Icon(Icons.undo),
            label: Text(context.strings.clear),
          ),
        ),
      ],
    );
  }
}
