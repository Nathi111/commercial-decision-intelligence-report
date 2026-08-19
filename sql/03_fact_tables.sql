-- Commercial Decision Intelligence Report
-- Fact tables

create table fact_sales as
select
    row_number() over (
        order by s.transaction_date, s.invoice_no, s.customer_code, s.product_code
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
where i.closing_stock_cases >= 0;

alter table fact_inventory add primary key (inventory_id);
alter table fact_inventory
add constraint fk_fact_inventory_date foreign key (date) references dim_date(date);
alter table fact_inventory
add constraint fk_fact_inventory_product foreign key (product_id) references dim_product(product_id);
