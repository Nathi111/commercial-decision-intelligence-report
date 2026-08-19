# Core DAX Measures

This file documents selected measures used in the Power BI semantic model.

## Base measures

```DAX
Total Sales ZAR =
SUM ( fact_sales[net_sales_zar] )
```

```DAX
Total Cases =
SUM ( fact_sales[quantity_cases] )
```

```DAX
Average Sales per Case =
DIVIDE ( [Total Sales ZAR], [Total Cases] )
```

## Current fiscal year

```DAX
Latest Sales Date =
CALCULATE (
    MAX ( fact_sales[date] ),
    REMOVEFILTERS ( dim_date )
)
```

```DAX
Current FY Sales =
VAR LatestDate = [Latest Sales Date]
VAR FYStart =
    IF (
        MONTH ( LatestDate ) >= 4,
        DATE ( YEAR ( LatestDate ), 4, 1 ),
        DATE ( YEAR ( LatestDate ) - 1, 4, 1 )
    )
RETURN
    CALCULATE (
        [Total Sales ZAR],
        DATESBETWEEN ( dim_date[date], FYStart, LatestDate )
    )
```

```DAX
Prior FY Sales =
VAR LatestDate = [Latest Sales Date]
VAR CurrentFYStart =
    IF (
        MONTH ( LatestDate ) >= 4,
        DATE ( YEAR ( LatestDate ), 4, 1 ),
        DATE ( YEAR ( LatestDate ) - 1, 4, 1 )
    )
VAR PriorFYStart = EDATE ( CurrentFYStart, -12 )
VAR PriorPeriodEnd = EDATE ( LatestDate, -12 )
RETURN
    CALCULATE (
        [Total Sales ZAR],
        DATESBETWEEN ( dim_date[date], PriorFYStart, PriorPeriodEnd )
    )
```

```DAX
Sales FY Growth % =
DIVIDE (
    [Current FY Sales] - [Prior FY Sales],
    [Prior FY Sales]
)
```

```DAX
Current FY Cases =
VAR LatestDate = [Latest Sales Date]
VAR FYStart =
    IF (
        MONTH ( LatestDate ) >= 4,
        DATE ( YEAR ( LatestDate ), 4, 1 ),
        DATE ( YEAR ( LatestDate ) - 1, 4, 1 )
    )
RETURN
    CALCULATE (
        [Total Cases],
        DATESBETWEEN ( dim_date[date], FYStart, LatestDate )
    )
```

```DAX
Prior FY Cases =
VAR LatestDate = [Latest Sales Date]
VAR CurrentFYStart =
    IF (
        MONTH ( LatestDate ) >= 4,
        DATE ( YEAR ( LatestDate ), 4, 1 ),
        DATE ( YEAR ( LatestDate ) - 1, 4, 1 )
    )
VAR PriorFYStart = EDATE ( CurrentFYStart, -12 )
VAR PriorPeriodEnd = EDATE ( LatestDate, -12 )
RETURN
    CALCULATE (
        [Total Cases],
        DATESBETWEEN ( dim_date[date], PriorFYStart, PriorPeriodEnd )
    )
```

```DAX
Cases FY Growth % =
DIVIDE (
    [Current FY Cases] - [Prior FY Cases],
    [Prior FY Cases]
)
```

## Value per case

```DAX
Current FY Value per Case =
DIVIDE ( [Current FY Sales], [Current FY Cases] )
```

```DAX
Prior FY Value per Case =
DIVIDE ( [Prior FY Sales], [Prior FY Cases] )
```

```DAX
Value per Case Growth % =
DIVIDE (
    [Current FY Value per Case] - [Prior FY Value per Case],
    [Prior FY Value per Case]
)
```

## Customer concentration

```DAX
Customer Sales Contribution % =
DIVIDE (
    [Customer Current FY Sales],
    CALCULATE (
        [Current FY Sales],
        REMOVEFILTERS ( dim_customer )
    )
)
```

```DAX
Customer Sales Rank =
RANKX (
    ALL ( dim_customer ),
    [Customer Current FY Sales],
    ,
    DESC,
    DENSE
)
```

```DAX
Top 5 Customer Sales =
VAR TopCustomers =
    TOPN (
        5,
        ALL ( dim_customer ),
        [Current FY Sales],
        DESC
    )
RETURN
    CALCULATE (
        [Current FY Sales],
        KEEPFILTERS ( TopCustomers )
    )
```

```DAX
Top 5 Customer Contribution % =
DIVIDE ( [Top 5 Customer Sales], [Current FY Sales] )
```

```DAX
Customer Cumulative Sales % =
VAR CurrentCustomerSales = [Customer Current FY Sales]
VAR CumulativeSales =
    CALCULATE (
        [Customer Current FY Sales],
        FILTER (
            ALLSELECTED ( dim_customer[customer_name] ),
            [Customer Current FY Sales] >= CurrentCustomerSales
        )
    )
VAR TotalSelectedSales =
    CALCULATE (
        [Customer Current FY Sales],
        ALLSELECTED ( dim_customer[customer_name] )
    )
RETURN
    DIVIDE ( CumulativeSales, TotalSelectedSales )
```

## Inventory snapshot logic

```DAX
Latest Inventory Date =
CALCULATE (
    MAX ( fact_inventory[date] ),
    REMOVEFILTERS ( dim_date )
)
```

```DAX
Latest Closing Stock =
VAR LatestDate = [Latest Inventory Date]
RETURN
    CALCULATE (
        SUM ( fact_inventory[closing_stock_cases] ),
        FILTER (
            ALL ( dim_date[date] ),
            dim_date[date] = LatestDate
        )
    )
```

```DAX
Latest Depletions =
VAR LatestDate = [Latest Inventory Date]
RETURN
    CALCULATE (
        SUM ( fact_inventory[depletions_cases] ),
        FILTER (
            ALL ( dim_date[date] ),
            dim_date[date] = LatestDate
        )
    )
```

```DAX
Latest Stock Cover Months =
DIVIDE ( [Latest Closing Stock], [Latest Depletions] )
```

```DAX
Stock Health =
VAR Cover = [Latest Stock Cover Months]
RETURN
    SWITCH (
        TRUE (),
        ISBLANK ( Cover ), "No Data",
        Cover < 3, "Low Stock",
        Cover <= 6, "Healthy",
        "Excess Stock"
    )
```

```DAX
Excess Stock Cases =
VAR Cover = [Latest Stock Cover Months]
VAR MonthlyDepletions = [Latest Depletions]
VAR MaximumHealthyStock = MonthlyDepletions * 6
RETURN
    IF (
        Cover > 6,
        MAX ( 0, [Latest Closing Stock] - MaximumHealthyStock ),
        0
    )
```

## Executive insight examples

```DAX
Executive Sales Insight =
"Revenue grew "
    & FORMAT ( [Sales FY Growth %], "0.0%" )
    & " YoY despite broadly flat case volumes, indicating value-led growth."
```

```DAX
Executive Inventory Insight =
"Stock cover is "
    & FORMAT ( [Latest Stock Cover Months], "0.0" )
    & " months vs the 3-6 month target, with "
    & FORMAT ( [Excess Stock Cases], "#,##0" )
    & " excess cases."
```
