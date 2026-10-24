import 'dart:ui';

import '../model/tooth_overlay.dart';

/// Colours and metrics for the odontogram. Use [OdontogramStyle.light] or
/// [OdontogramStyle.dark], or [OdontogramStyle.of] for a brightness.
class OdontogramStyle {
  const OdontogramStyle({
    required this.brightness,
    required this.toothFill,
    required this.toothOutline,
    required this.rootFill,
    required this.rootOutline,
    required this.absentOutline,
    required this.missingMark,
    required this.eruptingFill,
    required this.labelColor,
    required this.midlineColor,
    required this.selectedRing,
    required this.selectedSurfaceFill,
    required this.badgeFill,
    required this.badgeText,
    required this.planned,
    required this.overlayColors,
    this.outlineWidth = 1.0,
    this.selectedRingWidth = 2.5,
    this.hatchSpacing = 4.0,
    this.labelFontSize = 11.0,
    this.fontFamily,
  });

  /// Whether this is the light or dark variant.
  final Brightness brightness;

  /// Crown fill for a present tooth.
  final Color toothFill;

  /// Crown and surface-division stroke.
  final Color toothOutline;

  /// Root fill.
  final Color rootFill;

  /// Root stroke.
  final Color rootOutline;

  /// Ghost outline for absent (missing / extracted) teeth.
  final Color absentOutline;

  /// Grey X drawn over a missing tooth.
  final Color missingMark;

  /// Lighter crown fill for erupting / impacted teeth.
  final Color eruptingFill;

  /// Tooth number labels.
  final Color labelColor;

  /// Dashed midline between the quadrants.
  final Color midlineColor;

  /// Amber ring around the selected tooth.
  final Color selectedRing;

  /// Highlight fill for selected surfaces.
  final Color selectedSurfaceFill;

  /// Badge disc colour.
  final Color badgeFill;

  /// Badge count text colour.
  final Color badgeText;

  /// Blue used for all planned (hatched / outlined) work.
  final Color planned;

  /// Fill colour per overlay kind.
  final Map<OverlayKind, Color> overlayColors;

  /// Stroke width for outlines, in logical pixels.
  final double outlineWidth;

  /// Stroke width of the selection ring.
  final double selectedRingWidth;

  /// Spacing between hatch lines for planned work.
  final double hatchSpacing;

  /// Base label font size (scaled with tooth width).
  final double labelFontSize;

  /// Optional font family for labels (null = default).
  final String? fontFamily;

  /// Colour for an overlay, honouring its override.
  Color colorFor(ToothOverlay overlay) {
    final override = overlay.colorValue;
    if (override != null) return Color(override);
    return overlayColors[overlay.kind] ?? planned;
  }

  /// Picks the variant for [brightness].
  static OdontogramStyle of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Shared overlay palette: caries red, existing work grey, planned blue,
  /// crowns gold, implants steel, root canal orange.
  static const Map<OverlayKind, Color> _overlayPalette = {
    OverlayKind.caries: Color(0xFFD32F2F),
    OverlayKind.restoration: Color(0xFF8D99A6),
    OverlayKind.plannedRestoration: Color(0xFF1E6FD9),
    OverlayKind.rootCanal: Color(0xFFEF6C00),
    OverlayKind.plannedRootCanal: Color(0xFF1E6FD9),
    OverlayKind.crown: Color(0xFFC9A227),
    OverlayKind.plannedCrown: Color(0xFF1E6FD9),
    OverlayKind.bridgeAbutment: Color(0xFFC9A227),
    OverlayKind.bridgePontic: Color(0xFFE2C86A),
    OverlayKind.implant: Color(0xFF546E7A),
    OverlayKind.plannedImplant: Color(0xFF1E6FD9),
    OverlayKind.extractionPlanned: Color(0xFFD32F2F),
    OverlayKind.missing: Color(0xFF9E9E9E),
    OverlayKind.fracture: Color(0xFF8E0000),
    OverlayKind.sealant: Color(0xFF26A69A),
    OverlayKind.veneer: Color(0xFFB39DDB),
    OverlayKind.watch: Color(0xFFFFA000),
    OverlayKind.custom: Color(0xFF7B1FA2),
  };

  /// Light theme palette.
  static const OdontogramStyle light = OdontogramStyle(
    brightness: Brightness.light,
    toothFill: Color(0xFFFFFFFF),
    toothOutline: Color(0xFF4A4A4A),
    rootFill: Color(0xFFF1E9DD),
    rootOutline: Color(0xFF8C8273),
    absentOutline: Color(0xFFBDBDBD),
    missingMark: Color(0xFF9E9E9E),
    eruptingFill: Color(0xFFF5F5F5),
    labelColor: Color(0xFF333333),
    midlineColor: Color(0xFFBDBDBD),
    selectedRing: Color(0xFFFFB300),
    selectedSurfaceFill: Color(0x66FFB300),
    badgeFill: Color(0xFFD32F2F),
    badgeText: Color(0xFFFFFFFF),
    planned: Color(0xFF1E6FD9),
    overlayColors: _overlayPalette,
  );

  /// Dark theme palette.
  static const OdontogramStyle dark = OdontogramStyle(
    brightness: Brightness.dark,
    toothFill: Color(0xFF2B2F36),
    toothOutline: Color(0xFFD0D4DA),
    rootFill: Color(0xFF3A3630),
    rootOutline: Color(0xFFA09686),
    absentOutline: Color(0xFF5C6066),
    missingMark: Color(0xFF8A8F96),
    eruptingFill: Color(0xFF34393F),
    labelColor: Color(0xFFE6E8EB),
    midlineColor: Color(0xFF5C6066),
    selectedRing: Color(0xFFFFC107),
    selectedSurfaceFill: Color(0x66FFC107),
    badgeFill: Color(0xFFEF5350),
    badgeText: Color(0xFFFFFFFF),
    planned: Color(0xFF64A5FF),
    overlayColors: _overlayPalette,
  );
}
