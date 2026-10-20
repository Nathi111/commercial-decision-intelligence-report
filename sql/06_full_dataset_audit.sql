-- Full synthetic dataset audit (read-only): run on a COPY of the complete
-- raw-source portfolio database after SQL scripts 01–05 have completed.
-- The published README metrics are approximate historical dashboard snapshots;
-- do not certify against them without matching model, refresh and filters.
-- Execute: psql -X -v ON_ERROR_STOP=1 -d <isolated_database> -f sql/06_full_dataset_audit.sql
BEGIN TRANSACTION READ ONLY;

-- 1. Raw -> staging: records intentionally filtered require business review.
SELECT 'sales_source_to_stage' AS section, distributor_code, raw_rows,
       staged_rows, excluded_source_rows, excluded_source_pct,
       staged_cases, staged_sales_zar
FROM dq_sales_source_to_stage ORDER BY distributor_code;

SELECT 'inventory_source_to_stage' AS section, distributor_code, raw_rows,
       staged_rows, excluded_source_rows
FROM dq_inventory_source_to_stage ORDER BY distributor_code;

-- 2. Join coverage and grain quality: failures here invalidate the release.
SELECT 'sales_unmapped_dimension_rows' AS check_name, count(*) AS affected_rows
FROM dq_sales_unmapped_keys
UNION ALL
SELECT 'inventory_unmapped_dimension_rows', count(*)
FROM dq_inventory_unmapped_keys
UNION ALL
SELECT 'repeated_sales_natural_keys_requires_line_id', count(*)
FROM dq_sales_repeated_line_candidates
UNION ALL
SELECT 'duplicate_inventory_snapshot_keys', count(*)
FROM (
    SELECT date, distributor_code, product_id
    FROM fact_inventory GROUP BY date, distributor_code, product_id
    HAVING count(*) > 1
) x
UNION ALL
SELECT 'sales_stage_fact_mismatched_distributor_days', count(*)
FROM dq_sales_fact_reconciliation WHERE NOT is_reconciled
UNION ALL
SELECT 'inventory_stage_fact_mismatched_snapshots', count(*)
FROM dq_inventory_fact_reconciliation WHERE NOT is_reconciled;

-- 3. Source and fact grand totals, including signed credits/returns.
SELECT 'sales_fact_by_distributor' AS section, distributor_code,
       count(*) AS sales_lines,
       count(*) FILTER (WHERE quantity_cases < 0 AND net_sales_zar < 0) AS credit_lines,
       min(date) AS first_sale_date, max(date) AS last_sale_date,
       sum(quantity_cases) AS net_cases, sum(net_sales_zar) AS net_sales_zar
FROM fact_sales GROUP BY distributor_code ORDER BY distributor_code;

-- 4. Stock-flow continuity within the same product/distributor snapshot:
-- opening + arrivals - depletions = closing (may require adjustment policy).
WITH stock_flow AS (
    SELECT date, distributor_code, product_id,
           opening_stock_cases + arrivals_cases - depletions_cases
           - closing_stock_cases AS difference_cases
    FROM fact_inventory
)
SELECT 'inventory_stock_flow' AS section, count(*) AS snapshot_rows,
       count(*) FILTER (WHERE abs(difference_cases) > 0.000001) AS mismatched_rows,
       coalesce(sum(abs(difference_cases)), 0) AS total_abs_difference_cases
FROM stock_flow;

-- 5. Opening vs previous snapshot's closing at the same product/distributor.
-- Late corrections and adjustments may require documented exceptions.
WITH timeline AS (
    SELECT date, distributor_code, product_id, opening_stock_cases,
           lag(closing_stock_cases) OVER (
               PARTITION BY distributor_code, product_id ORDER BY date
           ) AS previous_closing_cases
    FROM fact_inventory
)
SELECT 'inventory_period_continuity' AS section,
       count(*) FILTER (WHERE previous_closing_cases IS NOT NULL) AS comparable_snapshots,
       count(*) FILTER (WHERE previous_closing_cases IS NOT NULL
           AND abs(opening_stock_cases - previous_closing_cases) > 0.000001) AS mismatched_rows
FROM timeline;

