-- Auditable source -> staging -> fact controls.
-- The source count gap may be nonzero because source data deliberately contains
-- invalid inputs. Investigate these separately; stage -> fact MUST balance.
CREATE OR REPLACE VIEW dq_sales_source_to_stage AS
WITH source_counts AS (
    SELECT 'DISTA'::text AS distributor_code, count(*)::bigint AS raw_rows FROM raw_distributor_a_sales
    UNION ALL SELECT 'DISTB', count(*) FROM raw_distributor_b_sales
    UNION ALL SELECT 'DISTC', count(*) FROM raw_distributor_c_sales
),
stage_counts AS (
    SELECT distributor_code, count(*)::bigint AS staged_rows,
           sum(quantity_cases) AS staged_cases,
           sum(net_sales_zar) AS staged_sales_zar
    FROM stg_sales GROUP BY distributor_code
)
SELECT r.distributor_code, r.raw_rows,
       coalesce(s.staged_rows, 0) AS staged_rows,
       r.raw_rows - coalesce(s.staged_rows, 0) AS excluded_source_rows,
       round(100.0 * (r.raw_rows - coalesce(s.staged_rows, 0))
            / nullif(r.raw_rows, 0), 2) AS excluded_source_pct,
       coalesce(s.staged_cases, 0) AS staged_cases,
       coalesce(s.staged_sales_zar, 0) AS staged_sales_zar
FROM source_counts r
LEFT JOIN stage_counts s USING (distributor_code);

-- Inventory also needs visible source exclusions; a repeated source snapshot
-- cannot be silently discarded or counted twice.
CREATE OR REPLACE VIEW dq_inventory_source_to_stage AS
WITH source_counts AS (
    SELECT CASE WHEN upper(trim(distributor_code)) = 'DIST-B'
                THEN 'DISTB' ELSE upper(trim(distributor_code)) END AS distributor_code,
           count(*)::bigint AS raw_rows
    FROM raw_inventory GROUP BY 1
),
stage_counts AS (
    SELECT distributor_code, count(*)::bigint AS staged_rows
    FROM stg_inventory GROUP BY distributor_code
)
SELECT r.distributor_code, r.raw_rows,
       coalesce(s.staged_rows, 0) AS staged_rows,
       r.raw_rows - coalesce(s.staged_rows, 0) AS excluded_source_rows
FROM source_counts r
LEFT JOIN stage_counts s USING (distributor_code);

-- Preflight diagnostics: query directly after a failed fact build.
CREATE OR REPLACE VIEW dq_sales_unmapped_keys AS
SELECT s.distributor_code, s.invoice_no, s.transaction_date,
       s.customer_code, s.product_code,
       (d.date IS NULL) AS missing_date,
       (c.customer_id IS NULL) AS missing_customer,
       (p.product_id IS NULL) AS missing_product
FROM stg_sales s
LEFT JOIN dim_date d ON d.date = s.transaction_date
LEFT JOIN dim_customer c ON c.customer_code = s.customer_code
LEFT JOIN dim_product p ON p.product_code = s.product_code
WHERE d.date IS NULL OR c.customer_id IS NULL OR p.product_id IS NULL;

CREATE OR REPLACE VIEW dq_inventory_unmapped_keys AS
SELECT i.distributor_code, i.month_end, i.product_code,
       (d.date IS NULL) AS missing_date,
       (p.product_id IS NULL) AS missing_product
FROM stg_inventory i
LEFT JOIN dim_date d ON d.date = i.month_end
LEFT JOIN dim_product p ON p.product_code = i.product_code
WHERE d.date IS NULL OR p.product_id IS NULL;

-- These are REVIEW CANDIDATES, not duplicates to automatically remove.
-- An invoice may contain multiple legitimate lines of the same SKU.
CREATE OR REPLACE VIEW dq_sales_repeated_line_candidates AS
SELECT distributor_code, invoice_no, transaction_date, customer_code, product_code,
       count(*) AS line_count, sum(quantity_cases) AS cases,
       sum(net_sales_zar) AS sales_zar
