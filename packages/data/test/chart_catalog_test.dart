import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.open());
  tearDown(() => env.close());

  group('tooth states', () {
    test('history collapses to current states', () async {
      final chart = env.repos.chart;
      await chart.recordToothState(
        ctx,
        toothState('ts-1', '36', ToothState.present, t0),
      );
      await chart.recordToothState(
        ctx,
        toothState('ts-2', '36', ToothState.extracted, t1),
      );
      await chart.recordToothState(
        ctx,
        toothState('ts-3', '18', ToothState.missing, t0),
      );
      // Same effectiveFrom, later createdAt wins.
      await chart.recordToothState(
        ctx,
        toothState('ts-4', '18', ToothState.unerupted, t0, createdAt: t2),
      );
      final current = await chart.currentStates(patientId);
      expect(current[ToothId.parse('36')], ToothState.extracted);
      expect(current[ToothId.parse('18')], ToothState.unerupted);
      expect(
        await chart.toothStateHistory(patientId, tooth: ToothId.parse('36')),
        hasLength(2),
      );
      final watched = await chart.watchCurrentStates(patientId).first;
      expect(watched, equals(current));
    });
  });

  group('findings', () {
    test('add, resolve, soft delete', () async {
      final chart = env.repos.chart;
      final f = finding();
      await chart.addFinding(ctx, f);
      expect((await chart.getFinding(f.id))!.toJson(), equals(f.toJson()));
      final resolved = await chart.resolveFinding(
        ctx,
        f.id,
        procedureId: 'proc-1',
        at: t1,
      );
      expect(resolved.status, FindingStatus.resolved);
      expect(resolved.resolvedAt, t1);
      await chart.deleteFinding(ctx, f.id, 'charted on wrong tooth');
      expect(await chart.findings(patientId), isEmpty);
      expect(
        (await chart.findings(patientId, includeDeleted: true)).single.status,
        FindingStatus.deleted,
      );
      final events = await env.repos.audit.forEntity(clinicId, 'Finding', f.id);
      expect(events.map((e) => e.action), [
        AuditAction.create,
        AuditAction.statusChange,
        AuditAction.softDelete,
      ]);
    });
  });

  group('procedures', () {
    test('completed procedures are listed per clinic and date range', () async {
      final chart = env.repos.chart;
      await chart.createProcedure(ctx, procedure(id: 'p-1', totalStages: 1));
      await chart.createProcedure(ctx, procedure(id: 'p-2', totalStages: 1));
      await chart.createProcedure(ctx, procedure(id: 'p-3', totalStages: 1));
      await chart.setProcedureStatus(
        ctx,
        'p-1',
        ProcedureStatus.completed,
        at: t0,
      );
      await chart.setProcedureStatus(
        ctx,
        'p-2',
        ProcedureStatus.completed,
        at: t2,
      );
      final all = await chart.completedProceduresForClinic(clinicId);
      expect(all.map((p) => p.id), ['p-2', 'p-1'], reason: 'newest first');
      expect(
        (await chart.completedProceduresForClinic(
          clinicId,
          from: t1,
        )).map((p) => p.id),
        ['p-2'],
      );
      expect(
        (await chart.completedProceduresForClinic(
          clinicId,
          from: t0,
          to: t1,
        )).map((p) => p.id),
        ['p-1'],
      );
      expect(await chart.completedProceduresForClinic('clinic-2'), isEmpty);
    });

    test('status transitions and stage advance write audit events', () async {
      final chart = env.repos.chart;
      final p = procedure();
      await chart.createProcedure(ctx, p);
      expect((await chart.getProcedure(p.id))!.toJson(), equals(p.toJson()));

      final accepted = await chart.setProcedureStatus(
        ctx,
        p.id,
        ProcedureStatus.accepted,
        at: t0,
      );
      expect(accepted.acceptedAt, t0);

      final s1 = await chart.advanceStage(ctx, p.id, at: t1);
      expect(s1.status, ProcedureStatus.inProgress);
      expect(s1.stageIndex, 0);
      expect(s1.currentStageName, 'Access and BMP');
      expect(s1.startedAt, t1);

      final s2 = await chart.advanceStage(ctx, p.id, at: t2);
      expect(s2.stageIndex, 1);
      expect(s2.status, ProcedureStatus.inProgress);

      final s3 = await chart.advanceStage(ctx, p.id);
      expect(s3.stageIndex, 2);
      expect(s3.status, ProcedureStatus.completed);
      expect(s3.completedAt, isNotNull);

      expect(() => chart.advanceStage(ctx, p.id), throwsStateError);
      // Completing a completed procedure is a no-op transition: rejected, so
      // a double tap cannot write a second status change.
      expect(
        () => chart.setProcedureStatus(ctx, p.id, ProcedureStatus.completed),
        throwsStateError,
      );
      expect(
        () => chart.setProcedureStatus(ctx, p.id, ProcedureStatus.deleted),
        throwsArgumentError,
      );

      final events = await env.repos.audit.forEntity(
        clinicId,
        'ProcedureRecord',
        p.id,
      );
      expect(events, hasLength(5));
      expect(events.first.action, AuditAction.create);
      expect(
        events.skip(1).every((e) => e.action == AuditAction.statusChange),
        isTrue,
      );
      expect(events[1].before!['status'], 'planned');
      expect(events[1].after!['status'], 'accepted');
      expect(events[2].before!['status'], 'accepted');
      expect(events[2].after!['status'], 'inProgress');
      expect(events[4].after!['status'], 'completed');
      // Audit time is the device clock, not the business `at` passed in.
      expect(
        events[2].occurredAt.isAfter(events[1].occurredAt) ||
            events[2].occurredAt == events[1].occurredAt,
        isTrue,
      );
      expect(events[1].occurredAt, isNot(t0));
      expect(events.every((e) => e.actorId == dentistId), isTrue);
      expect(events.every((e) => e.deviceId == deviceId), isTrue);

      final pending = await env.repos.outbox.pending(clinicId);
      final procedureRows = pending.where((o) => o.rowId == p.id).toList();
      expect(procedureRows, hasLength(5));
      expect(procedureRows.first.operation, OutboxOperation.insert);
      expect(procedureRows.last.operation, OutboxOperation.update);
      expect(procedureRows.first.targetTable, 'procedures');
      expect(procedureRows.last.payload['status'], 'completed');
    });

    test('soft delete hides from default queries', () async {
      final chart = env.repos.chart;
      await chart.createProcedure(ctx, procedure());
      await chart.deleteProcedure(ctx, 'proc-1', 'duplicate entry');
      expect(await chart.proceduresForPatient(patientId), isEmpty);
      expect(
        await chart.proceduresForPatient(patientId, includeDeleted: true),
        hasLength(1),
      );
      expect(
        await chart.proceduresForPatient(
          patientId,
          statuses: [ProcedureStatus.deleted],
        ),
        hasLength(1),
      );
      expect(await chart.watchProceduresForPatient(patientId).first, isEmpty);
    });

    test('implants round trip', () async {
      final i = implant();
      await env.repos.chart.upsertImplant(ctx, i);
      final stored = await env.repos.chart.implantsForPatient(patientId);
      expect(stored.single.toJson(), equals(i.toJson()));
    });
  });

  group('catalogue', () {
    test('seeded on open with the full Indian catalogue', () async {
      final items = await env.repos.catalog.globalItems();
      expect(items.length, greaterThanOrEqualTo(120));
      expect(items.length, indianProcedureCatalogue.length);
      expect(items.every((i) => i.clinicId == null), isTrue);
      expect(await env.repos.catalog.seedGlobalIfEmpty(), 0);
      final rct = await env.repos.catalog.byCode(clinicId, 'RCT-MOL');
      expect(rct, isNotNull);
      expect(rct!.isMultiSitting, isTrue);
      expect(rct.id, seedId('catalog', 'RCT-MOL'));
    });

    test('clinic override replaces the global row by code', () async {
      final catalog = env.repos.catalog;
      final before = await catalog.itemsForClinic(clinicId);
      final override = clinicCatalogItem();
      await catalog.saveClinicItem(ctx, override);
      final after = await catalog.itemsForClinic(clinicId);
      expect(after.length, before.length);
      final rct = await catalog.byCode(clinicId, 'RCT-MOL');
      expect(rct!.id, 'cat-1');
      expect(rct.defaultFee, const Money.rupees(6000));
      expect(rct.toJson(), equals(override.toJson()));

      final hits = await catalog.search(clinicId, 'root canal');
      expect(hits.any((i) => i.id == 'cat-1'), isTrue);
      expect(
        await catalog.search(
          clinicId,
          'zzz',
          category: ProcedureCategory.implant,
        ),
        isEmpty,
      );

      await catalog.deactivate(ctx, 'cat-1');
      expect(
        (await catalog.itemsForClinic(clinicId))
            .any((i) => i.code == 'RCT-MOL'),
        isFalse,
      );
      // Hiding a global item writes an inactive override.
      final ext = (await catalog.globalItems()).firstWhere(
        (i) => i.code == 'EXT-SIMPLE',
      );
      await catalog.deactivate(ctx, ext.id);
      expect(
        (await catalog.itemsForClinic(clinicId))
            .any((i) => i.code == 'EXT-SIMPLE'),
        isFalse,
      );
      expect(() => catalog.saveClinicItem(ctx, ext), throwsArgumentError);
    });
  });

  group('drug master', () {
    test('seeded on open with allergy check helper', () async {
      final rx = env.repos.prescriptions;
      final drugs = await rx.drugs();
      expect(drugs.length, dentalDrugMaster.length);
      expect(await rx.seedDrugMasterIfEmpty(), 0);
      final amox = await rx.searchDrugs('amox');
      expect(amox, isNotEmpty);
      expect(amox.every((d) => d.form != DrugForm.other), isTrue);
      final conflicts = conflictingDrugs(medicalHistory(), drugs);
      expect(conflicts, isNotEmpty);
      expect(conflicts.every((d) => d.allergyGroup == 'penicillin'), isTrue);
      expect(cautionDrugs(medicalHistory(), drugs), isEmpty);
    });

    test('free-typed substances block without a group chip', () async {
      final drugs = await env.repos.prescriptions.drugs();
      Set<String> blocked(String substance) {
        final history = medicalHistory().copyWith(
          allergies: [AllergyEntry(substance: substance)],
        );
        return conflictingDrugs(
          history,
          drugs,
        ).map((d) => d.genericName).toSet();
      }

      // The generic name itself, a combination containing it, and brands.
      expect(blocked('Amoxicillin'), {
        'Amoxicillin',
        'Amoxicillin + Clavulanic acid',
      });
      expect(blocked('augmentin'), {
        'Amoxicillin',
        'Amoxicillin + Clavulanic acid',
      });
      expect(blocked('Brufen'), containsAll(['Ibuprofen']));
      expect(blocked('Brufen'), contains('Ibuprofen + Paracetamol'));
      expect(blocked('lignocaine'), contains('Lignocaine + Adrenaline'));
      expect(blocked('Paracetamol'), contains('Paracetamol'));
      expect(blocked('Paracetamol'), contains('Aceclofenac + Paracetamol'));
      // Clavulanate is only ever co-formulated with amoxicillin, so the
      // whole penicillin group is blocked, not just the combination.
      expect(blocked('Clavulanic acid'), {
        'Amoxicillin',
        'Amoxicillin + Clavulanic acid',
      });
      // A combination component with no group of its own blocks the
      // combination drug.
      expect(blocked('Adrenaline'), {
        'Lignocaine + Adrenaline',
        'Articaine + Adrenaline',
      });
      // Nothing to match: too short or not a drug.
      expect(blocked('Pan'), isEmpty);
      expect(blocked('Latex'), isEmpty);
      expect(blocked('dust mites'), isEmpty);

      final amox = drugs.firstWhere((d) => d.genericName == 'Amoxicillin');
      final matches = allergyMatches(
        medicalHistory().copyWith(
          allergies: const [
            AllergyEntry(substance: 'Augmentin', allergyGroup: 'other'),
            AllergyEntry(substance: 'Latex', allergyGroup: 'latex'),
          ],
        ),
        amox,
      );
      // A wrongly chosen group does not hide a recognisable substance.
      expect(matches.map((a) => a.substance), ['Augmentin']);
    });
  });
}
