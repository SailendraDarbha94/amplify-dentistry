import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:ampdent_mobile/features/lab/lab_actions.dart';
import 'package:ampdent_mobile/features/recall/patient_messenger.dart';
import 'package:flutter_test/flutter_test.dart';

import '../recall/feature_harness.dart';

void main() {
  late AppTestEnv env;
  late List<Uri> launched;

  LabCaseActions actions(DateTime now) => LabCaseActions(
    labs: env.repos.labs,
    chart: env.repos.chart,
    messenger: PatientMessenger(
      messaging: _NoopMessaging(env),
      logs: env.repos.messages,
      consents: env.repos.consents,
      ctx: testCtx,
      launch: (uri) async {
        launched.add(uri);
        return true;
      },
      clock: () => now,
    ),
    ctx: testCtx,
    clock: () => now,
  );

  setUp(() async {
    env = await AppTestEnv.open(withPatient: true);
    launched = [];
    await env.repos.labs.upsertLab(testCtx, labFixture(days: 1));
  });
  tearDown(() => env.close());

  test(
    'due date skips Sunday: sent Saturday, 1 working day -> Monday',
    () async {
      final saturday = DateTime.utc(2026, 10, 24, 11);
      expect(saturday.weekday, DateTime.saturday);
      await env.repos.labs.createCase(testCtx, labCaseFixture(id: 'c1'));
      final sent = await actions(saturday).markSent('c1');
      expect(sent.status, LabCaseStatus.sent);
      expect(sent.sentAt, saturday);
      expect(sent.dueAt, DateTime.utc(2026, 10, 26, 11));
      expect(sent.dueAt!.weekday, DateTime.monday);
    },
  );

  test(
    'five working days from a Monday land on Saturday, not Sunday',
    () async {
      await env.repos.labs.upsertLab(testCtx, labFixture(days: 5));
      await env.repos.labs.createCase(testCtx, labCaseFixture(id: 'c5'));
      final monday = DateTime.utc(2026, 10, 19, 11);
      final sent = await actions(monday).markSent('c5');
      expect(sent.dueAt, DateTime.utc(2026, 10, 24, 11));
      expect(sent.dueAt, computeDueDate(monday, 5));
    },
  );

  test('status transitions stamp their timestamps in order', () async {
    await env.repos.labs.createCase(testCtx, labCaseFixture(id: 'c2'));
    final t0 = DateTime.utc(2026, 10, 19, 10);
    final sent = await actions(t0).markSent('c2');
    expect(sent.sentAt, t0);

    final t1 = t0.add(const Duration(days: 2));
    final received = await actions(t1).markReceived('c2');
    expect(received.status, LabCaseStatus.received);
    expect(received.receivedAt, t1);
    expect(received.sentAt, t0);

    final t2 = t1.add(const Duration(hours: 1));
    final qc = await actions(t2).markQualityChecked('c2');
    expect(qc.status, LabCaseStatus.qualityChecked);
    expect(qc.qualityCheckedAt, t2);

    final t3 = t2.add(const Duration(days: 1));
    final fitted = await actions(t3).markFitted('c2');
    expect(fitted.status, LabCaseStatus.fitted);
    expect(fitted.fittedAt, t3);
    expect(fitted.receivedAt, t1);
    expect(fitted.status.isOpen, isFalse);
    expect(LabCaseActions.nextStatus(fitted), isNull);
  });

  test('nextStatus walks created -> sent -> received -> QC -> fitted', () {
    final c = labCaseFixture(id: 'n');
    expect(LabCaseActions.nextStatus(c), LabCaseStatus.sent);
    expect(
      LabCaseActions.nextStatus(c.copyWith(status: LabCaseStatus.sent)),
      LabCaseStatus.received,
    );
    expect(
      LabCaseActions.nextStatus(c.copyWith(status: LabCaseStatus.received)),
      LabCaseStatus.qualityChecked,
    );
    expect(
      LabCaseActions.nextStatus(
        c.copyWith(status: LabCaseStatus.qualityChecked),
      ),
      LabCaseStatus.fitted,
    );
    expect(
      LabCaseActions.nextStatus(
        c.copyWith(status: LabCaseStatus.remakeRequested),
      ),
      isNull,
    );
  });

  test('remake requires a reason and creates a linked case', () async {
    await env.repos.labs.createCase(testCtx, labCaseFixture(id: 'c3'));
    final a = actions(DateTime.utc(2026, 10, 20, 9));
    await a.markSent('c3');
    await a.markReceived('c3');
    expect(() => a.requestRemake('c3', '   '), throwsArgumentError);
    final remake = await a.requestRemake('c3', 'Open margin');
    expect(remake.remakeOfCaseId, 'c3');
    expect(remake.remakeReason, 'Open margin');
    expect(remake.status, LabCaseStatus.created);
    expect(remake.teeth, [ToothId.parse('16')]);
    final original = await env.repos.labs.getCase('c3');
    expect(original!.status, LabCaseStatus.remakeRequested);
  });

  test('cancel requires a reason', () async {
    await env.repos.labs.createCase(testCtx, labCaseFixture(id: 'c4'));
    final a = actions(harnessNow);
    expect(() => a.cancel('c4', ''), throwsArgumentError);
    final cancelled = await a.cancel('c4', 'Patient changed plan');
    expect(cancelled.status, LabCaseStatus.cancelled);
  });

  test('create from a procedure links labCaseId on the procedure', () async {
    final p = procedureFixture(
      id: 'crn-16',
      code: 'CRN-ZIR',
      name: 'Zirconia crown',
      status: ProcedureStatus.accepted,
      tooth: '16',
    );
    await env.repos.chart.createProcedure(testCtx, p);
    final created = await actions(harnessNow)
        .create(labCaseFixture(id: 'c6', procedureId: 'crn-16'));
    final after = await env.repos.chart.getProcedure('crn-16');
    expect(after!.labCaseId, created.id);
  });
}

/// Messaging stub: renders the request into a queued log row like the deep
/// link provider would, without touching any platform channel.
class _NoopMessaging implements MessagingProvider {
  _NoopMessaging(this.env);
  final AppTestEnv env;

  @override
  Future<MessageLog> send(MessageRequest request) async {
    final log = request.toLog(id: newId(), now: harnessNow.toUtc());
    return env.repos.messages.enqueue(testCtx, log);
  }

  @override
  Future<MessageStatus> status(String providerMessageId) async =>
      MessageStatus.queued;
}
