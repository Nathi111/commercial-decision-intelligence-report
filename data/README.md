# Data

This project uses **synthetic portfolio data only**.

## Source files

The raw dataset simulates a commercial analytics environment with:

- three distributor sales files using different schemas
- customer master data
- product master data
- monthly inventory snapshots
- two fiscal years of sales history for YoY analysis

## Intentional data-quality issues

The source files include realistic problems that are resolved in SQL staging:

- inconsistent column names across distributors
- multiple date formats
- currency strings and thousands separators
- mixed upper/lower case business keys
- leading/trailing whitespace
- duplicate rows
- missing values
- malformed product/customer codes
- negative or zero values
- inconsistent province/channel naming

## Privacy

No real employer, customer, distributor or transactional data is included in this repository.

The raw CSV files are not committed here by default because the focus of the portfolio is the transformation and analytics design. They can be regenerated or shared separately if required.
