#!/usr/bin/env bash
set -euo pipefail

# PGHOST, PGPORT, PGUSER and PGPASSWORD are supplied by CI/local operator.
# Each scenario gets an isolated database, not a shared production schema.
base() {
  local db="$1"
  psql -X -v ON_ERROR_STOP=1 -d postgres -c "CREATE DATABASE $db" >/dev/null
  psql -X -v ON_ERROR_STOP=1 -d "$db" -f tests/fixtures.sql >/dev/null
  psql -X -v ON_ERROR_STOP=1 -d "$db" -f sql/01_staging_layer.sql >/dev/null
  psql -X -v ON_ERROR_STOP=1 -d "$db" -f sql/02_dimensions.sql >/dev/null
}

expect_failure() {
  local db="$1" script="$2" expected="$3" output
  output="$(mktemp)"
  if psql -X -v ON_ERROR_STOP=1 -d "$db" -f "$script" >"$output" 2>&1; then
    echo "ERROR: expected failure, but $script succeeded in $db"
    cat "$output"; rm -f "$output"; exit 1
  fi
  if ! grep -Fq "$expected" "$output"; then
    echo "ERROR: unexpected failure in $db; expected: $expected"
    cat "$output"; rm -f "$output"; exit 1
  fi
  rm -f "$output"
  echo "PASS: $db blocked as expected ($expected)"
}

base quality_happy
psql -X -v ON_ERROR_STOP=1 -d quality_happy -f sql/03_fact_tables.sql >/dev/null
psql -X -v ON_ERROR_STOP=1 -d quality_happy -f sql/04_reconciliation_checks.sql >/dev/null
psql -X -v ON_ERROR_STOP=1 -d quality_happy -f sql/05_assert_reconciliation.sql >/dev/null
psql -X -v ON_ERROR_STOP=1 -d quality_happy -f tests/assert_happy_path.sql >/dev/null
echo 'PASS: valid sales, credit notes, repeated lines and source-gap reporting'

base quality_orphan
psql -X -v ON_ERROR_STOP=1 -d quality_orphan -c   "INSERT INTO raw_distributor_a_sales VALUES ('ORPHAN-1', '2025-09-15', 'MISSING', 'SKU1', 1, 10)" >/dev/null
expect_failure quality_orphan sql/03_fact_tables.sql 'unmapped sales date/customer/product'

base quality_invalid_inventory
psql -X -v ON_ERROR_STOP=1 -d quality_invalid_inventory -c   "UPDATE raw_inventory SET closing_stock_cases = -1 WHERE distributor_code = 'DISTA'" >/dev/null
expect_failure quality_invalid_inventory sql/03_fact_tables.sql 'invalid inventory quantity'

base quality_duplicate_inventory
psql -X -v ON_ERROR_STOP=1 -d quality_duplicate_inventory -c \
  "INSERT INTO raw_inventory SELECT * FROM raw_inventory WHERE distributor_code = 'DISTA'" >/dev/null
expect_failure quality_duplicate_inventory sql/03_fact_tables.sql 'duplicate inventory snapshot grain'

psql -X -v ON_ERROR_STOP=1 -d quality_happy -c   'UPDATE fact_sales SET net_sales_zar = net_sales_zar + 1 WHERE sales_id = 1' >/dev/null
expect_failure quality_happy sql/05_assert_reconciliation.sql 'staged sales do not balance to fact_sales'
echo 'PASS: all PostgreSQL data integrity regression scenarios'
