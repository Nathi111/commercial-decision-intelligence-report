-- Commercial Decision Intelligence Report
-- Dimension tables

create table dim_customer as
select
    row_number() over (order by customer_code) as customer_id,
    customer_code,
    customer_name,
    channel,
    city,
    province,
    region,
    distributor_code,
    active_flag
from stg_customer_master;

alter table dim_customer
add primary key (customer_id);

alter table dim_customer
add constraint uq_dim_customer_code unique (customer_code);

create table dim_product as
select
    row_number() over (order by product_code) as product_id,
    product_code,
    brand,
    product_name,
    category,
    size_ml,
    pack_size,
    unit_cost_zar,
    recommended_retail_zar,
    active_flag
from stg_product_master;

alter table dim_product
add primary key (product_id);

alter table dim_product
add constraint uq_dim_product_code unique (product_code);

create table dim_date as
select
    d::date as date,
    extract(year from d)::int as calendar_year,
    extract(month from d)::int as calendar_month_number,
    trim(to_char(d, 'Month')) as calendar_month,
    extract(day from d)::int as day_of_month,
    extract(quarter from d)::int as calendar_quarter,
    case
        when extract(month from d) >= 4
            then extract(year from d)::int + 1
        else extract(year from d)::int
    end as fiscal_year,
    ((extract(month from d)::int + 8) % 12) + 1 as fiscal_month_number,
    case
        when extract(month from d) between 4 and 6 then 1
        when extract(month from d) between 7 and 9 then 2
        when extract(month from d) between 10 and 12 then 3
        else 4
    end as fiscal_quarter,
    trim(to_char(d, 'Day')) as day_name,
    case
        when extract(isodow from d) in (6,7) then true
        else false
    end as is_weekend,
    'FY' || case
        when extract(month from d) >= 4
            then (extract(year from d)::int + 1)::text
        else extract(year from d)::int::text
    end as fiscal_year_label,
    'FQ' || case
        when extract(month from d) between 4 and 6 then '1'
        when extract(month from d) between 7 and 9 then '2'
        when extract(month from d) between 10 and 12 then '3'
        else '4'
    end as fiscal_quarter_label,
    to_char(d, 'YYYY-MM') as year_month
from generate_series(
    '2024-04-01'::date,
    '2027-12-31'::date,
    interval '1 day'
) d;

alter table dim_date
add primary key (date);
