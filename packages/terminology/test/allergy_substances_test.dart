import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:test/test.dart';

void main() {
  group('inferAllergyGroup', () {
    test(
      'generic names, brands and shorthand map to the drug master groups',
      () {
        expect(inferAllergyGroup('Amoxicillin'), AllergyGroups.penicillin);
        expect(
          inferAllergyGroup('allergic to AUGMENTIN'),
          AllergyGroups.penicillin,
        );
        expect(inferAllergyGroup('Mox 500'), AllergyGroups.penicillin);
        expect(inferAllergyGroup('Penicillin V'), AllergyGroups.penicillin);
        expect(inferAllergyGroup('cefixime'), AllergyGroups.cephalosporin);
        expect(inferAllergyGroup('Ibuprofen'), AllergyGroups.nsaid);
        expect(inferAllergyGroup('Brufen'), AllergyGroups.nsaid);
        expect(inferAllergyGroup('Diclofenac gel'), AllergyGroups.nsaid);
        expect(inferAllergyGroup('aspirin'), AllergyGroups.nsaid);
        expect(inferAllergyGroup('Septran'), AllergyGroups.sulfa);
        expect(inferAllergyGroup('lignocaine'), AllergyGroups.localAnaesthetic);
        expect(inferAllergyGroup('Lidocaine'), AllergyGroups.localAnaesthetic);
        expect(
          inferAllergyGroup('Lignox 2% A'),
          AllergyGroups.localAnaesthetic,
        );
        expect(inferAllergyGroup('LA'), AllergyGroups.localAnaesthetic);
        expect(inferAllergyGroup('Azithromycin'), AllergyGroups.macrolide);
        expect(
          inferAllergyGroup('Levofloxacin'),
          AllergyGroups.fluoroquinolone,
        );
        expect(inferAllergyGroup('Tramadol'), AllergyGroups.opioid);
        expect(inferAllergyGroup('Alprax'), AllergyGroups.benzodiazepine);
        expect(inferAllergyGroup('Fluconazole'), AllergyGroups.azole);
        expect(inferAllergyGroup('Latex gloves'), 'latex');
        expect(inferAllergyGroup('peanuts'), 'food');
      },
    );

    test('does not mistake look-alike names for a group', () {
      // Nitroimidazole and PPIs end in -azole but are not azole antifungals.
      expect(inferAllergyGroup('Metronidazole'), isNull);
      expect(inferAllergyGroup('Pantoprazole'), isNull);
      // Clindamycin is a lincosamide, not a macrolide.
      expect(inferAllergyGroup('Clindamycin'), isNull);
      // `lox` is only an alias as a whole word; it is inside levoflox.
      expect(inferAllergyGroup('Levoflox'), AllergyGroups.fluoroquinolone);
      expect(inferAllergyGroup('Paracetamol'), isNull);
      expect(inferAllergyGroup('dust'), isNull);
      expect(inferAllergyGroup('   '), isNull);
    });

    test('normalisation folds case and punctuation', () {
      expect(
        normaliseAllergySubstance('  Amoxi-Clav (Augmentin)! '),
        'amoxi-clav augmentin',
      );
      expect(
        inferAllergyGroup('AMOXI-CLAV (Augmentin)!'),
        AllergyGroups.penicillin,
      );
    });
  });
}
