import 'package:ampdent_chart_engine/ampdent_chart_engine.dart';
import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/chart/chart_mapping.dart';
import 'package:ampdent_mobile/features/chart/preop_guard.dart';
import 'package:flutter_test/flutter_test.dart';

ProcedureRecord _procedure(
  String code, {
  ProcedureStatus status = ProcedureStatus.planned,
  String surfaces = '',
  String tooth = '16',
}) {
  final t = DateTime.utc(2026, 10, 20);
  return ProcedureRecord(
    id: 'p-$code-${status.name}',
    clinicId: 'c',
    patientId: 'pt',
    catalogItemId: 'cat-$code',
    code: code,
    name: code,
    tooth: ToothId.parse(tooth),
    surfaces: SurfaceSet.parse(surfaces),
    treatmentArea: TreatmentArea.tooth,
    status: status,
    providerId: 'm',
    fee: const Money.rupees(1000),
    createdAt: t,
    updatedAt: t,
  );
}

Finding _finding({
  String tooth = '16',
  String surfaces = 'MO',
  IcdasCode? icdas = IcdasCode.distinctCavity,
  String description = 'Caries',
  FindingStatus status = FindingStatus.active,
}) {
  final t = DateTime.utc(2026, 10, 20);
  return Finding(
    id: 'f-$tooth-$description',
    clinicId: 'c',
    patientId: 'pt',
    tooth: ToothId.parse(tooth),
    surfaces: SurfaceSet.parse(surfaces),
    description: description,
    icdas: icdas,
    status: status,
    recordedAt: t,
    recordedBy: 'm',
    createdAt: t,
    updatedAt: t,
  );
}

