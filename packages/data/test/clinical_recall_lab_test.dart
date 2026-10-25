import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.open());
  tearDown(() => env.close());

  group('clinical notes', () {
    test('signed notes version instead of mutating', () async {
      final clinical = env.repos.clinical;
      final n = note();
      await clinical.saveNote(ctx, n);
      expect((await clinical.getNote(n.id))!.toJson(), equals(n.toJson()));
      final edited = await clinical.saveNote(
        ctx,
        n.copyWith(advice: 'Soft diet, warm saline'),
      );
      expect(edited.id, n.id);
      expect(edited.version, 1);

      final signed = await clinical.signNote(ctx, n.id, at: t1);
      expect(signed.isSigned, isTrue);
      final v2 = await clinical.saveNote(
        ctx,
        signed.copyWith(advice: 'Amended advice'),
      );
      expect(v2.id, isNot(n.id));
      expect(v2.version, 2);
      expect(v2.supersedesNoteId, n.id);
      expect(v2.isSigned, isFalse);
      expect(v2.advice, 'Amended advice');
      // The signed original is untouched.
      expect((await clinical.getNote(n.id))!.advice, 'Soft diet, warm saline');

      final latest = await clinical.notesForVisit('visit-1');
      expect(latest.single.id, v2.id);
      expect(
        await clinical.notesForVisit('visit-1', latestOnly: false),
        hasLength(2),
      );
      expect((await clinical.noteVersions(v2.id)).map((x) => x.version), [
        1,
        2,
      ]);
      expect((await clinical.noteVersions(n.id)).map((x) => x.version), [1, 2]);
      expect(
        (await clinical.watchNotesForPatient(patientId).first).single.id,
        v2.id,
      );
    });

    test('medical histories are append-only snapshots', () async {
      final clinical = env.repos.clinical;
      final h1 = medicalHistory();
      await clinical.recordMedicalHistory(ctx, h1);
      expect(
        (await clinical.latestMedicalHistory(patientId))!.toJson(),
        equals(h1.toJson()),
      );
      expect(() => clinical.recordMedicalHistory(ctx, h1), throwsStateError);
      final h2 = medicalHistory(id: 'mh-2', recordedAt: t2);
      await clinical.recordMedicalHistory(ctx, h2);
      expect((await clinical.latestMedicalHistory(patientId))!.id, 'mh-2');
      expect(await clinical.medicalHistories(patientId), hasLength(2));
      final latest = await clinical.watchLatestMedicalHistory(patientId).first;
      expect(latest!.redFlags, contains(RedFlag.allergyPenicillin));
      expect(latest.mronjRisk, MronjRisk.low);
    });

    test('images and consents round trip', () async {
      final img = image();
      await env.repos.clinical.addImage(ctx, img);
      expect(
        (await env.repos.clinical.imagesForPatient(
          patientId,
          kind: ImageKind.periapical,
        )).single.toJson(),
        equals(img.toJson()),
      );
      expect(
        await env.repos.clinical.imagesForPatient(
          patientId,
          kind: ImageKind.opg,
        ),
        isEmpty,
      );

      final c = consent();
      await env.repos.consents.recordConsent(ctx, c);
      expect(
        (await env.repos.consents.getConsent(c.id))!.toJson(),
        equals(c.toJson()),
      );
      expect(() => env.repos.consents.recordConsent(ctx, c), throwsStateError);
      expect(
        (await env.repos.consents.consentsForProcedure('proc-1')).single.id,
        c.id,
      );
      expect(await env.repos.consents.consentsForProcedure('proc-9'), isEmpty);
    });

    test('data consents: latest per purpose, withdrawal', () async {
      final consents = env.repos.consents;
      await consents.recordDataConsent(ctx, dataConsent());
      await consents.recordDataConsent(
        ctx,
        dataConsent(id: 'dc-2', purpose: DataPurpose.marketing, granted: false),
      );
      await consents.recordDataConsent(
        ctx,
        dataConsent(
          id: 'dc-3',
          purpose: DataPurpose.marketing,
          granted: true,
          grantedAt: t2,
        ),
      );
      final latest = await consents.latestDataConsents(patientId);
      expect(latest[DataPurpose.marketing]!.id, 'dc-3');
      expect(latest[DataPurpose.appointmentReminders]!.id, 'dc-1');
      expect(
        await consents.hasActiveDataConsent(patientId, DataPurpose.marketing),
        isTrue,
      );
      await consents.withdrawDataConsent(ctx, 'dc-3', at: t2);
      expect(
        await consents.hasActiveDataConsent(patientId, DataPurpose.marketing),
        isFalse,
      );
      expect(
        await consents.hasActiveDataConsent(patientId, DataPurpose.research),
        isFalse,
      );
    });
  });

  group('perio', () {
    test('exams round trip and flatten site history', () async {
      final perio = env.repos.perio;
      final e1 = perioExam();
      await perio.saveExam(ctx, e1);
      expect((await perio.getExam(e1.id))!.toJson(), equals(e1.toJson()));
      final e2 = perioExam(id: 'perio-2', examinedAt: t2);
      await perio.saveExam(ctx, e2);
      expect((await perio.latestExam(patientId))!.id, 'perio-2');
      final history = await perio.siteHistory(
        patientId,
        ToothId.parse('16'),
        PerioSite.mesioBuccal,
      );
      expect(history.map((p) => p.examId), ['perio-1', 'perio-2']);
      expect(history.first.reading.probingDepth, 4);
      expect(history.first.reading.clinicalAttachmentLoss, 5);
      expect(
        (await perio.examsForPatient(patientId)).first.summary.sitesBleeding,
        1,
      );
    });
  });

  group('prescriptions', () {
    test('issue is immutable and mints a verification code', () async {
      final rx = env.repos.prescriptions;
      final p = prescription();
      await rx.issuePrescription(ctx, p);
      expect((await rx.getPrescription(p.id))!.toJson(), equals(p.toJson()));
      expect(() => rx.issuePrescription(ctx, p), throwsStateError);
      expect((await rx.byVerificationCode('ABCD1234'))!.id, p.id);
      final minted = await rx.issuePrescription(
        ctx,
        Prescription(
          id: 'rx-2',
          clinicId: clinicId,
          patientId: patientId,
          prescriberId: dentistId,
          prescriberName: 'Dr. A. Rao',
          prescriberRegistrationNumber: 'A-12345',
          issuedAt: t1,
          verificationCode: '',
          createdAt: t1,
        ),
      );
      expect(minted.verificationCode, hasLength(8));
      expect((await rx.prescriptionsForPatient(patientId)).first.id, 'rx-2');
    });
  });

  group('recalls', () {
    test('due list orders by dueAt and excludes closed recalls', () async {
      final recalls = env.repos.recalls;
      await recalls.upsert(
        ctx,
        recall(id: 'r-late', dueAt: DateTime.utc(2026, 9, 1)),
      );
      await recalls.upsert(
        ctx,
        recall(id: 'r-soon', dueAt: DateTime.utc(2026, 10, 10)),
      );
      await recalls.upsert(
        ctx,
        recall(id: 'r-future', dueAt: DateTime.utc(2026, 12, 1)),
      );
      await recalls.upsert(
        ctx,
        recall(
          id: 'r-done',
          dueAt: DateTime.utc(2026, 8, 1),
          status: RecallStatus.completed,
        ),
      );
      final due = await recalls.due(
        clinicId,
        until: DateTime.utc(2026, 10, 18),
      );
      expect(due.map((r) => r.id), ['r-late', 'r-soon']);
      expect(
        await recalls.dueValue(clinicId, until: DateTime.utc(2026, 10, 18)),
        const Money.rupees(3000),
      );
      expect(
        (await recalls.due(
          clinicId,
          until: DateTime.utc(2027, 1, 1),
        )).map((r) => r.id),
        ['r-late', 'r-soon', 'r-future'],
      );
      expect(
        (await recalls.due(
          clinicId,
          until: DateTime.utc(2027, 1, 1),
          limit: 1,
        )).single.id,
        'r-late',
      );

      final notified = await recalls.markNotified(ctx, 'r-late', at: t1);
      expect(notified.status, RecallStatus.notified);
      expect(notified.notifyCount, 1);
      expect(notified.lastNotifiedAt, t1);
      expect(notified.isOverdue(DateTime.utc(2026, 10, 18)), isTrue);
      // Notified recalls stay in the due list; scheduled ones leave it.
      expect(
        (await recalls.due(
          clinicId,
          until: DateTime.utc(2026, 10, 18),
        )).first.id,
        'r-late',
      );
      await recalls.markScheduled(ctx, 'r-late', 'appt-1');
      expect(
        (await recalls.due(
          clinicId,
          until: DateTime.utc(2026, 10, 18),
        )).map((r) => r.id),
        ['r-soon'],
      );
      await recalls.dismiss(ctx, 'r-soon', 'patient relocated');
      expect(
        await recalls.due(clinicId, until: DateTime.utc(2026, 10, 18)),
        isEmpty,
      );
      expect((await recalls.forPatient(patientId)), hasLength(4));
    });

    test(
      'created from a completed procedure through the default rules',
      () async {
        final completed = procedure(
          code: 'SCALING-ADULT',
          totalStages: 1,
          status: ProcedureStatus.completed,
        );
        final r = await env.repos.recalls.createFromProcedure(
          ctx,
          completed,
          completedOn: t0,
        );
        expect(r, isNotNull);
        expect(r!.type, RecallType.hygiene);
        expect(r.dueAt, t0.add(const Duration(days: 180)));
        expect(r.estimatedValue.paise, greaterThan(0));
        expect(r.triggeredByProcedureId, completed.id);
        expect(
          await env.repos.recalls.createFromProcedure(
            ctx,
            procedure(code: 'NOT-A-CODE'),
          ),
          isNull,
        );
        // Idempotent: a repeated completion returns the same recall instead
        // of opening a duplicate that would double the overdue KPI.
        final again = await env.repos.recalls.createFromProcedure(
          ctx,
          completed,
          completedOn: t1,
        );
        expect(again!.id, r.id);
        expect(again.dueAt, r.dueAt);
        expect(
          (await env.repos.recalls.forPatient(patientId))
              .where((x) => x.triggeredByProcedureId == completed.id)
              .length,
          1,
        );
        expect((await env.repos.recalls.forProcedure(completed.id))!.id, r.id);
        expect(await env.repos.recalls.forProcedure('nope'), isNull);
      },
    );
  });

  group('lab cases', () {
    test('due date from turnaround and timestamped transitions', () async {
      final labs = env.repos.labs;
      await labs.upsertLab(ctx, lab());
      expect((await labs.getLab('lab-1'))!.toJson(), equals(lab().toJson()));
      final c = labCase();
      await labs.createCase(ctx, c);
      expect((await labs.getCase(c.id))!.toJson(), equals(c.toJson()));
      expect(() => labs.createCase(ctx, c), throwsStateError);

      // Monday 19 Oct 2026 + 5 working days (Sunday off) = Saturday 24 Oct.
      final sentAt = DateTime.utc(2026, 10, 19, 11);
      final sent = await labs.markSent(ctx, c.id, at: sentAt);
      expect(sent.status, LabCaseStatus.sent);
      expect(sent.sentAt, sentAt);
      expect(sent.dueAt, DateTime.utc(2026, 10, 24, 11));
      expect(sent.dueAt, computeDueDate(sentAt, 5));
      expect(sent.isOverdue(DateTime.utc(2026, 10, 25)), isTrue);
      expect(
        (await labs.overdueCases(
          clinicId,
          asOf: DateTime.utc(2026, 10, 25),
        )).single.id,
        c.id,
      );
      expect(
        await labs.overdueCases(clinicId, asOf: DateTime.utc(2026, 10, 23)),
        isEmpty,
      );

      final received = await labs.markReceived(
        ctx,
        c.id,
        at: DateTime.utc(2026, 10, 23),
      );
      expect(received.status, LabCaseStatus.received);
      expect(received.receivedAt, DateTime.utc(2026, 10, 23));
      final checked = await labs.markQualityChecked(ctx, c.id, at: t2);
      expect(checked.qualityCheckedAt, t2);
      final fitted = await labs.markFitted(ctx, c.id, at: t2);
      expect(fitted.status, LabCaseStatus.fitted);
      expect(fitted.fittedAt, t2);
      expect(await labs.openCases(clinicId), isEmpty);

      final events = await env.repos.audit.forEntity(clinicId, 'LabCase', c.id);
      expect(events.map((e) => e.action).toSet(), {
        AuditAction.create,
        AuditAction.statusChange,
      });
      expect(events, hasLength(5));
    });

    test('remake creates a linked case and explicit turnaround wins', () async {
      final labs = env.repos.labs;
      await labs.upsertLab(ctx, lab());
      await labs.createCase(ctx, labCase());
      final sent = await labs.markSent(
        ctx,
        'case-1',
        at: DateTime.utc(2026, 10, 19, 11),
        turnaroundWorkingDays: 1,
      );
      expect(sent.dueAt, DateTime.utc(2026, 10, 20, 11));
      final remake = await labs.requestRemake(
        ctx,
        'case-1',
        reason: 'Open margin',
      );
      expect(remake.remakeOfCaseId, 'case-1');
      expect(remake.status, LabCaseStatus.created);
      expect(
        (await labs.getCase('case-1'))!.status,
        LabCaseStatus.remakeRequested,
      );
      expect((await labs.getCase('case-1'))!.remakeReason, 'Open margin');
      expect(await labs.openCases(clinicId), hasLength(2));
      expect(
        () => labs.requestRemake(ctx, remake.id, reason: ''),
        throwsArgumentError,
      );
      await labs.cancelCase(ctx, remake.id, 'patient declined');
      expect(await labs.watchOpenCases(clinicId).first, hasLength(1));
    });
  });

  group('compliance', () {
    test('cycle numbers mint and licences expire soon', () async {
      final compliance = env.repos.compliance;
      final c1 = await compliance.recordCycle(ctx, cycle(number: ''));
      expect(c1.cycleNumber, 'SC-00001');
      final c2 = await compliance.recordCycle(
        ctx,
        cycle(id: 'cyc-2', number: ''),
      );
      expect(c2.cycleNumber, 'SC-00002');
      expect(c1.passed, isTrue);
      expect(await compliance.cycles(clinicId, from: t0, to: t1), hasLength(2));
      expect(await compliance.cycles(clinicId, from: t1), isEmpty);
      expect(
        await compliance.watchRecentCycles(clinicId, limit: 1).first,
        hasLength(1),
      );
      expect(() => compliance.recordCycle(ctx, c1), throwsStateError);

      await compliance.upsertLicence(ctx, licence());
      await compliance.upsertLicence(
        ctx,
        licence(id: 'lic-2', expiresAt: DateTime.utc(2026, 11, 1)),
      );
      expect(
        (await compliance.licences(clinicId)).first.toJson(),
        equals(
          licence(id: 'lic-2', expiresAt: DateTime.utc(2026, 11, 1)).toJson(),
        ),
      );
      final soon = await compliance.expiringSoon(
        clinicId,
        asOf: DateTime.utc(2026, 10, 18),
        withinDays: 30,
      );
      expect(soon.single.id, 'lic-2');
      // lic-1 expires 2027 but its QA is due 1 Dec 2026.
      final sixty = await compliance.expiringSoon(
        clinicId,
        asOf: DateTime.utc(2026, 10, 18),
      );
      expect(sixty.map((l) => l.id), ['lic-2', 'lic-1']);
    });
  });

  group('message log', () {
    test('enqueue and status updates', () async {
      final messages = env.repos.messages;
      final m = message();
      await messages.enqueue(ctx, m);
      expect((await messages.getById(m.id))!.toJson(), equals(m.toJson()));
      expect((await messages.queued(clinicId)).single.id, m.id);
      final sent = await messages.updateStatus(
        ctx,
        m.id,
        MessageStatus.sent,
        providerMessageId: 'wamid.1',
        at: t1,
      );
      expect(sent.sentAt, t1);
      expect(sent.providerMessageId, 'wamid.1');
      final delivered = await messages.updateStatus(
        ctx,
        m.id,
        MessageStatus.delivered,
        at: t2,
      );
      expect(delivered.deliveredAt, t2);
      expect(await messages.queued(clinicId), isEmpty);
      expect(
        (await messages.forPatient(patientId)).single.status,
        MessageStatus.delivered,
      );
    });
  });
}
