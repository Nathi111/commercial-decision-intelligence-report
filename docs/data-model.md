# Data Model

## Star-schema design

The Power BI model contains two fact tables sharing conformed date and product dimensions.

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

## Tables

### `dim_date`

Fiscal calendar with an April-March financial year.

Important attributes:

- `date`
- `calendar_year`
- `calendar_month_number`
- `calendar_month`
- `fiscal_year`
- `fiscal_month_number`
- `fiscal_quarter`
- `fiscal_year_label`
- `year_month`

### `dim_customer`

Customer/outlet master used to analyse channel, geography, concentration and account performance.

Important attributes:

- `customer_id` surrogate key
- `customer_code` business key
- `customer_name`
- `channel`
- `city`
- `province`
- `region`
- `distributor_code`

### `dim_product`

Product/SKU master.

Important attributes:

- `product_id` surrogate key
- `product_code` business key
- `brand`
- `product_name`
- `category`
- `size_ml`
- `pack_size`

### `fact_sales`

**Grain:** one transaction/product line.

Measures include sales value, cases and derived value per case.

### `fact_inventory`

**Grain:** one product x distributor x month-end snapshot.

Contains opening stock, arrivals, depletions and closing stock.

## Relationship Rules

- One-to-many from dimensions to facts
- Single cross-filter direction
- Active relationships only
- No direct `fact_sales` to `fact_inventory` relationship
- Customer filters sales only because inventory is not recorded at customer grain

## Semi-additive Inventory

Closing stock cannot be summed across time. For KPI cards and current-position analysis, DAX first resolves the latest inventory date and then aggregates closing stock at that snapshot.

For time-series visuals where month is explicitly present on the axis, monthly closing stock can be aggregated within each month because the filter context isolates the snapshot period.

## Fiscal Calendar

The financial year starts on 1 April:

```text
April     = Fiscal Month 1
May       = Fiscal Month 2
...
March     = Fiscal Month 12
```

A date in April 2025 belongs to FY2026.
