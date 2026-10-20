# Full-dataset reconciliation evidence (2026-10-20)

**Status: BLOCKED FOR FULL-DATA CERTIFICATION.** Automated regression and
read-only full-audit query smoke checks passed against isolated **synthetic
fixture data**, but the original portfolio source files and connected live
commercial model were not accessible for an independent full-run.

## Environment and evidence
- PR: https://github.com/Nathi111/commercial-decision-intelligence-report/pull/1
- SQL audit: `sql/06_full_dataset_audit.sql`
- CI: `.github/workflows/sql-quality.yml` with PostgreSQL 16
- Latest observed CI run: https://github.com/Nathi111/commercial-decision-intelligence-report/actions/runs/39426005921
- Repository `data/README.md` explicitly states the original raw CSV files
  are not committed by default.
- Available connected Supabase/Neon projects do not include a commercial
  analytics dataset project. Do not access unrelated application datasets.

## Validated on the isolated fixture
- 6 raw sales records (Distributor A: 4, B: 1, C: 1).
- 5 accepted staging records and 5 fact records.
- 1 deliberately excluded zero-value raw sales record.
- 1 correctly signed return/credit-note fact line.
- 2 equal-looking invoice lines retained (flagged, not deduplicated).
- **R375** synthetic sales value; **31** net synthetic cases.
- 2 valid inventory fact snapshots.
- Fail-closed regression cases: missing customer, negative closing stock,
  duplicate inventory snapshot, tampered fact revenue.
- Read-only full-audit SQL ran successfully as a smoke test on those fixtures.

These figures are **test-fixture values** and are not the published
Commercial Decision Intelligence dashboard results.

## Full-data controls ready but not certified
1. Raw sales and inventory count/exclusion rates by distributor.
2. Staging-to-fact sales counts, cases and ZAR by distributor and date.
3. Staging-to-fact inventory movement/closing balances by distributor and snapshot.
4. Orphan keys and repeated invoice-line candidates.
5. Stock-flow and month-to-month inventory continuity.
6. Current fiscal-year / matched prior-year revenue, cases, YoY changes and value per case.
7. Latest stock closing cases, depletions, months cover, excess cases at
   granular vs portfolio-total grain.
8. Active FY customer count and top-five customer concentration.

## Published reference values (approximate, NOT signed off)
The README documents ~R49.23m FY revenue, +8.7% YoY revenue growth,
250 active customers, ~7.5 months stock cover and ~5,349 excess cases.
These are historical **synthetic report** snapshots, not exact audit targets.
They must be compared on the same model, refresh date, dates and slicer state.

Potential semantic-model risk: The published DAX `[Excess Stock Cases]`
calculates excess at **current filter grain**. The total-row evaluation of
`MAX(0, [Closing Stock] - 6 × [Depletions])` may differ from the sum of
SKU-level excess. The new read-only audit outputs both interpretations.
Until compared with the original Power BI file, mark this KPI **UNVERIFIED**.

## How to close the blocker (no production write access required)
1. Obtain the six original synthetic source datasets matching the SQL raw tables:
   Distributor A/B/C sales, customer master, product master, inventory.
   An authorized, sanitized full database export is also acceptable.
2. Restore/load into an **isolated non-production PostgreSQL database**.
3. Execute scripts `sql/01_...` through `sql/05_...` with
   `psql -X -v ON_ERROR_STOP=1`, investigate source exclusions, then run
   `sql/06_full_dataset_audit.sql`. Both preflight and postload gates must pass.
4. Reconcile the original Power BI report's **unsliced** FY, prior FY and
   inventory KPIs against the SQL bridge, matching data refresh and filters.
5. Capture row counts, date ranges, exclusion reasons, SQL vs DAX differences
   and reconciliation sign-off here, with exact values and evidence links.

## Release decision
**NO-GO for full data sign-off / PR merge** until full-source load,
exception review and Power BI reconciliation are complete. This does not
invalidate the passing CI regression tests; it limits what they prove.
