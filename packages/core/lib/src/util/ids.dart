import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a client-side UUID v4 string. Every entity id in the system is
/// one of these so rows can be created offline and merged on sync.
String newId() => _uuid.v4();

/// A lightweight typed wrapper is deliberately not used: ids are plain
/// strings to keep Drift, JSON and Supabase mappings trivial. These helpers
/// exist so callers never hand-roll validation.
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

bool isValidId(String id) => _uuidPattern.hasMatch(id);

/// Local draft document numbers (invoices, estimates) until the server mints
/// the sequential number on first sync.
String draftNumber(String prefix, DateTime now, int localSequence) =>
    'DRAFT-$prefix-${now.year}${now.month.toString().padLeft(2, '0')}-${localSequence.toString().padLeft(4, '0')}';

bool isDraftNumber(String number) => number.startsWith('DRAFT-');