FROM stg_sales
GROUP BY distributor_code, invoice_no, transaction_date, customer_code, product_code
HAVING count(*) > 1;

CREATE OR REPLACE VIEW dq_sales_fact_reconciliation AS
WITH staged AS (
    SELECT distributor_code, transaction_date AS sale_date,
           count(*)::bigint AS rows, sum(quantity_cases) AS cases,
           sum(net_sales_zar) AS sales_zar
    FROM stg_sales GROUP BY 1, 2
),
loaded AS (
    SELECT distributor_code, date AS sale_date,
           count(*)::bigint AS rows, sum(quantity_cases) AS cases,
           sum(net_sales_zar) AS sales_zar
    FROM fact_sales GROUP BY 1, 2
)
SELECT coalesce(s.distributor_code, f.distributor_code) AS distributor_code,
       coalesce(s.sale_date, f.sale_date) AS sale_date,
       coalesce(s.rows, 0) AS staged_rows, coalesce(f.rows, 0) AS fact_rows,
       coalesce(s.cases, 0) AS staged_cases, coalesce(f.cases, 0) AS fact_cases,
       coalesce(s.sales_zar, 0) AS staged_sales_zar,
       coalesce(f.sales_zar, 0) AS fact_sales_zar,
       coalesce(s.rows, 0) = coalesce(f.rows, 0)
         AND abs(coalesce(s.cases, 0) - coalesce(f.cases, 0)) <= 0.000001
         AND abs(coalesce(s.sales_zar, 0) - coalesce(f.sales_zar, 0)) <= 0.01
         AS is_reconciled
FROM staged s FULL OUTER JOIN loaded f
ON s.distributor_code = f.distributor_code AND s.sale_date = f.sale_date;

-- Inventory balances must be compared within a snapshot, not added over time.
CREATE OR REPLACE VIEW dq_inventory_fact_reconciliation AS
WITH staged AS (
    SELECT distributor_code, month_end AS snapshot_date,
           count(*)::bigint AS rows,
           sum(opening_stock_cases) AS opening_cases,
           sum(arrivals_cases) AS arrivals_cases,
           sum(depletions_cases) AS depletions_cases,
           sum(closing_stock_cases) AS closing_cases
    FROM stg_inventory GROUP BY 1, 2
),
loaded AS (
    SELECT distributor_code, date AS snapshot_date,
           count(*)::bigint AS rows,
           sum(opening_stock_cases) AS opening_cases,
           sum(arrivals_cases) AS arrivals_cases,
           sum(depletions_cases) AS depletions_cases,
           sum(closing_stock_cases) AS closing_cases
    FROM fact_inventory GROUP BY 1, 2
)
SELECT coalesce(s.distributor_code, f.distributor_code) AS distributor_code,
       coalesce(s.snapshot_date, f.snapshot_date) AS snapshot_date,
       coalesce(s.rows, 0) AS staged_rows, coalesce(f.rows, 0) AS fact_rows,
       coalesce(s.closing_cases, 0) AS staged_closing_cases,
       coalesce(f.closing_cases, 0) AS fact_closing_cases,
       coalesce(s.rows, 0) = coalesce(f.rows, 0)
         AND abs(coalesce(s.opening_cases, 0) - coalesce(f.opening_cases, 0)) <= 0.000001
         AND abs(coalesce(s.arrivals_cases, 0) - coalesce(f.arrivals_cases, 0)) <= 0.000001
         AND abs(coalesce(s.depletions_cases, 0) - coalesce(f.depletions_cases, 0)) <= 0.000001
         AND abs(coalesce(s.closing_cases, 0) - coalesce(f.closing_cases, 0)) <= 0.000001
         AS is_reconciled
FROM staged s FULL OUTER JOIN loaded f
ON s.distributor_code = f.distributor_code AND s.snapshot_date = f.snapshot_date;
