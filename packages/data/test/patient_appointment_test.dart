import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.open(withPatient: false));
  tearDown(() => env.close());

  group('patients', () {
    test('create, read, update, deactivate with audit', () async {
      final repo = env.repos.patients;
      final p = patient();
      await repo.upsert(ctx, p);
      final stored = await repo.getById(p.id);
      expect(stored!.toJson(), equals(p.toJson()));

      final updated = p.copyWith(phone: '9111111111', updatedAt: t1);
      await repo.upsert(ctx, updated);
      expect((await repo.getById(p.id))!.phone, '9111111111');

      await repo.deactivate(ctx, p.id, reason: 'moved city');
      expect((await repo.getById(p.id))!.isActive, isFalse);
      expect(await repo.search(clinicId, 'Anil'), isEmpty);
      expect(await repo.count(clinicId), 0);

      final events = await env.repos.audit.forEntity(clinicId, 'Patient', p.id);
      expect(events.map((e) => e.action), [
        AuditAction.create,
        AuditAction.update,
        AuditAction.softDelete,
      ]);
      expect(events.first.before, isNull);
      expect(events.first.after!['phone'], '9000000002');
      expect(events[1].before!['phone'], '9000000002');
      expect(events[1].after!['phone'], '9111111111');
      expect(events.last.reason, 'moved city');
    });

    test('search by name, phone and number; watchAll filters', () async {
      final repo = env.repos.patients;
      await repo.upsert(ctx, patient());
      await repo.upsert(
        ctx,
        patient(
          id: 'patient-2',
          number: 'P-00002',
          firstName: 'Sita',
          lastName: 'Devi',
          phone: '9222222222',
          altPhone: '9333333333',
        ),
      );
      expect((await repo.search(clinicId, 'sita')).single.id, 'patient-2');
      expect((await repo.search(clinicId, '9000000002')).single.id, patientId);
      expect((await repo.search(clinicId, 'P-00002')).single.id, 'patient-2');
      expect((await repo.search(clinicId, 'Anil Kumar')).single.id, patientId);
      expect(await repo.search(clinicId, ''), hasLength(2));
      expect(
        (await repo.findByPhone(clinicId, '9000000003')).single.id,
        patientId,
      );
      expect((await repo.findByNumber(clinicId, 'P-00002'))!.firstName, 'Sita');

      final all = await repo.watchAll(clinicId).first;
      expect(all, hasLength(2));
      final filtered = await repo.watchAll(clinicId, query: 'devi').first;
      expect(filtered.single.id, 'patient-2');
      final byIds = await repo.watchByIds(['patient-2']).first;
      expect(byIds.single.id, 'patient-2');
    });

    test('recent, count and family lookups are database queries', () async {
      final repo = env.repos.patients;
      await repo.upsert(ctx, patient());
      await repo.upsert(
        ctx,
        patient(
          id: 'patient-2',
          number: 'P-00002',
          firstName: 'Sita',
          phone: '9222222222',
          altPhone: '9333333333',
        ).copyWith(updatedAt: t1),
      );
      await repo.upsert(
        ctx,
        patient(
          id: 'patient-3',
          number: 'P-00003',
          firstName: 'Gopal',
          phone: '9444444444',
          altPhone: '9555555555',
        ).copyWith(updatedAt: t2, isActive: false),
      );
      expect(await repo.watchCount(clinicId).first, 2);
      final recent = await repo.watchRecent(clinicId).first;
      expect(recent.map((p) => p.id), ['patient-2', patientId]);
      expect(
        (await repo.watchRecent(clinicId, limit: 1).first).single.id,
        'patient-2',
      );
      // Every fixture patient names the same guardian phone.
      expect(
        (await repo.findByGuardianPhone(
          clinicId,
          '9000000004',
        )).map((p) => p.id).toSet(),
        {patientId, 'patient-2'},
      );
      expect(
        await repo.findByGuardianPhone(
          clinicId,
          '9000000004',
          includeInactive: true,
        ),
        hasLength(3),
      );
      expect(await repo.findByGuardianPhone(clinicId, '9000000009'), isEmpty);
      await repo.deactivate(ctx, 'patient-2');
      expect(await repo.watchCount(clinicId).first, 1);
    });

    test(
      'patient numbers are sequential P-00001... on the primary device',
      () async {
        final clinics = env.repos.clinics;
        // The device that created the clinic is its primary device.
        expect(await clinics.primaryDeviceId(clinicId), deviceId);
        expect(await clinics.nextPatientNumber(ctx), 'P-00001');
        expect(await clinics.nextPatientNumber(ctx), 'P-00002');
        expect(await clinics.nextPatientNumber(ctx), 'P-00003');
        // Draft numbers carry the device code so two phones never mint the
        // same number against the server's unique (clinic_id, number) index.
        expect(
          await clinics.nextDraftInvoiceNumber(ctx, now: t0),
          'DRAFT-INV-202610-DEVI-0001',
        );
        expect(
          await clinics.nextDraftInvoiceNumber(ctx, now: t0),
          'DRAFT-INV-202610-DEVI-0002',
        );
        expect(
          await clinics.nextDraftEstimateNumber(ctx, now: t0),
          'DRAFT-EST-202610-DEVI-0001',
        );
        expect(
          isDraftNumber(await clinics.nextDraftInvoiceNumber(ctx, now: t0)),
          isTrue,
        );
      },
    );

    test(
      'a second device mints device-coded numbers that cannot collide',
      () async {
        final clinics = env.repos.clinics;
        const second = ActorContext(
          clinicId: clinicId,
          actorId: dentistId,
          deviceId: '7f3a9c2e-0000-4000-8000-000000000002',
        );
        expect(await clinics.nextPatientNumber(ctx), 'P-00001');
        expect(await clinics.nextPatientNumber(second), 'P-7F3A-00001');
        expect(await clinics.nextPatientNumber(second), 'P-7F3A-00002');
        // The primary's own sequence is untouched by the other device.
        expect(await clinics.nextPatientNumber(ctx), 'P-00002');
        expect(
          await clinics.nextDraftInvoiceNumber(second, now: t0),
          'DRAFT-INV-202610-7F3A-0001',
        );
        expect(
          await clinics.nextDraftInvoiceNumber(ctx, now: t0),
          'DRAFT-INV-202610-DEVI-0001',
        );
        // Every number minted so far is distinct.
        final all = <String>{};
        for (var i = 0; i < 5; i++) {
          expect(all.add(await clinics.nextPatientNumber(ctx)), isTrue);
          expect(all.add(await clinics.nextPatientNumber(second)), isTrue);
        }
        expect(SettingsAccess.deviceCode('ab-1'), 'AB10');
        expect(SettingsAccess.deviceCode('device-1'), 'DEVI');
      },
    );

    test(
      'a clinic without a recorded primary is claimed by the first minter',
      () async {
        final clinics = env.repos.clinics;
        // Simulate a clinic created before the setting existed.
        await env.db.customStatement(
          "DELETE FROM settings WHERE setting_key = 'device.primary'",
        );
        expect(await clinics.primaryDeviceId(clinicId), isNull);
        const other = ActorContext(
          clinicId: clinicId,
          actorId: dentistId,
          deviceId: 'b2c4-second-phone',
        );
        expect(await clinics.nextPatientNumber(other), 'P-00001');
        expect(await clinics.primaryDeviceId(clinicId), 'b2c4-second-phone');
        // The original device is now secondary.
        expect(await clinics.nextPatientNumber(ctx), 'P-DEVI-00001');
        // The owner can move the primary role explicitly.
        await clinics.setPrimaryDevice(ctx, deviceId);
        expect(await clinics.nextPatientNumber(ctx), 'P-00002');
      },
    );

    test('rejects writes for another clinic', () async {
      const other = ActorContext(
        clinicId: 'clinic-2',
        actorId: 'x',
        deviceId: 'y',
      );
      expect(
        () => env.repos.patients.upsert(other, patient()),
        throwsArgumentError,
      );
    });
  });

  group('clinic settings', () {
    test('clinic creation seeds GST defaults, notation and counters', () async {
      final clinics = env.repos.clinics;
      final rates = await clinics.loadGstRates(clinicId);
      expect(rates, hasLength(4));
      final table = await clinics.loadGstRateTable(clinicId);
      final defaults = GstRateTable.indiaDefaults();
      for (final c in GstClass.values) {
        expect(
          table.rateFor(c, at: t0).ratePercent,
          defaults.rateFor(c, at: t0).ratePercent,
        );
      }
      expect(await clinics.loadNotation(clinicId), ToothNotation.fdi);
      await clinics.saveNotation(ctx, ToothNotation.palmer);
      expect(await clinics.loadNotation(clinicId), ToothNotation.palmer);
      expect(
        await clinics.getSetting(clinicId, SettingKeys.patientNumberCounter),
        counterToJson(0),
      );
      final events = await env.repos.audit.forEntity(
        clinicId,
        'Setting',
        '$clinicId:${SettingKeys.notation}',
      );
      expect(events.single.action, AuditAction.settingsChange);
    });

    test('chairs and members', () async {
      final clinics = env.repos.clinics;
      await clinics.upsertChair(
        ctx,
        const Chair(id: 'chair-1', clinicId: clinicId, name: 'Chair 1'),
      );
      await clinics.upsertChair(
        ctx,
        const Chair(
          id: 'chair-2',
          clinicId: clinicId,
          name: 'Surgery',
          sortOrder: 1,
        ),
      );
      expect((await clinics.chairs(clinicId)).map((c) => c.name), [
        'Chair 1',
        'Surgery',
      ]);
      await clinics.deactivateChair(ctx, 'chair-2');
      expect(await clinics.chairs(clinicId), hasLength(1));
      expect(
        await clinics.chairs(clinicId, includeInactive: true),
        hasLength(2),
      );
      expect((await clinics.members(clinicId)).single.isClinician, isTrue);
      await clinics.deactivateMember(ctx, dentistId, reason: 'left');
      expect(await clinics.members(clinicId), isEmpty);
    });
  });

  group('appointments', () {
    setUp(() => env.repos.patients.upsert(ctx, patient()));

    test('range, conflicts and status changes', () async {
      final repo = env.repos.appointments;
      final a = appointment();
      await repo.upsert(ctx, a);
      expect((await repo.getById(a.id))!.toJson(), equals(a.toJson()));

      final inRange = await repo.range(
        clinicId,
        DateTime.utc(2026, 10, 18),
        DateTime.utc(2026, 10, 19),
      );
      expect(inRange.single.id, a.id);
      expect(
        await repo.range(
          clinicId,
          DateTime.utc(2026, 10, 19),
          DateTime.utc(2026, 10, 20),
        ),
        isEmpty,
      );

      // Overlapping on the same chair conflicts.
      final overlapping = await repo.conflicts(
        clinicId: clinicId,
        chairId: 'chair-1',
        start: DateTime.utc(2026, 10, 18, 9, 15),
        end: DateTime.utc(2026, 10, 18, 9, 45),
      );
      expect(overlapping.single.id, a.id);
      // Same provider on another chair also conflicts.
      final sameProvider = await repo.conflicts(
        clinicId: clinicId,
        chairId: 'chair-9',
        providerId: dentistId,
        start: DateTime.utc(2026, 10, 18, 9, 15),
        end: DateTime.utc(2026, 10, 18, 9, 45),
      );
      expect(sameProvider, hasLength(1));
      // Touching edges do not conflict.
      expect(
        await repo.conflicts(
          clinicId: clinicId,
          chairId: 'chair-1',
          providerId: dentistId,
          start: t1,
          end: t2,
        ),
        isEmpty,
      );
      // Excluding itself when rescheduling.
      expect(
        await repo.conflicts(
          clinicId: clinicId,
          chairId: 'chair-1',
          start: t0,
          end: t1,
          excludeId: a.id,
        ),
        isEmpty,
      );
      // Cancelled appointments free the chair.
      await repo.changeStatus(
        ctx,
        a.id,
        AppointmentStatus.cancelled,
        reason: 'patient sick',
      );
      final cancelled = await repo.getById(a.id);
      expect(cancelled!.status, AppointmentStatus.cancelled);
      expect(cancelled.cancelledReason, 'patient sick');
      expect(
        await repo.conflicts(
          clinicId: clinicId,
          chairId: 'chair-1',
          start: t0,
          end: t1,
        ),
        isEmpty,
      );
      final arrived = await repo.changeStatus(
        ctx,
        a.id,
        AppointmentStatus.arrived,
        at: t1,
      );
      expect(arrived.arrivedAt, t1);
    });

    test('visits open and close', () async {
      final repo = env.repos.appointments;
      final v = await repo.startVisit(ctx, visit());
      expect((await repo.openVisit(patientId))!.id, v.id);
      final ended = await repo.endVisit(ctx, v.id, at: t2);
      expect(ended.isOpen, isFalse);
      expect(ended.endedAt, t2);
      expect(await repo.openVisit(patientId), isNull);
      expect(await repo.watchVisits(patientId).first, hasLength(1));
    });
  });
}
