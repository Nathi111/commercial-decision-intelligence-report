-- Commercial Decision Intelligence Report
-- Staging layer
-- PostgreSQL / Supabase

-- Distributor A
create or replace view stg_distributor_a_sales as
select distinct
    trim(invoice_no) as invoice_no,
    transaction_date::date as transaction_date,
    upper(trim(customer_code)) as customer_code,
    upper(trim(product_code)) as product_code,
    quantity_cases::numeric as quantity_cases,
    net_sales_zar::numeric as net_sales_zar,
    'DISTA'::text as distributor_code
from raw_distributor_a_sales
where customer_code is not null
  and product_code is not null
  and quantity_cases is not null
  and quantity_cases::numeric > 0
  and net_sales_zar is not null
  and net_sales_zar::numeric > 0;

-- Distributor B
create or replace view stg_distributor_b_sales as
select distinct
    trim("Invoice") as invoice_no,
    to_date(trim("Txn_Date"), 'DD/MM/YYYY') as transaction_date,
    upper(trim("Outlet_ID")) as customer_code,
    upper(trim("SKU")) as product_code,
    "Sales_Qty"::numeric as quantity_cases,
    replace(replace(trim("Net_Value"), 'R ', ''), ',', '')::numeric as net_sales_zar,
    'DISTB'::text as distributor_code
from raw_distributor_b_sales
where "Outlet_ID" is not null
  and "SKU" is not null
  and "Sales_Qty" is not null
  and "Sales_Qty"::numeric > 0
  and "Net_Value" is not null;

-- Distributor C
create or replace view stg_distributor_c_sales as
select distinct
    trim(document_id) as invoice_no,
    to_date(trim(date_sold), 'DD-Mon-YYYY') as transaction_date,
    upper(trim(account_number)) as customer_code,
    case
        when upper(trim(item_number)) like 'SKU-%'
            then replace(upper(trim(item_number)), 'SKU-', 'SKU')
        else upper(trim(item_number))
    end as product_code,
    cases_sold::numeric as quantity_cases,
    sales_value::numeric as net_sales_zar,
    'DISTC'::text as distributor_code
from raw_distributor_c_sales
where account_number is not null
  and trim(account_number) <> ''
  and item_number is not null
  and cases_sold is not null
  and cases_sold::numeric > 0
  and sales_value is not null;

-- Consolidated sales staging view
create or replace view stg_sales as
select invoice_no, transaction_date, customer_code, product_code,
       quantity_cases, net_sales_zar, distributor_code
from stg_distributor_a_sales
union all
select invoice_no, transaction_date, customer_code, product_code,
       quantity_cases, net_sales_zar, distributor_code
from stg_distributor_b_sales
union all
select invoice_no, transaction_date, customer_code, product_code,
       quantity_cases, net_sales_zar, distributor_code
from stg_distributor_c_sales;

-- Customer master
create or replace view stg_customer_master as
select distinct
    upper(trim(customer_code)) as customer_code,
    trim(customer_name) as customer_name,
    case
        when channel is null or trim(channel) = '' then 'Unknown'
        else initcap(trim(channel))
    end as channel,
    case
        when city is null or trim(city) = '' then 'Unknown'
        else trim(city)
    end as city,
    case
        when upper(trim(province)) in ('KZN','KWAZULU NATAL','KWAZULU-NATAL')
            then 'KwaZulu-Natal'
        else trim(province)
    end as province,
    case
        when upper(trim(region)) in ('KZN','KWAZULU NATAL','KWAZULU-NATAL')
            then 'KwaZulu-Natal'
        else trim(region)
    end as region,
    upper(trim(distributor_code)) as distributor_code,
    upper(trim(active_flag)) as active_flag
from raw_customer_master
where customer_code is not null
  and trim(customer_code) <> '';

-- Product master
create or replace view stg_product_master as
select distinct
    upper(trim(product_code)) as product_code,
    case
        when lower(trim(brand)) = 'marula crest' then 'Marula Crest'
        else initcap(trim(brand))
    end as brand,
    trim(product_name) as product_name,
    initcap(trim(category)) as category,
    size_ml::numeric as size_ml,
    pack_size::numeric as pack_size,
    unit_cost_zar::numeric as unit_cost_zar,
    recommended_retail_zar::numeric as recommended_retail_zar,
    upper(trim(active_flag)) as active_flag
from raw_product_master
where product_code is not null
  and trim(product_code) <> '';

-- Inventory
create or replace view stg_inventory as
select distinct
    to_date(trim(month_end), 'YYYY/MM/DD') as month_end,
    case
        when upper(trim(distributor_code)) = 'DIST-B' then 'DISTB'
        else upper(trim(distributor_code))
    end as distributor_code,
    upper(trim(product_code)) as product_code,
    opening_stock_cases::numeric as opening_stock_cases,
    arrivals_cases::numeric as arrivals_cases,
    depletions_cases::numeric as depletions_cases,
    closing_stock_cases::numeric as closing_stock_cases
from raw_inventory
where product_code is not null
  and trim(product_code) <> ''
  and distributor_code is not null
  and trim(distributor_code) <> '';
