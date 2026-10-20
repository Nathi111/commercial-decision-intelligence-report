# Data integrity controls — Phase 1

## Contract
Sales grain: one source invoice/product line. **No reliable source line ID**
currently exists in the CSV contracts; therefore identical rows cannot be
assumed to be duplicates. Do not remove them with `DISTINCT`.

Inventory grain: one product × distributor × month-end snapshot. Snapshot
balances must **not** be summed across reporting months.

A credit note/return is accepted only when both quantity and net value are
negative; an ordinary sale must have both positive. Zero-value and mixed-sign
records remain excluded pending a business-approved adjustment policy.
A negative revenue with positive cases may represent a discount or adjustment,
but is deliberately *not* reclassified as a standard sale or return.

## Execution order
After loading the six `raw_*` source tables into an **isolated non-production
PostgreSQL database**, execute the files with `psql -v ON_ERROR_STOP=1`:

1. `sql/01_staging_layer.sql` — normalize sales and inventory, preserving signed returns
2. `sql/02_dimensions.sql` — conformed dimensions
3. `sql/03_fact_tables.sql` — **preflight gate** then build facts
4. `sql/04_reconciliation_checks.sql` — source/stage and stage/fact audit views
5. `sql/05_assert_reconciliation.sql` — **postload gate**, exit nonzero on mismatch

The preflight rejects missing sales invoice numbers, missing customer/product/date
dimension mappings, invalid or negative inventory balances, duplicate inventory snapshot keys and inconsistent
sale/return signs. The postload gate rejects any stage-to-fact loss, multiplication
or changed case/revenue/snapshot totals by distributor and period.

## Diagnostics
- `SELECT * FROM dq_sales_source_to_stage;` shows raw/staged count,
  excluded-record count and exclusion rate for each distributor.
  **Nonzero exclusions do not automatically fail:** the synthetic source contains
  deliberate invalid rows. Review them against the business rules and retain a
  source-file audit separately when applying to real data.
- `SELECT * FROM dq_inventory_source_to_stage;` shows raw/staged snapshot counts.
- `SELECT * FROM dq_sales_unmapped_keys;` identifies missing sales dimensions.
- `SELECT * FROM dq_inventory_unmapped_keys;` identifies missing inventory dimensions.
- `SELECT * FROM dq_sales_repeated_line_candidates;` highlights repeated
  natural keys for review. It does **not** delete them because a source line ID
  is needed to distinguish duplicates from legitimate multi-line invoices.
- `SELECT * FROM dq_sales_fact_reconciliation WHERE NOT is_reconciled;`
- `SELECT * FROM dq_inventory_fact_reconciliation WHERE NOT is_reconciled;`

## Boundaries and limitations
- Source exclusions are currently **count-only**, not a persistent rejected-row
  table with reasons. Before production ingestion, add stable source-row
  identifiers and explicit row-level exception capture.
- The existing source parsers still assume valid numeric/date representations
  after known schema normalization. Unsupported malformed strings can fail SQL
  parsing rather than be quarantined. Add safe typed-landing validation next.
- Source tables are intended for one landed batch at a time. The current script
  rebuilds facts; it is not a multi-batch incremental ingestion strategy.
- Keep the April-to-March fiscal calendar and Power BI semantic model unchanged
  until the new SQL checks have been run against the full synthetic dataset.
- Never use these synthetic regression results as proof of a live database
  reconciliation. The actual dataset must pass the same controls separately.

## Automated regression scenarios
`tests/run_sql_quality_tests.sh` creates disposable PostgreSQL databases to
assert: (a) valid records pass, (b) identical source lines survive,
(c) signed credits reduce net sales and cases, (d) excluded raw rows are counted,
(e) missing customer mappings, negative stock and duplicate inventory snapshots fail preflight,
(f) changed fact values fail postload reconciliation.

In GitHub, `.github/workflows/sql-quality.yml` runs the tests in an ephemeral
Postgres 16 container on pull requests and main.
