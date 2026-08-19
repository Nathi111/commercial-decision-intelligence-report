# Commercial Decision Intelligence Report

An end-to-end commercial analytics portfolio project built to demonstrate how fragmented distributor sales and inventory files can be transformed into a governed decision-intelligence model using **PostgreSQL/Supabase, SQL, Power BI, dimensional modelling and DAX**.

> **Data note:** All data in this project is synthetic and fictional. The solution simulates a realistic FMCG/beverage commercial analytics environment without exposing confidential business data.

## Business Problem

Commercial teams often receive sales, customer, product and inventory information from multiple distributors in different formats. This makes it difficult to answer decision questions consistently:

- How is revenue performing versus the prior year?
- Is growth driven by volume or value per case?
- Which brands, customers and regions drive the portfolio?
- Is revenue concentrated in a small number of customers?
- Which SKUs are overstocked or at risk of stock-out?
- Is inventory deployment aligned with commercial performance?

This project creates a single analytical model that answers those questions from a controlled source of truth.

## Architecture

```text
Raw CSV files
     |
     v
Supabase / PostgreSQL
     |
     +-- Raw tables
     |     raw_distributor_a_sales
     |     raw_distributor_b_sales
     |     raw_distributor_c_sales
     |     raw_customer_master
     |     raw_product_master
     |     raw_inventory
     |
     +-- SQL staging views
     |     stg_sales
     |     stg_customer_master
     |     stg_product_master
     |     stg_inventory
     |
     +-- Analytics layer
           dim_date
           dim_customer
           dim_product
           fact_sales
           fact_inventory
                |
                v
            Power BI
                |
                +-- Executive Overview
                +-- Sales & Growth
                +-- Customer Performance
                +-- Inventory & Supply
```

## Technology Stack

- **Database:** PostgreSQL hosted on Supabase
- **Data ingestion:** CSV imports
- **Transformation:** SQL staging views and dimensional modelling
- **BI:** Microsoft Power BI
- **Semantic modelling:** Star schema, one-to-many single-direction relationships
- **Analytics:** DAX measures and dynamic executive insight measures

## Data Model

```text
                    dim_date
                   /        \
                  *          *
          fact_sales      fact_inventory
           *      *            *
           |      |            |
           1      1            1
 dim_customer   dim_product ----+
```

### Grain

- `fact_sales`: one sales transaction/product line
- `fact_inventory`: one product x distributor x month-end snapshot

Inventory is treated as **semi-additive**. Closing stock is not summed across months; snapshot measures return the latest valid inventory period.

## Key Commercial Findings

The finished report identified the following synthetic business story:

- **FY sales:** R49.23M
- **YoY revenue growth:** +8.7%
- **Case volumes:** broadly flat year-on-year
- **Value per case:** approximately R311.67
- **Growth profile:** value-led rather than volume-led
- **Largest brand:** Vela at approximately 24% of FY sales
- **Top three brands:** approximately 68% of portfolio revenue
- **Active customers:** 250
- **Top five customer contribution:** approximately 3%, indicating low customer concentration risk
- **Largest channel:** Retail
- **Largest geographic market:** Gauteng
- **Latest stock cover:** approximately 7.5 months versus a 3-6 month healthy range
- **Excess-stock SKUs:** 13
- **Healthy SKUs:** 7
- **Low-stock SKUs:** 0
- **Excess stock:** approximately 5,349 cases above the healthy-stock ceiling

### Primary Recommendation

Protect value-led commercial growth while releasing working capital through targeted inventory rebalancing. Prioritise SKUs and brands with stock cover above six months rather than applying broad stock reductions across the portfolio.

## Report Pages

### 1. Executive Overview
Leadership-facing view of sales, YoY growth, volume, stock cover, dynamic insights, sales trend, brand performance and inventory position.

### 2. Sales & Growth
Monthly performance, prior-year comparisons, brand/product contribution, sales mix and value per case.

### 3. Customer Performance
Customer ranking, concentration, channel performance, geographic performance and cumulative/Pareto analysis.

### 4. Inventory & Supply
Latest stock position, stock cover, excess/shortfall cases, SKU health classifications, arrivals/depletions trends and stock-versus-sales decision support.

## Repository Structure

```text
.
├── README.md
├── data/
│   └── README.md
├── sql/
│   ├── 01_staging_layer.sql
│   ├── 02_dimensions.sql
│   └── 03_fact_tables.sql
├── dax/
│   └── measures.md
├── docs/
│   ├── architecture.md
│   ├── data-model.md
│   └── business-findings.md
└── screenshots/
    └── README.md
```

## Skills Demonstrated

- Multi-source data standardisation
- SQL data-quality handling
- PostgreSQL views and relational modelling
- Star-schema design
- Surrogate keys and foreign keys
- Fiscal-calendar modelling (April-March)
- Power BI semantic modelling
- DAX time intelligence
- Semi-additive inventory measures
- Customer concentration analysis
- Inventory health and working-capital analysis
- Dynamic executive insight generation
- Commercial storytelling and dashboard UX

## Synthetic Data Caveat

The prior-year synthetic sales history was generated from the current-year pattern at an approximately uniform discount. As a result, some YoY brand-level growth rates are intentionally uniform and should not be interpreted as a realistic brand-specific growth pattern. The portfolio analysis therefore focuses on sales mix, concentration, seasonality, value/volume dynamics and inventory deployment rather than presenting that artefact as a business finding.

## Author

**Nkosinathi Makhanya**  
Data Analytics | Business Intelligence | Decision Intelligence
