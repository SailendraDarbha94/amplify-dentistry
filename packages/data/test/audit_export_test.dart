import 'dart:convert';
import 'dart:io';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.open());
  tearDown(() => env.close());

  group('audit and outbox', () {
    test(
      'every repository write leaves an audit event and an outbox row',
      () async {
        final r = env.repos;
        final auditBefore = await r.audit.count(clinicId);
        final outboxBefore = await r.outbox.pendingCount(clinicId);

        await r.appointments.upsert(ctx, appointment());
        await r.appointments.startVisit(ctx, visit());
        await r.chart.recordToothState(
          ctx,
          toothState('ts-1', '36', ToothState.present, t0),
        );
        await r.chart.addFinding(ctx, finding());
        await r.chart.createProcedure(ctx, procedure());
        await r.treatmentPlans.savePlan(ctx, plan(), [planLine()]);
        await r.consents.recordConsent(ctx, consent());
        await r.consents.recordDataConsent(ctx, dataConsent());
        await r.clinical.saveNote(ctx, note());
        await r.clinical.recordMedicalHistory(ctx, medicalHistory());
        await r.clinical.addImage(ctx, image());
        await r.perio.saveExam(ctx, perioExam());
        await r.prescriptions.issuePrescription(ctx, prescription());
        await r.labs.upsertLab(ctx, lab());
        await r.labs.createCase(ctx, labCase());
        await r.chart.upsertImplant(ctx, implant());
        await r.recalls.upsert(ctx, recall());
        await r.messages.enqueue(ctx, message());
        await r.compliance.recordCycle(ctx, cycle());
        await r.compliance.upsertLicence(ctx, licence());
        await r.billing.saveDraft(ctx, draftInvoice());
        // 21 writes above, plus plan line (1) = 22 entity rows.
        const expectedWrites = 22;

        final auditAfter = await r.audit.count(clinicId);
        final outboxAfter = await r.outbox.pendingCount(clinicId);
        expect(auditAfter - auditBefore, expectedWrites);
        expect(outboxAfter - outboxBefore, expectedWrites);

        final pending = await r.outbox.pending(clinicId);
        expect(
          pending.every((o) => o.operation == OutboxOperation.insert),
          isTrue,
        );
        expect(pending.every((o) => o.payload.containsKey('id')), isTrue);
        expect(
          pending.map((o) => o.targetTable).toSet(),
          containsAll([
            'appointments',
            'visits',
            'tooth_state_records',
            'findings',
            'procedures',
            'treatment_plans',
            'treatment_plan_lines',
            'consent_records',
            'data_consents',
            'clinical_notes',
            'medical_histories',
            'image_records',
            'perio_exams',
            'prescriptions',
            'labs',
            'lab_cases',
            'implant_records',
            'recalls',
            'message_logs',
            'sterilisation_cycles',
            'licences',
            'invoices',
          ]),
        );

        // Issuing an invoice writes invoice + ledger entry; a payment writes
        // payment + ledger + invoice update: all in one transaction each.
        await r.billing.issueInvoice(ctx, 'inv-1');
        expect(await r.audit.count(clinicId), auditAfter + 2);
        await r.billing.recordPayment(ctx, payment());
        expect(await r.audit.count(clinicId), auditAfter + 5);

        final byActor = await r.audit.forActor(clinicId, dentistId);
        expect(byActor.length, await r.audit.count(clinicId));
        final windowed = await r.audit.inRange(
          clinicId,
          DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
          DateTime.now().toUtc().add(const Duration(minutes: 5)),
        );
        expect(windowed.length, byActor.length);
        expect(
          (await r.audit.watchRecent(clinicId, limit: 3).first),
          hasLength(3),
        );
      },
    );

    test('outbox ack and failure bookkeeping', () async {
      final outbox = env.repos.outbox;
      final pending = await outbox.pending(clinicId);
      expect(pending, isNotEmpty);
      await outbox.recordFailure(pending.first.id, 'offline');
      final again = await outbox.pending(clinicId);
      expect(again.first.attempts, 1);
      expect(again.first.lastError, 'offline');
      await outbox.ack(pending.map((o) => o.id));
      expect(await outbox.pendingCount(clinicId), 0);
      expect(await outbox.watchPendingCount(clinicId).first, 0);
      // Rows are kept, only stamped.
      final rows = await env.db.select(env.db.syncOutbox).get();
      expect(rows.length, pending.length);
      expect(rows.every((o) => o.ackedAt != null), isTrue);
    });

    test('noop sync engine mirrors the pending count', () async {
      final engine = NoopSyncEngine(
        pendingCount: env.repos.outbox.watchPendingCount(clinicId),
      );
      final first = await engine.state.first;
      expect(first.status, SyncStatus.disabled);
      await engine.pushPending();
      await engine.pullSince(null);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(engine.current.pendingCount, greaterThan(0));
      await engine.dispose();
    });

    test('standalone audit append and failed transaction rollback', () async {
      final audit = env.repos.audit;
      await audit.append(
        ctx,
        action: AuditAction.view,
        entityType: 'Patient',
        entityId: patientId,
      );
      final views = await audit.forEntity(clinicId, 'Patient', patientId);
      expect(views.last.action, AuditAction.view);

      // A write that fails inside its transaction leaves no audit trace.
      final before = await audit.count(clinicId);
      await expectLater(
        env.repos.billing.recordPayment(
          ctx,
          payment(id: 'pay-x', invoiceId: 'missing-invoice'),
        ),
        throwsStateError,
      );
      expect(await audit.count(clinicId), before);
      expect(await env.repos.billing.paymentsForPatient(patientId), isEmpty);
    });
  });

  group('export', () {
    test('patient bundle contains every section and is audited', () async {
      final r = env.repos;
      await r.appointments.upsert(ctx, appointment());
      await r.appointments.startVisit(ctx, visit());
      await r.chart.recordToothState(
        ctx,
        toothState('ts-1', '36', ToothState.present, t0),
      );
      await r.chart.addFinding(ctx, finding());
      await r.chart.createProcedure(ctx, procedure());
      await r.treatmentPlans.savePlan(ctx, plan(), [planLine()]);
      await r.treatmentPlans.estimateFromPlan(ctx, 'plan-1');
      await r.consents.recordConsent(ctx, consent());
      await r.consents.recordDataConsent(ctx, dataConsent());
      await r.clinical.saveNote(ctx, note());
      await r.clinical.recordMedicalHistory(ctx, medicalHistory());
      await r.clinical.addImage(ctx, image());
      await r.perio.saveExam(ctx, perioExam());
      await r.prescriptions.issuePrescription(ctx, prescription());
      await r.labs.upsertLab(ctx, lab());
      await r.labs.createCase(ctx, labCase());
      await r.chart.upsertImplant(ctx, implant());
      await r.billing.saveDraft(ctx, draftInvoice());
      await r.billing.issueInvoice(ctx, 'inv-1');
      await r.billing.recordPayment(ctx, payment());
      await r.billing.recordAdjustment(ctx, adjustment());
      await r.recalls.upsert(ctx, recall());
      await r.messages.enqueue(ctx, message());

      final bundle = await r.export.exportPatient(ctx, patientId);
      final json = bundle.toJson();
      for (final key in PatientExportBundle.sectionKeys) {
        expect(json.containsKey(key), isTrue, reason: 'missing $key');
        final section = json[key];
        if (section is List) {
          expect(section, isNotEmpty, reason: '$key is empty');
        } else {
          expect(section, isA<Map<String, Object?>>());
        }
      }
      // Serialises to real JSON text.
      final text = jsonEncode(json);
      expect(text, contains('"patientNumber":"P-00001"'));
      expect(bundle.ledgerEntries, hasLength(3));

      final events = await r.audit.forEntity(clinicId, 'Patient', patientId);
      expect(events.last.action, AuditAction.export);

      final clinicBundle = await r.export.exportClinic(ctx);
      expect(clinicBundle.patients.single.patient.id, patientId);
      expect(clinicBundle.members, hasLength(1));
      expect(clinicBundle.settings.keys, contains(SettingKeys.gstRates));
      expect(clinicBundle.auditEvents, isNotEmpty);
      expect(
        jsonEncode(clinicBundle.toJson()),
        contains('"name":"Smile Dental"'),
      );
    });
  });

  group('API review: no hard deletes', () {
    test('repository and db sources never call drift delete APIs', () {
      final dirs = [
        Directory('lib/src/repositories'),
        Directory('lib/src/sync'),
        Directory('lib/src/seed'),
        Directory('lib/src/db'),
      ];
      final forbidden = RegExp(
        r'\.delete\(|deleteWhere\(|deleteAll\(|\bDELETE\b|deleteReturning\(',
      );
      final files = dirs
          .where((d) => d.existsSync())
          .expand((d) => d.listSync(recursive: true))
          .whereType<File>()
          .where(
            (f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'),
          );
      expect(files, isNotEmpty);
      for (final f in files) {
        final matches = forbidden.allMatches(f.readAsStringSync());
        expect(
          matches,
          isEmpty,
          reason:
              '${f.path} contains a delete: ${matches.map((m) => m.group(0))}',
        );
      }
    });

    test(
      'abstract repositories expose only soft deletes returning the row',
      () {
        final abstracts = Directory('lib/src/repositories')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('_repository.dart'));
        final deleteMethod = RegExp(
          r'(Future<[^>]+>)\s+(delete\w*|deactivate\w*|dismiss|cancelCase)\(',
        );
        var found = 0;
        for (final f in abstracts) {
          for (final m in deleteMethod.allMatches(f.readAsStringSync())) {
            found++;
            expect(
              m.group(1),
              isNot('Future<void>'),
              reason:
                  '${f.path}: ${m.group(2)} must return the soft-deleted row',
            );
          }
        }
        expect(found, greaterThan(0));
      },
    );
  });
}