-- 6. Unsliced FY DAX bridge: date anchor matches [Latest Sales Date].
WITH anchor AS (
    SELECT max(date) AS latest_sale_date FROM fact_sales
),
periods AS (
    SELECT latest_sale_date,
           make_date(
             extract(year FROM latest_sale_date)::int -
                 CASE WHEN extract(month FROM latest_sale_date)::int < 4 THEN 1 ELSE 0 END,
             4, 1
           ) AS fy_start
    FROM anchor WHERE latest_sale_date IS NOT NULL
),
fy AS (
    SELECT p.latest_sale_date, p.fy_start,
           coalesce(sum(s.net_sales_zar) FILTER (
               WHERE s.date >= p.fy_start AND s.date <= p.latest_sale_date), 0) AS cy_zar,
           coalesce(sum(s.quantity_cases) FILTER (
               WHERE s.date >= p.fy_start AND s.date <= p.latest_sale_date), 0) AS cy_cases,
           coalesce(sum(s.net_sales_zar) FILTER (
               WHERE s.date >= (p.fy_start - interval '12 months')::date
                 AND s.date <= (p.latest_sale_date - interval '12 months')::date), 0) AS py_zar,
           coalesce(sum(s.quantity_cases) FILTER (
               WHERE s.date >= (p.fy_start - interval '12 months')::date
                 AND s.date <= (p.latest_sale_date - interval '12 months')::date), 0) AS py_cases
    FROM periods p CROSS JOIN fact_sales s
    GROUP BY p.latest_sale_date, p.fy_start
)
SELECT 'fy_dax_bridge_unsliced' AS section, fy_start, latest_sale_date,
       cy_zar, py_zar, cy_cases, py_cases,
       round((cy_zar - py_zar) / nullif(py_zar, 0) * 100, 4) AS sales_yoy_growth_pct,
       round((cy_cases - py_cases) / nullif(py_cases, 0) * 100, 4) AS cases_yoy_growth_pct,
       round(cy_zar / nullif(cy_cases, 0), 2) AS current_value_per_case,
       round(py_zar / nullif(py_cases, 0), 2) AS prior_value_per_case
FROM fy;

-- 7. Latest inventory snapshot: align with latest-date DAX convention.
WITH inventory_anchor AS (
    SELECT max(date) AS latest_inventory_date FROM fact_inventory
),
latest AS (
    SELECT f.product_id, f.distributor_code,
           sum(f.closing_stock_cases) AS closing_cases,
           sum(f.depletions_cases) AS depletions_cases
    FROM fact_inventory f CROSS JOIN inventory_anchor a
    WHERE f.date = a.latest_inventory_date
    GROUP BY f.product_id, f.distributor_code
),
agg AS (
    SELECT sum(closing_cases) AS closing_cases,
           sum(depletions_cases) AS depletions_cases,
           sum(CASE WHEN depletions_cases > 0
                       AND closing_cases / nullif(depletions_cases, 0) > 6
                    THEN greatest(0::numeric, closing_cases - 6 * depletions_cases)
                    ELSE 0::numeric END) AS excess_cases_at_sku_distributor_grain
    FROM latest
)
SELECT 'inventory_dax_bridge_unsliced' AS section,
       a.latest_inventory_date,
       agg.closing_cases, agg.depletions_cases,
       round(agg.closing_cases / nullif(agg.depletions_cases, 0), 4) AS cover_months,
       agg.excess_cases_at_sku_distributor_grain,
       CASE WHEN agg.depletions_cases > 0 AND
                      agg.closing_cases / nullif(agg.depletions_cases, 0) > 6
            THEN greatest(0::numeric, agg.closing_cases - 6 * agg.depletions_cases)
            ELSE 0::numeric END AS excess_cases_at_total_grain
FROM inventory_anchor a CROSS JOIN agg;

-- 8. Business segmentation, using unsliced FY to match the same date anchor.
WITH periods AS (
    SELECT max(date) AS latest_date FROM fact_sales
),
fy AS (
    SELECT latest_date,
           make_date(
               extract(year FROM latest_date)::int -
               CASE WHEN extract(month FROM latest_date)::int < 4 THEN 1 ELSE 0 END,
               4, 1
           ) AS fy_start
    FROM periods WHERE latest_date IS NOT NULL
),
customer_totals AS (
    SELECT s.customer_id, sum(s.net_sales_zar) AS sales_zar
    FROM fact_sales s CROSS JOIN fy
    WHERE s.date BETWEEN fy.fy_start AND fy.latest_date
    GROUP BY s.customer_id
),
top_customers AS (
    SELECT customer_id, sales_zar
    FROM customer_totals ORDER BY sales_zar DESC
    FETCH FIRST 5 ROWS WITH TIES
)
SELECT 'customer_kpi_bridge_unsliced' AS section,
       (SELECT count(*) FROM customer_totals) AS active_fy_customers,
       (SELECT sum(sales_zar) FROM customer_totals) AS total_fy_sales,
       (SELECT sum(sales_zar) FROM top_customers) AS top5_sales_including_ties,
       round(100 * (SELECT sum(sales_zar) FROM top_customers) /
            nullif((SELECT sum(sales_zar) FROM customer_totals), 0), 4)
         AS top5_contribution_pct;

COMMIT;
