-- 0007_estimate_binding_rx_snapshot.sql
-- Schema parity with Drift schema v4 (the Dart side is the contract):
--   1. estimates.plan_version / plan_snapshot_hash: the plan version and the SHA-256 of the plan lines an
--      estimate was issued from, so acceptance can tell when the plan changed after the patient saw it.
--   2. treatment_plans.estimate_declined_reason: why the patient declined a written estimate before
--      accepting (the only way to accept without one; DCI 5.7.1 estimates precede treatment).
--   3. prescriptions.patient_snapshot: the patient demographics frozen at issue (PatientSnapshot), so a
--      reprint shows what the signed original showed after the patient record changes.
--   drugs.clinic_id already exists server-side (0001); the Dart Drug entity now carries it too.

alter table public.estimates
  add column plan_version       integer check (plan_version >= 1),
  add column plan_snapshot_hash text;
comment on column public.estimates.plan_version is
  'Version of the plan the estimate was issued from.';
comment on column public.estimates.plan_snapshot_hash is
  'computePlanSnapshotHash of the plan lines at issue; acceptance compares it with the live lines.';

alter table public.treatment_plans
  add column estimate_declined_reason text;
comment on column public.treatment_plans.estimate_declined_reason is
  'Recorded when the patient declined a written estimate and accepted the plan without one.';

alter table public.prescriptions
  add column patient_snapshot jsonb
  check (patient_snapshot is null or jsonb_typeof(patient_snapshot) = 'object');
comment on column public.prescriptions.patient_snapshot is
  'PatientSnapshot JSON frozen at issue: name, number, age, sex, address, phone, guardian.';
