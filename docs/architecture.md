# Solution Architecture

## Objective

Create a lightweight commercial decision-intelligence platform that converts fragmented distributor and inventory files into a governed analytical model for Power BI.

## Layers

### 1. Raw layer

The raw layer preserves source files as landed. No business logic is applied here.

```text
raw_distributor_a_sales
raw_distributor_b_sales
raw_distributor_c_sales
raw_customer_master
raw_product_master
raw_inventory
```

This provides traceability back to source and avoids overwriting source-system behaviour.

### 2. Staging layer

PostgreSQL views standardise schemas and resolve data-quality issues.

Typical transformations include:

- date parsing
- currency-string cleaning
- whitespace removal
- upper/lower-case standardisation
- malformed key repair
- province/channel standardisation
- duplicate removal
- invalid/null record filtering

The three distributor schemas are unioned into a common `stg_sales` structure.

### 3. Analytics layer

The curated dimensional model contains:

```text
dim_date
dim_customer
dim_product
fact_sales
fact_inventory
```

Surrogate integer keys are used in the dimensions. Business keys remain available for audit and traceability.

### 4. Semantic layer

Power BI consumes only the curated analytics layer.

Relationships are one-to-many, single-direction, from dimension to fact. `fact_sales` and `fact_inventory` are not directly related.

### 5. Presentation layer

Four report pages are designed around decisions rather than data sources:

1. Executive Overview
2. Sales & Growth
3. Customer Performance
4. Inventory & Supply

## Design Principles

- Keep raw data immutable.
- Perform reusable transformation logic upstream in SQL.
- Use conformed dimensions where facts share business entities.
- Avoid fact-to-fact relationships.
- Treat inventory snapshots as semi-additive.
- Use DAX for analytical context, not for avoidable data cleaning.
- Separate KPI reporting from business interpretation.
