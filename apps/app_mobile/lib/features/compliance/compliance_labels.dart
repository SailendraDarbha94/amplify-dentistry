import 'package:ampdent_core/ampdent_core.dart';

/// Display label for an autoclave cycle type.
String cycleTypeLabel(SterilisationCycleType type) => switch (type) {
  SterilisationCycleType.classB => 'Class B',
  SterilisationCycleType.classN => 'Class N',
  SterilisationCycleType.classS => 'Class S',
  SterilisationCycleType.chemical => 'Chemical',
};

/// Display label for a spore-test result.
String biologicalResultLabel(BiologicalIndicatorResult? result) =>
    switch (result) {
      null || BiologicalIndicatorResult.notDone => 'Not done',
      BiologicalIndicatorResult.pending => 'Pending',
      BiologicalIndicatorResult.pass => 'Pass',
      BiologicalIndicatorResult.fail => 'Fail',
    };

/// Display label for a licence kind.
String licenceKindLabel(LicenceKind kind) => switch (kind) {
  LicenceKind.aerbRegistration => 'AERB X-ray registration',
  LicenceKind.biomedicalWasteAuthorisation => 'Biomedical waste authorisation',
  LicenceKind.clinicalEstablishmentRegistration =>
    'Clinical establishment registration',
  LicenceKind.tradeLicence => 'Trade licence',
  LicenceKind.fireNoc => 'Fire NOC',
  LicenceKind.gstRegistration => 'GST registration',
  LicenceKind.dentalCouncilRegistration => 'Dental council registration',
  LicenceKind.other => 'Other',
};

/// Short form of [licenceKindLabel] for chips and PDF columns.
String licenceKindShortLabel(LicenceKind kind) => switch (kind) {
  LicenceKind.aerbRegistration => 'AERB',
  LicenceKind.biomedicalWasteAuthorisation => 'BMW',
  LicenceKind.clinicalEstablishmentRegistration => 'CEA',
  LicenceKind.tradeLicence => 'Trade',
  LicenceKind.fireNoc => 'Fire',
  LicenceKind.gstRegistration => 'GST',
  LicenceKind.dentalCouncilRegistration => 'DCI',
  LicenceKind.other => 'Other',
};
