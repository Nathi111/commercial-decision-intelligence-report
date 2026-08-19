# Business Findings

This section summarises the analytical story produced by the synthetic portfolio dataset.

## 1. Revenue growth is value-led

FY2026 sales reached approximately **R49.23M**, up **8.7% YoY**, while case volumes remained broadly flat.

This indicates that the improvement came from higher value generated per case rather than additional physical volume. The report does not assume this is pure pricing; the result could reflect price, brand mix, channel mix, customer mix or a combination of those effects.

## 2. Sales are seasonal

Monthly sales show a pronounced year-end acceleration, peaking around the festive period before declining sharply in January/February and beginning to recover in March.

**Implication:** replenishment and inventory deployment should account for seasonal demand rather than using a flat monthly run rate.

## 3. Brand revenue is moderately concentrated

Vela is the largest brand at roughly **24% of FY sales**. The top three brands collectively contribute approximately **68%** of portfolio revenue.

This makes brand mix an important driver of total commercial performance.

## 4. Customer concentration risk is low

The dataset contains **250 active customers**, while the top five customers account for only about **3% of FY revenue**.

**Implication:** the revenue base is diversified and is not heavily dependent on a small number of key accounts.

## 5. Retail is the largest route to market

Retail is the highest-value channel at roughly **R18M** of FY sales, representing more than one-third of revenue.

A small amount of revenue remains classified as `Unknown`, highlighting an upstream customer-master data-quality opportunity.

## 6. Gauteng is the core geographic market

Gauteng contributes approximately **R18.7M**, or around **38% of FY revenue**, materially ahead of the other provinces represented in the model.

## 7. Inventory is the primary operational opportunity

The portfolio closes with approximately **7.5 months of stock cover**, above the defined healthy range of **3-6 months**.

The latest snapshot identifies:

- **13 excess-stock SKUs**
- **7 healthy SKUs**
- **0 low-stock SKUs**
- approximately **5,349 excess cases** above the healthy-stock ceiling
- **0 stock-shortfall cases**

The inventory problem is therefore excess working capital rather than immediate supply risk.

## 8. Inventory deployment is not fully aligned with sales contribution

Golden Reef carries the highest brand-level stock cover at roughly **10 months** while contributing less than one-fifth of FY sales. Higher-contributing brands such as Ember & Oak operate closer to the healthy stock range.

## Recommendation

Protect the value-led growth trajectory while releasing working capital through targeted stock rebalancing.

Priority actions:

1. Review SKUs with more than six months of cover.
2. Reduce or rebalance excess inventory rather than applying broad stock cuts.
3. Protect replenishment for high-performing SKUs that sit within the healthy 3-6 month range.
4. Incorporate the seasonal demand profile into future inventory planning.
5. Improve customer-master completeness for records assigned to the `Unknown` channel.

## Synthetic-data caveat

The prior-year synthetic sales values were generated at an approximately uniform discount to the following year. This intentionally creates a uniform YoY growth pattern at some lower levels such as brand. Those rates are therefore not presented as genuine brand-specific performance differences.
