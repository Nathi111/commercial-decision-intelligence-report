-- Hard release gate: any lost/duplicated/mutated staged data fails the run.
-- Run after sql/04_reconciliation_checks.sql, before publishing BI outputs.
DO $quality$
BEGIN
    IF EXISTS (SELECT 1 FROM dq_sales_source_to_stage WHERE excluded_source_rows < 0) THEN
        RAISE EXCEPTION 'Reconciliation failed: staging has more sales rows than raw source';
    END IF;
    IF EXISTS (SELECT 1 FROM dq_inventory_source_to_stage WHERE excluded_source_rows < 0) THEN
        RAISE EXCEPTION 'Reconciliation failed: inventory staging exceeds source rows';
    END IF;
    IF EXISTS (SELECT 1 FROM dq_sales_unmapped_keys) THEN
        RAISE EXCEPTION 'Reconciliation failed: sales dimension orphans';
    END IF;
    IF EXISTS (SELECT 1 FROM dq_inventory_unmapped_keys) THEN
        RAISE EXCEPTION 'Reconciliation failed: inventory dimension orphans';
    END IF;
    IF EXISTS (SELECT 1 FROM dq_sales_fact_reconciliation WHERE NOT is_reconciled) THEN
        RAISE EXCEPTION 'Reconciliation failed: staged sales do not balance to fact_sales';
    END IF;
    IF EXISTS (SELECT 1 FROM dq_inventory_fact_reconciliation WHERE NOT is_reconciled) THEN
        RAISE EXCEPTION 'Reconciliation failed: staged inventory does not balance to fact_inventory';
    END IF;
    RAISE NOTICE 'PASS: staged sales and inventory reconcile to fact tables';
END
$quality$;

SELECT * FROM dq_sales_source_to_stage ORDER BY distributor_code;
SELECT * FROM dq_inventory_source_to_stage ORDER BY distributor_code;
SELECT * FROM dq_sales_fact_reconciliation ORDER BY distributor_code, sale_date;
SELECT * FROM dq_inventory_fact_reconciliation ORDER BY distributor_code, snapshot_date;
