import 'package:flutter/material.dart';

/// Semantic colours that Material's [ColorScheme] does not name: statuses,
/// treatment-plan states and chart marks. Read with `AppColors.of(context)`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// Creates a semantic colour set.
  const AppColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.planned,
    required this.completed,
    required this.caries,
    required this.existing,
  });

  /// Light-mode palette tuned against a teal-blue seed.
  const AppColors.light()
    : success = const Color(0xFF1B7F3B),
      warning = const Color(0xFFB26A00),
      danger = const Color(0xFFB3261E),
      info = const Color(0xFF0B63B8),
      planned = const Color(0xFFC62828),
      completed = const Color(0xFF1565C0),
      caries = const Color(0xFFD32F2F),
      existing = const Color(0xFF455A64);

  /// Dark-mode palette with lighter tones for contrast on dark surfaces.
  const AppColors.dark()
    : success = const Color(0xFF6DD58C),
      warning = const Color(0xFFFFB95C),
      danger = const Color(0xFFFF8A80),
      info = const Color(0xFF7FB9FF),
      planned = const Color(0xFFFF7B7B),
      completed = const Color(0xFF86B6FF),
      caries = const Color(0xFFFF6B6B),
      existing = const Color(0xFFB0BEC5);

  /// Positive outcome: synced, paid, completed sterilisation cycle.
  final Color success;

  /// Needs attention soon: pending consent, due recall, low stock.
  final Color warning;

  /// Error or destructive: failed sync, overdue, delete.
  final Color danger;

  /// Neutral information: tips, counts, sync progress.
  final Color info;

  /// Treatment-planned work (dental convention: red).
  final Color planned;

  /// Completed work (dental convention: blue).
  final Color completed;

  /// Active caries marks on the odontogram.
  final Color caries;

  /// Pre-existing work done elsewhere (grey-blue).
  final Color existing;

  /// Resolves the extension from the nearest [Theme]; falls back to light.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? const AppColors.light();

  @override
  AppColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? planned,
    Color? completed,
    Color? caries,
    Color? existing,
  }) {
    return AppColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      planned: planned ?? this.planned,
      completed: completed ?? this.completed,
      caries: caries ?? this.caries,
      existing: existing ?? this.existing,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      planned: Color.lerp(planned, other.planned, t)!,
      completed: Color.lerp(completed, other.completed, t)!,
      caries: Color.lerp(caries, other.caries, t)!,
      existing: Color.lerp(existing, other.existing, t)!,
    );
  }
}
