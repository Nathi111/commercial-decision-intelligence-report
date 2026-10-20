-- Positive checks: repeats survive, returns stay signed, known exclusions
-- are visible, and inventory/finance outputs balance.
DO $test$
BEGIN
    IF (SELECT count(*) FROM stg_sales) <> 5 THEN
        RAISE EXCEPTION 'Expected five valid staged rows';
    END IF;
    IF (SELECT count(*) FROM fact_sales) <> 5 THEN
        RAISE EXCEPTION 'Expected five fact sales rows; a repeated line may have been dropped';
    END IF;
    IF (SELECT sum(quantity_cases) FROM fact_sales) <> 31 THEN
        RAISE EXCEPTION 'Expected signed sales quantity of 31 cases';
    END IF;
    IF (SELECT sum(net_sales_zar) FROM fact_sales) <> 375 THEN
        RAISE EXCEPTION 'Expected signed revenue of 375';
    END IF;
    IF (SELECT count(*) FROM fact_sales
        WHERE quantity_cases < 0 AND net_sales_zar < 0) <> 1 THEN
        RAISE EXCEPTION 'Credit note/return not preserved';
    END IF;
    IF (SELECT excluded_source_rows FROM dq_sales_source_to_stage
        WHERE distributor_code = 'DISTA') <> 1 THEN
        RAISE EXCEPTION 'Source exclusion count should expose the zero-value record';
    END IF;
    IF (SELECT count(*) FROM dq_sales_repeated_line_candidates) <> 1 THEN
        RAISE EXCEPTION 'Identical source lines should be flagged for review without deleting them';
    END IF;
    IF (SELECT count(*) FROM fact_inventory) <> 2 THEN
        RAISE EXCEPTION 'Expected both inventory snapshots';
    END IF;
END
$test$;
