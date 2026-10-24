import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/material.dart';

import '../layout/odontogram_layout.dart';
import '../model/tooth_overlay.dart';
import '../painting/chart_text_cache.dart';
import '../painting/odontogram_painter.dart';
import '../style/odontogram_style.dart';

/// Interactive odontogram. Lays out both arches as the clinician views the
/// patient, hit-tests taps to a tooth and then a surface, and scrolls
/// horizontally when the width cannot hold 16 teeth at 44 px each.
///
/// Tap behaviour: a tap on an unselected tooth calls [onToothTap]; a tap on
/// a surface of the already [selectedTooth] calls [onSurfaceTap].
class Odontogram extends StatefulWidget {
  const Odontogram({
    super.key,
    required this.teeth,
    required this.notation,
    this.selectedTooth,
    this.selectedSurfaces = const SurfaceSet.empty(),
    this.mixedDentition = false,
    this.style,
    this.onToothTap,
    this.onSurfaceTap,
    this.onToothLongPress,
    this.compact = false,
    this.showUnerupted = false,
  });

  /// Visual per tooth; teeth missing from the map are not drawn.
  final Map<ToothId, ToothVisual> teeth;

  /// Numbering system for the labels (Palmer uses plain text, e.g. `UR6`).
  final ToothNotation notation;

  /// Tooth drawn with the selection ring.
  final ToothId? selectedTooth;

  /// Surfaces of [selectedTooth] drawn highlighted.
  final SurfaceSet selectedSurfaces;

  /// Draw the primary rows between the permanent rows.
  final bool mixedDentition;

  /// Palette; defaults to the variant matching the ambient brightness.
  final OdontogramStyle? style;
  final void Function(ToothId tooth)? onToothTap;
  final void Function(ToothId tooth, ToothSurface surface)? onSurfaceTap;
  final void Function(ToothId tooth)? onToothLongPress;

  /// Stack the four quadrant rows (8 teeth per row) for narrow screens.
  final bool compact;

  /// Also draw unerupted teeth (faint) instead of hiding them.
  final bool showUnerupted;

  @override
  State<Odontogram> createState() => _OdontogramState();
}

class _OdontogramState extends State<Odontogram> {
  final ToothLayoutCache _layouts = ToothLayoutCache();
  final ChartTextCache _text = ChartTextCache();
  OdontogramLayout? _current;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  List<ToothId> _visible() => visibleTeeth({
    for (final e in widget.teeth.entries) e.key: e.value.state,
  }, showUnerupted: widget.showUnerupted);

  void _handleTap(Offset local) {
    final layout = _current;
    if (layout == null) return;
    final hit = layout.hitTest(local);
    if (hit == null) return;
    final surface = hit.surface;
    if (hit.tooth == widget.selectedTooth &&
        surface != null &&
        widget.onSurfaceTap != null) {
      widget.onSurfaceTap!(hit.tooth, surface);
    } else {
      widget.onToothTap?.call(hit.tooth);
    }
  }

  void _handleLongPress(Offset local) {
    final tooth = _current?.toothAt(local);
    if (tooth != null) widget.onToothLongPress?.call(tooth);
  }

  @override
  Widget build(BuildContext context) {
    final style =
        widget.style ?? OdontogramStyle.of(Theme.of(context).brightness);
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = OdontogramLayoutSpec(
          availableWidth: constraints.maxWidth,
          availableHeight: constraints.hasBoundedHeight
              ? constraints.maxHeight
              : double.infinity,
          compact: widget.compact,
          mixedDentition: widget.mixedDentition,
          visibleTeeth: _visible(),
        );
        final layout = _layouts.layoutFor(spec);
        _current = layout;
        final chart = SizedBox(
          width: layout.size.width,
          height: layout.size.height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _handleTap(d.localPosition),
            onLongPressStart: widget.onToothLongPress == null
                ? null
                : (d) => _handleLongPress(d.localPosition),
            child: RepaintBoundary(
              child: CustomPaint(
                size: layout.size,
                painter: OdontogramPainter(
                  layout: layout,
                  teeth: widget.teeth,
                  notation: widget.notation,
                  style: style,
                  textCache: _text,
                  selectedTooth: widget.selectedTooth,
                  selectedSurfaces: widget.selectedSurfaces,
                ),
              ),
            ),
          ),
        );
        if (layout.overflowsWidth) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: chart,
          );
        }
        return Align(alignment: Alignment.topCenter, child: chart);
      },
    );
  }
}
