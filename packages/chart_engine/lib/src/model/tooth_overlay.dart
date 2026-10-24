import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/foundation.dart';

/// Kinds of visual annotation an odontogram can draw on a tooth. Planned
/// variants render hatched / outlined in the style's planned colour; the
/// others render filled.
enum OverlayKind {
  caries,
  restoration,
  plannedRestoration,
  rootCanal,
  plannedRootCanal,
  crown,
  plannedCrown,
  bridgeAbutment,
  bridgePontic,
  implant,
  plannedImplant,
  extractionPlanned,
  missing,
  fracture,
  sealant,
  veneer,
  watch,
  custom;

  /// Whether this kind is treatment-planned (drawn hatched / outlined).
  bool get isPlanned =>
      this == plannedRestoration ||
      this == plannedRootCanal ||
      this == plannedCrown ||
      this == plannedImplant ||
      this == extractionPlanned;

  /// Whether this kind is painted onto specific surfaces (needs a
  /// [ToothOverlay.surfaces] set to draw anything).
  bool get isSurfaceBased =>
      this == caries ||
      this == restoration ||
      this == plannedRestoration ||
      this == sealant ||
      this == veneer ||
      this == custom;

  /// Short legend label.
  String get label => switch (this) {
    OverlayKind.caries => 'Caries',
    OverlayKind.restoration => 'Restoration',
    OverlayKind.plannedRestoration => 'Planned restoration',
    OverlayKind.rootCanal => 'Root canal',
    OverlayKind.plannedRootCanal => 'Planned root canal',
    OverlayKind.crown => 'Crown',
    OverlayKind.plannedCrown => 'Planned crown',
    OverlayKind.bridgeAbutment => 'Bridge abutment',
    OverlayKind.bridgePontic => 'Bridge pontic',
    OverlayKind.implant => 'Implant',
    OverlayKind.plannedImplant => 'Planned implant',
    OverlayKind.extractionPlanned => 'Extraction planned',
    OverlayKind.missing => 'Missing',
    OverlayKind.fracture => 'Fracture',
    OverlayKind.sealant => 'Sealant',
    OverlayKind.veneer => 'Veneer',
    OverlayKind.watch => 'Watch',
    OverlayKind.custom => 'Other',
  };
}

/// One immutable visual annotation on a tooth.
@immutable
class ToothOverlay {
  const ToothOverlay({
    required this.kind,
    this.surfaces,
    this.label,
    this.colorValue,
  });

  /// What to draw.
  final OverlayKind kind;

  /// Surfaces the annotation covers; null or empty means the whole tooth.
  final SurfaceSet? surfaces;

  /// Optional short text drawn over the crown (for example a material code).
  final String? label;

  /// Optional ARGB colour override replacing the style's colour for [kind].
  final int? colorValue;

  /// Copy with changed fields.
  ToothOverlay copyWith({
    OverlayKind? kind,
    SurfaceSet? surfaces,
    String? label,
    int? colorValue,
  }) => ToothOverlay(
    kind: kind ?? this.kind,
    surfaces: surfaces ?? this.surfaces,
    label: label ?? this.label,
    colorValue: colorValue ?? this.colorValue,
  );

  /// JSON form (surfaces as the canonical surface string).
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    if (surfaces != null) 'surfaces': surfaces!.code,
    if (label != null) 'label': label,
    if (colorValue != null) 'color': colorValue,
  };

  /// Parses [toJson] output.
  factory ToothOverlay.fromJson(Map<String, Object?> json) => ToothOverlay(
    kind: OverlayKind.values.byName(json['kind'] as String),
    surfaces: json['surfaces'] == null
        ? null
        : SurfaceSet.parse(json['surfaces'] as String),
    label: json['label'] as String?,
    colorValue: json['color'] as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is ToothOverlay &&
      other.kind == kind &&
      other.surfaces == surfaces &&
      other.label == label &&
      other.colorValue == colorValue;

  @override
  int get hashCode => Object.hash(kind, surfaces, label, colorValue);

  @override
  String toString() =>
      'ToothOverlay(${kind.name}, ${surfaces?.code ?? "whole"})';
}

/// Everything the odontogram needs to draw one tooth.
@immutable
class ToothVisual {
  const ToothVisual({
    required this.tooth,
    required this.state,
    this.overlays = const [],
    this.badgeCount = 0,
  });

  final ToothId tooth;
  final ToothState state;

  /// Annotations drawn in order (later overlays paint on top).
  final List<ToothOverlay> overlays;

  /// Count shown in a small badge (open findings, notes...); 0 hides it.
  final int badgeCount;

  /// Copy with changed fields.
  ToothVisual copyWith({
    ToothState? state,
    List<ToothOverlay>? overlays,
    int? badgeCount,
  }) => ToothVisual(
    tooth: tooth,
    state: state ?? this.state,
    overlays: overlays ?? this.overlays,
    badgeCount: badgeCount ?? this.badgeCount,
  );

  /// JSON form (tooth as its FDI storage key).
  Map<String, Object?> toJson() => {
    'tooth': tooth.storageKey,
    'state': state.name,
    'overlays': overlays.map((o) => o.toJson()).toList(),
    'badgeCount': badgeCount,
  };

  /// Parses [toJson] output.
  factory ToothVisual.fromJson(Map<String, Object?> json) => ToothVisual(
    tooth: ToothId.parse(json['tooth'] as String),
    state: ToothState.values.byName(json['state'] as String),
    overlays: (json['overlays'] as List<Object?>? ?? const [])
        .map((o) => ToothOverlay.fromJson(o! as Map<String, Object?>))
        .toList(),
    badgeCount: json['badgeCount'] as int? ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is ToothVisual &&
      other.tooth == tooth &&
      other.state == state &&
      other.badgeCount == badgeCount &&
      listEquals(other.overlays, overlays);

  @override
  int get hashCode =>
      Object.hash(tooth, state, badgeCount, Object.hashAll(overlays));
}

/// Builds a plain visual map (no overlays) from a state map, e.g. the output
/// of `defaultToothStates(ageYears:)` from `ampdent_core`.
Map<ToothId, ToothVisual> toothVisualsFromStates(
  Map<ToothId, ToothState> states,
) => {
  for (final entry in states.entries)
    entry.key: ToothVisual(tooth: entry.key, state: entry.value),
};
