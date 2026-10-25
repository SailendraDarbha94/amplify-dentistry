/// Maps free-typed allergy substances to the normalised allergy groups used
/// by the prescribing cross-check, so an entry such as `Augmentin` or
/// `lignocaine` blocks the matching drugs even when no group chip was tapped.
library;

import 'drug_master.dart';

/// Lower-case fragments that identify a group when they occur anywhere in
/// the substance text (`amoxicillin`, `brufen 400`, `allergic to augmentin`).
/// Every fragment is specific enough not to appear inside unrelated drug
/// names; short or ambiguous aliases live in [_allergyGroupTokens] instead.
const Map<String, List<String>> _allergyGroupFragments = {
  AllergyGroups.penicillin: [
    'penicillin',
    'penicilin',
    'cillin',
    'augmentin',
    'clavulan',
    'clavam',
    'moxikind',
    'novamox',
    'almox',
    'moxclav',
  ],
  AllergyGroups.cephalosporin: [
    'cephalosporin',
    'cephalexin',
    'cefadroxil',
    'cefixime',
    'cefuroxime',
    'ceftriaxone',
    'cefpodoxime',
    'cefotaxime',
    'taxim',
    'zifi',
    'cefolac',
    'ceftum',
    'zocef',
    'altacef',
    'monocef',
    'oframax',
  ],
  AllergyGroups.nsaid: [
    'nsaid',
    'ibuprofen',
    'brufen',
    'ibugesic',
    'combiflam',
    'diclofenac',
    'voveran',
    'diclomol',
    'reactin',
    'aceclofenac',
    'zerodol',
    'hifenac',
    'aceclo',
    'ketorolac',
    'ketorol',
    'ketanov',
    'etoricoxib',
    'etoshine',
    'nucoxia',
    'aspirin',
    'salicylate',
    'disprin',
    'ecosprin',
    'naproxen',
    'mefenamic',
    'meftal',
    'nimesulide',
    'piroxicam',
    'indomethacin',
    'celecoxib',
    'painkiller',
    'pain killer',
  ],
  AllergyGroups.sulfa: [
    'sulfa',
    'sulpha',
    'sulfonamide',
    'sulphonamide',
    'septran',
    'bactrim',
    'trimoxazole',
    'sulfamethoxazole',
    'sulfasalazine',
  ],
  AllergyGroups.localAnaesthetic: [
    'lignocaine',
    'lidocaine',
    'xylocaine',
    'lignox',
    'articaine',
    'septanest',
    'ubistesin',
    'bupivacaine',
    'mepivacaine',
    'prilocaine',
    'procaine',
    'benzocaine',
    'local anaesth',
    'local anesth',
  ],
  AllergyGroups.macrolide: ['macrolide', 'thromycin', 'azithral', 'zithromax'],
  AllergyGroups.fluoroquinolone: [
    'quinolone',
    'floxacin',
    'levoflox',
    'glevo',
    'ciplox',
    'oflomac',
    'zenflox',
    'zanocin',
    'norflox',
  ],
  AllergyGroups.opioid: [
    'opioid',
    'opiate',
    'tramadol',
    'ultracet',
    'tramazac',
    'contramal',
    'codeine',
    'morphine',
    'tapentadol',
    'pentazocine',
    'fortwin',
    'fentanyl',
    'buprenorphine',
  ],
  AllergyGroups.benzodiazepine: [
    'benzodiazepine',
    'alprazolam',
    'alprax',
    'restyl',
    'diazepam',
    'valium',
    'calmpose',
    'lorazepam',
    'ativan',
    'clonazepam',
    'midazolam',
  ],
  AllergyGroups.azole: [
    'fluconazole',
    'conazole',
    'clotrimazole',
    'forcan',
    'flucos',
    'zocon',
    'clotrin',
    'antifungal',
  ],
  'latex': ['latex', 'rubber glove'],
  'food': [
    'peanut',
    'groundnut',
    'shellfish',
    'prawn',
    'seafood',
    'gluten',
    'lactose',
    'dairy',
  ],
};

/// Short aliases matched only as whole words, because as fragments they would
/// hit unrelated names (`lox` is inside `levoflox`, `mox` inside `moxikind`
/// is fine but `o2` is a brand on its own).
const Map<String, List<String>> _allergyGroupTokens = {
  AllergyGroups.penicillin: ['mox', 'pen', 'penv', 'pen-v'],
  AllergyGroups.localAnaesthetic: ['lox', 'la'],
  AllergyGroups.macrolide: ['azee'],
  AllergyGroups.fluoroquinolone: ['o2'],
  AllergyGroups.benzodiazepine: ['trika'],
  AllergyGroups.azole: ['candid'],
  'food': ['egg', 'eggs', 'milk', 'nuts', 'fish', 'soy', 'wheat'],
};

/// Normalises substance text for matching: lower case, punctuation other
/// than `-`/`%` folded to spaces, whitespace collapsed.
String normaliseAllergySubstance(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9%\-]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The allergy group implied by a free-typed [substance], or null when the
/// text names nothing the drug master knows. Case-insensitive; brand names
/// common in India are recognised (`Augmentin` -> `penicillin`, `Brufen`
/// -> `nsaid`, `Lignox` -> `localAnaesthetic`).
String? inferAllergyGroup(String substance) {
  final text = normaliseAllergySubstance(substance);
  if (text.isEmpty) return null;
  for (final entry in _allergyGroupFragments.entries) {
    for (final fragment in entry.value) {
      if (text.contains(fragment)) return entry.key;
    }
  }
  final tokens = text.split(' ').toSet();
  for (final entry in _allergyGroupTokens.entries) {
    if (entry.value.any(tokens.contains)) return entry.key;
  }
  return null;
}