void main() {
  group('classifyProcedure', () {
    test('maps catalogue codes to chart families', () {
      expect(classifyProcedure('RCT-MOL'), ProcedureKind.rootCanal);
      expect(classifyProcedure('RERCT'), ProcedureKind.rootCanal);
      expect(classifyProcedure('CRN-ZIR'), ProcedureKind.crown);
      expect(classifyProcedure('BRG-PFM-UNIT'), ProcedureKind.crown);
      expect(classifyProcedure('EXT-SIMPLE'), ProcedureKind.extraction);
      expect(classifyProcedure('IMP-PLACE'), ProcedureKind.implant);
      expect(classifyProcedure('COMP-POST-2'), ProcedureKind.restoration);
      expect(classifyProcedure('GIC-1'), ProcedureKind.restoration);
      expect(classifyProcedure('PFS'), ProcedureKind.sealant);
      expect(classifyProcedure('VNR-CER'), ProcedureKind.veneer);
      expect(classifyProcedure('SCALING-ADULT'), ProcedureKind.other);
    });

    test('falls back to the category for custom codes', () {
      expect(
        classifyProcedure('MY-FILL', category: ProcedureCategory.restorative),
        ProcedureKind.restoration,
      );
      expect(
        classifyProcedure('MY-ENDO', category: ProcedureCategory.endodontic),
        ProcedureKind.rootCanal,
      );
    });

    test('pre-op guard applies to endo, extraction, implant and crown', () {
      expect(procedureNeedsPreOpRadiograph(ProcedureKind.rootCanal), isTrue);
      expect(procedureNeedsPreOpRadiograph(ProcedureKind.extraction), isTrue);
      expect(procedureNeedsPreOpRadiograph(ProcedureKind.implant), isTrue);
      expect(procedureNeedsPreOpRadiograph(ProcedureKind.crown), isTrue);
      expect(procedureNeedsPreOpRadiograph(ProcedureKind.restoration), isFalse);
      expect(
        procedureNeedsPreOpRadiograph(
          ProcedureKind.restoration,
          catalogFlag: true,
        ),
        isTrue,
      );
    });
  });

  group('overlays', () {
    test('planned vs completed restoration keeps surfaces', () {
      final planned = overlayForProcedure(
        _procedure('COMP-POST-2', surfaces: 'MO'),
        ProcedureKind.restoration,
      );
      expect(planned!.kind, OverlayKind.plannedRestoration);
      expect(planned.surfaces, SurfaceSet.parse('MO'));
      final done = overlayForProcedure(
        _procedure(
          'COMP-POST-2',
          surfaces: 'MO',
          status: ProcedureStatus.completed,
        ),
        ProcedureKind.restoration,
      );
      expect(done!.kind, OverlayKind.restoration);
    });

    test('rct, crown, extraction and implant map by status', () {
      expect(
        overlayForProcedure(
          _procedure('RCT-MOL'),
          ProcedureKind.rootCanal,
        )!.kind,
        OverlayKind.plannedRootCanal,
      );
      expect(
        overlayForProcedure(
          _procedure('RCT-MOL', status: ProcedureStatus.completed),
          ProcedureKind.rootCanal,
        )!.kind,
        OverlayKind.rootCanal,
      );
      expect(
        overlayForProcedure(_procedure('CRN-ZIR'), ProcedureKind.crown)!.kind,
        OverlayKind.plannedCrown,
      );
      expect(
        overlayForProcedure(
          _procedure('EXT-SIMPLE'),
          ProcedureKind.extraction,
        )!.kind,
        OverlayKind.extractionPlanned,
      );
      expect(
        overlayForProcedure(
          _procedure('EXT-SIMPLE', status: ProcedureStatus.completed),
          ProcedureKind.extraction,
        )!.kind,
        OverlayKind.missing,
      );
      expect(
        overlayForProcedure(
          _procedure('IMP-PLACE', status: ProcedureStatus.completed),
          ProcedureKind.implant,
        )!.kind,
        OverlayKind.implant,
      );
      expect(
        overlayForProcedure(
          _procedure('RCT-MOL', status: ProcedureStatus.deleted),
          ProcedureKind.rootCanal,
        ),
        isNull,
      );
    });

    test('findings: caries carries surfaces, resolved draws nothing', () {
      final caries = overlayForFinding(_finding());
      expect(caries!.kind, OverlayKind.caries);
      expect(caries.surfaces, SurfaceSet.parse('MO'));
      expect(
        overlayForFinding(_finding(status: FindingStatus.resolved)),
        isNull,
      );
      expect(
        overlayForFinding(
          _finding(icdas: null, description: 'Fractured tooth', surfaces: ''),
        )!.kind,
        OverlayKind.fracture,
      );
    });

    test('buildToothVisuals merges states, findings and procedures', () {
      final states = defaultToothStates(ageYears: 30);
      final visuals = buildToothVisuals(
        states: states,
        findings: [_finding()],
        procedures: [
          _procedure('RCT-MOL', tooth: '26'),
          _procedure('COMP-POST-2', surfaces: 'O', tooth: '16'),
        ],
      );
      final t16 = visuals[ToothId.parse('16')]!;
      expect(t16.state, ToothState.present);
      expect(t16.badgeCount, 1);
      expect(
        t16.overlays.map((o) => o.kind),
        containsAll([OverlayKind.caries, OverlayKind.plannedRestoration]),
      );
      // Planned marks paint last.
      expect(t16.overlays.last.kind, OverlayKind.plannedRestoration);
      expect(
        visuals[ToothId.parse('26')]!.overlays.single.kind,
        OverlayKind.plannedRootCanal,
      );
      expect(visuals[ToothId.parse('11')]!.overlays, isEmpty);
      expect(visuals.length, states.length);
    });
  });

  group('mixed dentition default', () {
    test('on under 12.5 years or when a primary tooth is present', () {
      expect(mixedDentitionDefault(8, const {}), isTrue);
      expect(mixedDentitionDefault(30, const {}), isFalse);
      expect(mixedDentitionDefault(null, const {}), isFalse);
      expect(
        mixedDentitionDefault(14, {ToothId.parse('55'): ToothState.present}),
        isTrue,
      );
      expect(
        mixedDentitionDefault(14, {ToothId.parse('55'): ToothState.exfoliated}),
        isFalse,
      );
    });
  });

  group('checkPreOpRadiograph', () {
    ImageRecord image(String id, ImageKind kind, List<String> teeth) =>
        ImageRecord(
          id: id,
          clinicId: 'c',
          patientId: 'pt',
          kind: kind,
          filePath: '/tmp/$id.jpg',
          capturedAt: DateTime.utc(2026, 10, 1),
          teeth: teeth.map(ToothId.parse).toList(),
          createdAt: DateTime.utc(2026, 10, 1),
        );

    test('blocks an endo start with nothing on record', () {
      final check = checkProcedurePreOp(
        _procedure('RCT-MOL'),
        kind: ProcedureKind.rootCanal,
        images: [
          image('photo', ImageKind.photoIntraoral, ['16']),
        ],
      );
      expect(check.outcome, PreOpOutcome.missing);
      expect(check.blocks, isTrue);
      expect(check.candidates, isEmpty);
    });

    test('auto-attaches a periapical of the same tooth', () {
      final check = checkProcedurePreOp(
        _procedure('RCT-MOL'),
        kind: ProcedureKind.rootCanal,
        images: [
          image('iopa', ImageKind.periapical, ['16']),
          image('other', ImageKind.periapical, ['36']),
        ],
      );
      expect(check.outcome, PreOpOutcome.satisfied);
      expect(check.attachedImageIds, ['iopa']);
      expect(check.candidates.length, 2);
    });

    test('does not ask again once work is in progress or reasoned', () {
      expect(
        checkProcedurePreOp(
          _procedure('RCT-MOL', status: ProcedureStatus.inProgress),
          kind: ProcedureKind.rootCanal,
        ).outcome,
        PreOpOutcome.notRequired,
      );
      final reasoned = _procedure(
        'RCT-MOL',
      ).copyWith(note: appendPreOpReason(null, 'Patient pregnant, deferred'));
      expect(
        checkProcedurePreOp(reasoned, kind: ProcedureKind.rootCanal).outcome,
        PreOpOutcome.satisfied,
      );
      expect(
        checkProcedurePreOp(
          _procedure('COMP-POST-2'),
          kind: ProcedureKind.restoration,
        ).outcome,
        PreOpOutcome.notRequired,
      );
    });

    test('resolution needs an image or a real reason', () {
      expect(const PreOpResolution().isValid, isFalse);
      expect(const PreOpResolution(reason: 'ok').isValid, isFalse);
      expect(const PreOpResolution(reason: 'Refused').isValid, isTrue);
      expect(const PreOpResolution(imageIds: ['x']).isValid, isTrue);
    });
  });
}
