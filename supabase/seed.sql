-- seed.sql
-- Intentionally empty of data.
--
-- Nothing patient-related is ever seeded here. The reference vocabularies
-- (Indian procedure catalogue, ICD-10 K00-K14, dental drug master, consent
-- templates, recall rules, GST state codes) ship inside the app in
-- packages/terminology (package:ampdent_terminology) and are written into
-- public.catalog_items / public.drugs per clinic by the app on first run,
-- so a clinic can edit its own copy without touching other tenants.
--
-- Platform-wide rows (clinic_id is null in catalog_items / drugs) may be
-- added later by a maintenance script run with the service role; they are
-- read-only for clinic members through RLS.

select 1 as seed_noop;
