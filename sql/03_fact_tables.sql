-- Commercial Decision Intelligence Report
-- Fact tables

-- Fail closed before any fact is built: dimension joins must never silently remove rows.
-- Run AFTER dimensions have been created and BEFORE loading facts.
DO $quality$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM stg_sales) THEN
        RAISE EXCEPTION 'Data integrity preflight failed: sales staging is empty';
    END IF;

    IF EXISTS (
        SELECT 1 FROM stg_sales
        WHERE invoice_no IS NULL OR btrim(invoice_no) = ''
           OR transaction_date IS NULL
           OR quantity_cases = 0 OR net_sales_zar = 0
           OR sign(quantity_cases) <> sign(net_sales_zar)
    ) THEN
        RAISE EXCEPTION 'Data integrity preflight failed: invalid staged sale/credit note';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM stg_sales s
        LEFT JOIN dim_date d ON d.date = s.transaction_date
        LEFT JOIN dim_customer c ON c.customer_code = s.customer_code
        LEFT JOIN dim_product p ON p.product_code = s.product_code
        WHERE d.date IS NULL OR c.customer_id IS NULL OR p.product_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Data integrity preflight failed: unmapped sales date/customer/product; run the orphan-key diagnostics';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM stg_inventory i
        LEFT JOIN dim_date d ON d.date = i.month_end
        LEFT JOIN dim_product p ON p.product_code = i.product_code
        WHERE d.date IS NULL OR p.product_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Data integrity preflight failed: unmapped inventory date/product';
    END IF;

    IF EXISTS (
        SELECT 1 FROM stg_inventory
        GROUP BY month_end, distributor_code, product_code
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'Data integrity preflight failed: duplicate inventory snapshot grain';
    END IF;

    IF EXISTS (
        SELECT 1 FROM stg_inventory
        WHERE opening_stock_cases IS NULL OR arrivals_cases IS NULL
           OR depletions_cases IS NULL OR closing_stock_cases IS NULL
           OR closing_stock_cases < 0
    ) THEN
        RAISE EXCEPTION 'Data integrity preflight failed: invalid inventory quantity';
    END IF;
END
$quality$;


create table fact_sales as
select
    row_number() over (
        order by s.transaction_date, s.distributor_code, s.invoice_no, s.customer_code, s.product_code
    ) as sales_id,
    d.date,
    c.customer_id,
    p.product_id,
    s.invoice_no,
    s.distributor_code,
    s.quantity_cases,
    s.net_sales_zar,
    round(s.net_sales_zar / nullif(s.quantity_cases, 0), 2) as avg_sales_per_case
from stg_sales s
inner join dim_date d
    on s.transaction_date = d.date
inner join dim_customer c
    on s.customer_code = c.customer_code
inner join dim_product p
    on s.product_code = p.product_code;

alter table fact_sales add primary key (sales_id);
alter table fact_sales
add constraint fk_fact_sales_date foreign key (date) references dim_date(date);
alter table fact_sales
add constraint fk_fact_sales_customer foreign key (customer_id) references dim_customer(customer_id);
alter table fact_sales
add constraint fk_fact_sales_product foreign key (product_id) references dim_product(product_id);

create table fact_inventory as
select
    row_number() over (
        order by i.month_end, i.distributor_code, i.product_code
    ) as inventory_id,
    i.month_end as date,
    p.product_id,
    i.distributor_code,
    i.opening_stock_cases,
    i.arrivals_cases,
    i.depletions_cases,
    i.closing_stock_cases,
    case
        when i.depletions_cases > 0
            then round(i.closing_stock_cases / i.depletions_cases, 2)
        else null
    end as stock_cover_months
from stg_inventory i
inner join dim_date d
    on i.month_end = d.date
inner join dim_product p
    on i.product_code = p.product_code
; -- negative balances fail the preflight instead of being silently discarded

alter table fact_inventory add primary key (inventory_id);
alter table fact_inventory
add constraint fk_fact_inventory_date foreign key (date) references dim_date(date);
alter table fact_inventory
add constraint fk_fact_inventory_product foreign key (product_id) references dim_product(product_id);
