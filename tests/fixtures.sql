-- Minimal, deterministic synthetic source model for the SQL quality gate.
-- These values are fictional and safe to run in ephemeral CI PostgreSQL.
CREATE TABLE raw_distributor_a_sales (
    invoice_no text, transaction_date date, customer_code text, product_code text,
    quantity_cases numeric, net_sales_zar numeric
);
CREATE TABLE raw_distributor_b_sales (
    "Invoice" text, "Txn_Date" text, "Outlet_ID" text, "SKU" text,
    "Sales_Qty" numeric, "Net_Value" text
);
CREATE TABLE raw_distributor_c_sales (
    document_id text, date_sold text, account_number text, item_number text,
    cases_sold numeric, sales_value numeric
);
CREATE TABLE raw_customer_master (
    customer_code text, customer_name text, channel text, city text, province text,
    region text, distributor_code text, active_flag text
);
CREATE TABLE raw_product_master (
    product_code text, brand text, product_name text, category text,
    size_ml numeric, pack_size numeric, unit_cost_zar numeric,
    recommended_retail_zar numeric, active_flag text
);
CREATE TABLE raw_inventory (
    month_end text, distributor_code text, product_code text,
    opening_stock_cases numeric, arrivals_cases numeric,
    depletions_cases numeric, closing_stock_cases numeric
);

INSERT INTO raw_customer_master VALUES
('C1', 'Customer One', 'Retail', 'Johannesburg', 'Gauteng', 'Gauteng', 'DISTA', 'Y'),
('C2', 'Customer Two', 'Retail', 'Durban', 'KZN', 'KZN', 'DISTB', 'Y'),
('C3', 'Customer Three', 'Trade', 'Pretoria', 'Gauteng', 'Gauteng', 'DISTC', 'Y');
INSERT INTO raw_product_master VALUES
('SKU1', 'Vela', 'Product 1', 'Spirit', 750, 12, 40, 60, 'Y'),
('SKU2', 'Vela', 'Product 2', 'Spirit', 750, 12, 45, 65, 'Y'),
('SKU3', 'Marula Crest', 'Product 3', 'Spirit', 750, 12, 50, 70, 'Y');

-- Two identical lines have no safe source line ID: both must be preserved.
INSERT INTO raw_distributor_a_sales VALUES
('INV-A-1', '2025-09-15', ' C1 ', ' SKU1 ', 10, 100),
('INV-A-1', '2025-09-15', ' C1 ', ' SKU1 ', 10, 100),
('CN-A-1', '2025-09-15', 'C1', 'SKU1', -2, -20),
('ZERO-REJECT', '2025-09-15', 'C1', 'SKU1', 0, 0);
INSERT INTO raw_distributor_b_sales VALUES
('INV-B-1', '15/09/2025', 'C2', 'SKU2', 5, 'R 75.00');
INSERT INTO raw_distributor_c_sales VALUES
('INV-C-1', '15-Sep-2025', 'C3', 'SKU-3', 8, 120);

INSERT INTO raw_inventory VALUES
('2025/09/30', 'DISTA', 'SKU1', 30, 10, 5, 35),
('2025/09/30', 'DIST-B', 'SKU2', 20, 5, 10, 15);
