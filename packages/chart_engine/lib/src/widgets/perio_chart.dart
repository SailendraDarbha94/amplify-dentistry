import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/material.dart';

import '../layout/perio_grid_layout.dart';
import '../painting/chart_text_cache.dart';
import '../painting/perio_grid_painter.dart';
import '../perio/perio_sequence.dart';
import '../style/perio_style.dart';

/// Called when a grid cell is tapped.
typedef PerioCellTap = void Function(
  ToothId tooth,
  PerioSite? site,
  PerioMeasurementType type,
);

/// Called when a value is entered for a cell (null clears it). Boolean
/// measurements pass 1 / 0.
typedef PerioValueEntered = void Function(
  ToothId tooth,
  PerioSite? site,
  PerioMeasurementType type,
  int? value,
);

/// Six-site periodontal chart for one arch and one aspect: a column per
/// tooth and rows for PD (3 sites), GM (3 sites), bleeding dots, plaque
/// dots, mobility and furcation. Scrolls horizontally when narrow.
class PerioChart extends StatefulWidget {
  const PerioChart({
    super.key,
    required this.arch,
    required this.aspect,
    required this.states,
    required this.readings,
    this.toothReadings = const [],
    this.focusedCell,
    this.onCellTap,
    this.onValueEntered,
    this.notation = ToothNotation.fdi,
    this.style,
    this.includeAbsent = true,
  });

  final Arch arch;
  final PerioAspect aspect;
  final Map<ToothId, ToothState> states;
  final List<PerioSiteReading> readings;
  final List<PerioToothReading> toothReadings;

  /// Highlighted (tooth, site), typically the entry cursor.
  final (ToothId, PerioSite)? focusedCell;
  final PerioCellTap? onCellTap;

  /// Invoked by [enterValue]; kept on the widget so an attached number pad
  /// and the grid share one callback.
  final PerioValueEntered? onValueEntered;

  /// Routes a value from an attached [PerioNumberPad] (or any other input)
  /// to [onValueEntered]. Null clears the cell; boolean measurements pass
  /// 1 / 0. Returns false when no callback is wired.
  bool enterValue(
    ToothId tooth,
    PerioSite? site,
    PerioMeasurementType type,
    int? value,
  ) {
    final cb = onValueEntered;
    if (cb == null) return false;
    cb(tooth, site, type, value);
    return true;
  }

  final ToothNotation notation;
  final PerioStyle? style;

  /// Keep columns for absent teeth (shaded) so positions stay aligned.
  final bool includeAbsent;

  /// Teeth shown as columns for these props, in viewer order.
  List<ToothId> columns() {
    final out = <ToothId>[];
    for (final t in ToothId.archRow(arch, Dentition.permanent)) {
      final s = states[t];
      if (s == null) continue;
      if (s.isDrawnPresent ||
          s == ToothState.implant ||
          (includeAbsent && s.isAbsent)) {
        out.add(t);
      }
    }
    for (final e in states.entries) {
      if (e.key.isPrimary && e.key.arch == arch && e.value.isDrawnPresent) {
        out.add(e.key);
      }
    }
    out.sort((a, b) => perioColumnOrder(a).compareTo(perioColumnOrder(b)));
    return out;
  }

  @override
  State<PerioChart> createState() => _PerioChartState();
}

class _PerioChartState extends State<PerioChart> {
  final ChartTextCache _text = ChartTextCache();
  PerioGridLayout? _layout;
  PerioGridSpec? _spec;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Map<(ToothId, PerioSite), PerioSiteReading> _indexReadings() => {
    for (final r in widget.readings) (r.tooth, r.site): r,
  };

  Map<ToothId, PerioToothReading> _indexToothReadings() => {
    for (final r in widget.toothReadings) r.tooth: r,
  };

  void _handleTap(Offset local) {
    final cell = _layout?.hitTest(local);
    if (cell == null) return;
    widget.onCellTap?.call(cell.tooth, cell.site, cell.type);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? PerioStyle.of(Theme.of(context).brightness);
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = PerioGridSpec(
          arch: widget.arch,
          aspect: widget.aspect,
          teeth: widget.columns(),
          availableWidth: constraints.maxWidth,
        );
        if (spec != _spec) {
          _spec = spec;
          _layout = PerioGridLayout.compute(spec);
        }
        final layout = _layout!;
        final grid = SizedBox(
          width: layout.size.width,
          height: layout.size.height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _handleTap(d.localPosition),
            child: RepaintBoundary(
              child: CustomPaint(
                size: layout.size,
                painter: PerioGridPainter(
                  layout: layout,
                  states: widget.states,
                  readings: _indexReadings(),
                  toothReadings: _indexToothReadings(),
                  notation: widget.notation,
                  style: style,
                  textCache: _text,
                  focusedCell: widget.focusedCell,
                ),
              ),
            ),
          ),
        );
        if (layout.overflowsWidth) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: grid,
          );
        }
        return Align(alignment: Alignment.topLeft, child: grid);
      },
    );
  }
}
