# Databricks Metric Views Skill

## Quick Start Guide

### What This Skill Covers
Creating and managing Databricks metric views - semantic layers that transform raw tables into standardized business metrics. Use this when working with metric view YAML definitions or SQL DDL.

### When to Use This Skill
- Creating new metric views with YAML definitions
- Defining measures, dimensions, joins, and filters
- Adding semantic metadata (display names, formats, synonyms)
- Working with window measures or composable metrics
- Managing metric views via SQL (CREATE, ALTER, DROP)

### Prerequisites Checklist
- SELECT privileges on source data
- CREATE TABLE and USE SCHEMA privileges
- USE CATALOG privilege
- Databricks Runtime 17.2+ (for semantic metadata)
- SQL warehouse or compute resource access

---

## Core Concepts

### Metric View Components
Every metric view consists of:

1. **Source**: Base table, view, or SQL query
2. **Dimensions**: Attributes for segmenting (used in SELECT, WHERE, GROUP BY)
3. **Measures**: Aggregations that produce metrics (must use aggregate functions)
4. **Filters**: Persistent WHERE conditions applied to all queries

### Quick Example
```yaml
version: 1.1
source: samples.tpch.orders

dimensions:
  - name: Order Month
    expr: DATE_TRUNC('MONTH', o_orderdate)

measures:
  - name: Order Count
    expr: COUNT(1)
  - name: Total Revenue
    expr: SUM(o_totalprice)
```

---

## Creating Metric Views

### SQL DDL Syntax
```sql
CREATE OR REPLACE VIEW view_name
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: catalog.schema.table
  # ... YAML definition
$$
```

### YAML Structure

#### Version Header
```yaml
version: 1.1  # Required; use 1.1 for semantic metadata support
comment: "Optional description"
```

#### Source Options

**Option 1: Table**
```yaml
source: samples.tpch.orders
```

**Option 2: SQL Query**
```yaml
source: SELECT * FROM samples.tpch.orders o
  LEFT JOIN samples.tpch.customer c
  ON o.o_custkey = c.c_custkey
```

**Option 3: Another Metric View**
```yaml
source: views.examples.source_metric_view
```

#### Filters
```yaml
# Single condition
filter: o_orderdate > '2024-01-01'

# Multiple conditions
filter: o_orderdate > '2024-01-01' AND o_orderstatus = 'F'

# Complex conditions
filter: o_orderstatus IN ('F', 'P') AND o_totalprice > 1000.00
```

---

## Dimensions

### Basic Structure
```yaml
dimensions:
  - name: dimension_name
    expr: column_or_expression
    comment: "Optional description"
    display_name: "Display Name"  # v1.1+
    synonyms:  # v1.1+
      - "synonym1"
      - "synonym2"
    format:  # v1.1+ (for date dimensions)
      type: date
      date_format: year_month_day
```

### Common Patterns
```yaml
dimensions:
  # Direct column reference
  - name: order_date
    expr: o_orderdate

  # Date truncation
  - name: order_month
    expr: DATE_TRUNC('MONTH', o_orderdate)

  # CASE expression
  - name: order_status_label
    expr: CASE
      WHEN o_orderstatus = 'O' THEN 'Open'
      WHEN o_orderstatus = 'F' THEN 'Fulfilled'
      END

  # String manipulation
  - name: priority_number
    expr: SPLIT(o_orderpriority, '-')[1]

  # Composable - references another dimension
  - name: order_year
    expr: DATE_TRUNC('year', order_date)
```

---

## Measures

### Basic Structure
```yaml
measures:
  - name: measure_name
    expr: AGGREGATE_FUNCTION(column)
    comment: "Optional description"
    display_name: "Display Name"  # v1.1+
    synonyms:  # v1.1+
      - "synonym1"
    format:  # v1.1+
      type: currency
      currency_code: USD
```

### Common Patterns

#### Simple Aggregations
```yaml
measures:
  # Count
  - name: order_count
    expr: COUNT(1)

  # Sum
  - name: total_revenue
    expr: SUM(o_totalprice)

  # Distinct count
  - name: unique_customers
    expr: COUNT(DISTINCT o_custkey)

  # Average
  - name: avg_price
    expr: AVG(o_totalprice)
```

#### Filtered Measures
```yaml
measures:
  # FILTER clause
  - name: urgent_order_revenue
    expr: SUM(o_totalprice) FILTER (WHERE o_orderpriority = '1-URGENT')
```

#### Calculated Measures
```yaml
measures:
  # Direct calculation
  - name: avg_order_value
    expr: SUM(o_totalprice) / COUNT(DISTINCT o_orderkey)

  # Using dimension
  - name: avg_monthly_revenue
    expr: SUM(o_totalprice) / COUNT(DISTINCT DATE_TRUNC('MONTH', o_orderdate))
```

---

## Composability (MEASURE Function)

### Why Use Composability
- Reuse existing measures in new calculations
- Maintain consistency across derived metrics
- Simplify complex metric definitions
- Changes to base measures propagate automatically

### Syntax
Use `MEASURE(measure_name)` to reference other measures.

### Examples

#### Basic Composition
```yaml
measures:
  # Atomic measures
  - name: total_revenue
    expr: SUM(o_totalprice)

  - name: order_count
    expr: COUNT(1)

  # Composed measure
  - name: avg_order_value
    expr: MEASURE(total_revenue) / MEASURE(order_count)
```

#### With Conditional Logic
```yaml
measures:
  # Base measures
  - name: total_orders
    expr: COUNT(1)

  - name: fulfilled_orders
    expr: COUNT(1) FILTER (WHERE o_orderstatus = 'F')

  # Ratio
  - name: fulfillment_rate
    expr: MEASURE(fulfilled_orders) / MEASURE(total_orders)
    format:
      type: percentage
```

#### Multi-Level Composition
```yaml
measures:
  - name: gross_revenue
    expr: SUM(o_totalprice)

  - name: returns
    expr: SUM(o_totalprice) FILTER (WHERE o_orderstatus = 'R')

  - name: net_revenue
    expr: MEASURE(gross_revenue) - MEASURE(returns)

  - name: return_rate
    expr: MEASURE(returns) / MEASURE(gross_revenue)
```

### Best Practices
1. Define atomic measures first
2. Always use MEASURE() function (don't repeat aggregation logic)
3. Name measures clearly to show relationships
4. Add comments explaining complex compositions

---

## Joins

### Star Schema (Basic Joins)

#### Using ON Clause
```yaml
source: catalog.schema.fact_table

joins:
  - name: dimension_table_1
    source: catalog.schema.dimension_table_1
    on: source.dim_fk = dimension_table_1.pk

dimensions:
  - name: dim_key
    expr: dimension_table_1.pk
```

#### Using USING Clause
```yaml
joins:
  - name: dimension_table_2
    source: catalog.schema.dimension_table_2
    using:
      - key_column_a
      - key_column_b
```

**Important Notes:**
- Use `source` to reference the metric view's source table
- Use the join `name` to reference joined table columns
- Quote special keys: `'on': source.fk = dim.pk` (avoid YAML parser issues)
- Joins must be LEFT OUTER JOIN (many-to-one)
- Joined tables cannot include MAP type columns

### Snowflake Schema (Nested Joins)
```yaml
source: samples.tpch.orders

joins:
  - name: customer
    source: samples.tpch.customer
    on: source.o_custkey = customer.c_custkey
    joins:
      - name: nation
        source: samples.tpch.nation
        on: customer.c_nationkey = nation.n_nationkey
        joins:
          - name: region
            source: samples.tpch.region
            on: nation.n_regionkey = region.r_regionkey

dimensions:
  - name: customer_name
    expr: customer.c_name
  - name: nation_name
    expr: customer.nation.n_name
  - name: region_name
    expr: customer.nation.region.r_name
```

**Requirements:**
- Databricks Runtime 17.1+
- Set primary/foreign key constraints with RELY option for optimal performance

---

## Window Measures (Experimental)

### Structure
```yaml
measures:
  - name: measure_name
    expr: AGGREGATE_FUNCTION(column)
    window:
      - order: dimension_name
        range: range_specification
        semiadditive: first|last
```

### Range Options

| Range | Description | Example |
|-------|-------------|---------|
| `current` | Current row only | `range: current` |
| `cumulative` | All rows up to current | `range: cumulative` |
| `trailing N unit` | N units backward (excludes current) | `range: trailing 7 day` |
| `leading N unit` | N units forward | `range: leading 7 day` |
| `all` | All rows | `range: all` |

### Common Patterns

#### Trailing Window (7-day)
```yaml
measures:
  - name: t7d_customers
    expr: COUNT(DISTINCT o_custkey)
    window:
      - order: date
        range: trailing 7 day
        semiadditive: last
```

#### Running Total
```yaml
measures:
  - name: running_total_sales
    expr: SUM(o_totalprice)
    window:
      - order: date
        range: cumulative
        semiadditive: last
```

#### Period-over-Period
```yaml
measures:
  - name: previous_day_sales
    expr: SUM(o_totalprice)
    window:
      - order: date
        range: trailing 1 day
        semiadditive: last

  - name: current_day_sales
    expr: SUM(o_totalprice)
    window:
      - order: date
        range: current
        semiadditive: last

  - name: day_over_day_growth
    expr: (MEASURE(current_day_sales) - MEASURE(previous_day_sales)) / MEASURE(previous_day_sales) * 100
```

#### Year-to-Date
```yaml
dimensions:
  - name: date
    expr: o_orderdate
  - name: year
    expr: DATE_TRUNC('year', o_orderdate)

measures:
  - name: ytd_sales
    expr: SUM(o_totalprice)
    window:
      - order: date
        range: cumulative
        semiadditive: last
      - order: year
        range: current
        semiadditive: last
```

#### Semiadditive (Bank Balance Example)
```yaml
measures:
  - name: account_balance
    expr: SUM(balance)
    window:
      - order: date
        range: current
        semiadditive: last
```

---

## Semantic Metadata (v1.1+)

### Requirements
- Databricks Runtime 17.2+
- YAML version 1.1
- Preview enrollment (check on Previews page)

### Display Names
```yaml
dimensions:
  - name: order_date
    display_name: 'Order Date'  # Max 255 chars

measures:
  - name: total_revenue
    display_name: 'Total Revenue'
```

### Synonyms
```yaml
dimensions:
  - name: order_date
    synonyms:  # Max 10 synonyms, 255 chars each
      - 'order time'
      - 'date of order'

measures:
  - name: total_revenue
    synonyms: ['revenue', 'total sales', 'sales amount']
```

### Format Specifications

#### Number Format
```yaml
format:
  type: number
  decimal_places:
    type: max|exact|all
    places: 2  # 0-10, required for max/exact
  hide_group_separator: true|false
  abbreviation: none|compact|scientific
```

#### Currency Format
```yaml
format:
  type: currency
  currency_code: USD  # ISO-4217 code
  decimal_places:
    type: exact
    places: 2
  hide_group_separator: false
  abbreviation: compact
```

#### Percentage Format
```yaml
format:
  type: percentage
  decimal_places:
    type: all
  hide_group_separator: true
```

#### Date Format
```yaml
format:
  type: date
  date_format: locale_short_month|locale_long_month|year_month_day|locale_number_month|year_week
  leading_zeros: true|false
```

#### DateTime Format
```yaml
format:
  type: date_time
  date_format: no_date|locale_short_month|locale_long_month|year_month_day|locale_number_month|year_week
  time_format: no_time|locale_hour_minute|locale_hour_minute_second
  leading_zeros: true|false
```

**Note:** At least one of date_format or time_format must be specified (not no_date/no_time).

---

## SQL Management Commands

### Create
```sql
CREATE OR REPLACE VIEW orders_metric_view
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: samples.tpch.orders
  dimensions:
    - name: order_date
      expr: o_orderdate
  measures:
    - name: order_count
      expr: COUNT(1)
$$
```

### Alter
```sql
ALTER VIEW orders_metric_view
AS $$
  version: 1.1
  source: samples.tpch.orders
  # Updated YAML definition
$$
```

### Describe
```sql
-- Human-readable format
DESCRIBE TABLE EXTENDED orders_metric_view

-- JSON format (machine-readable)
DESCRIBE TABLE EXTENDED orders_metric_view AS JSON
```

### Grant Privileges
```sql
GRANT SELECT ON orders_metric_view TO `data-consumers`;
```

### Drop
```sql
DROP VIEW orders_metric_view;
```

---

## Complete Reference Example

```yaml
version: 1.1
comment: "Comprehensive sales metrics with semantic metadata"
source: samples.tpch.orders
filter: o_orderdate > '1990-01-01'

joins:
  - name: customer
    source: samples.tpch.customer
    on: source.o_custkey = customer.c_custkey

dimensions:
  - name: order_date
    expr: o_orderdate
    comment: "Date when the order was placed"
    display_name: 'Order Date'
    format:
      type: date
      date_format: year_month_day
      leading_zeros: true
    synonyms:
      - 'order time'
      - 'date of order'

  - name: order_month
    expr: DATE_TRUNC('MONTH', o_orderdate)
    display_name: 'Order Month'

  - name: order_status
    expr: CASE
      WHEN o_orderstatus = 'O' THEN 'Open'
      WHEN o_orderstatus = 'P' THEN 'Processing'
      WHEN o_orderstatus = 'F' THEN 'Fulfilled'
      END
    display_name: 'Order Status'

  - name: customer_name
    expr: customer.c_name
    display_name: 'Customer Name'

measures:
  - name: order_count
    expr: COUNT(1)
    comment: "Total number of orders"
    display_name: 'Order Count'
    format:
      type: number
      decimal_places:
        type: all
      hide_group_separator: true
    synonyms:
      - 'count'
      - 'number of orders'

  - name: total_revenue
    expr: SUM(o_totalprice)
    comment: "Total revenue from all orders"
    display_name: 'Total Revenue'
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
      abbreviation: compact
    synonyms:
      - 'revenue'
      - 'total sales'

  - name: avg_order_value
    expr: MEASURE(total_revenue) / MEASURE(order_count)
    comment: "Average revenue per order"
    display_name: 'Average Order Value'
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2

  - name: urgent_order_revenue
    expr: SUM(o_totalprice) FILTER (WHERE o_orderpriority = '1-URGENT')
    display_name: 'Urgent Order Revenue'
    format:
      type: currency
      currency_code: USD

  - name: running_total_revenue
    expr: SUM(o_totalprice)
    window:
      - order: order_date
        range: cumulative
        semiadditive: last
```

---

## Quick Reference: Common Tasks

### Task 1: Create Simple Metric View
```sql
CREATE VIEW my_metrics WITH METRICS LANGUAGE YAML AS $$
version: 1.1
source: my_catalog.my_schema.my_table
dimensions:
  - name: date_col
    expr: my_date
measures:
  - name: count_metric
    expr: COUNT(1)
$$
```

### Task 2: Add Filtered Measure
```yaml
measures:
  - name: high_value_orders
    expr: COUNT(1) FILTER (WHERE amount > 1000)
```

### Task 3: Create Ratio Metric
```yaml
measures:
  - name: numerator
    expr: SUM(col_a)
  - name: denominator
    expr: SUM(col_b)
  - name: ratio
    expr: MEASURE(numerator) / MEASURE(denominator)
```

### Task 4: Add Display Formatting
```yaml
measures:
  - name: revenue
    expr: SUM(price)
    display_name: 'Total Revenue'
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
```

### Task 5: Join Dimension Table
```yaml
joins:
  - name: dim_table
    source: catalog.schema.dim_table
    on: source.fk_id = dim_table.pk_id
dimensions:
  - name: dim_attribute
    expr: dim_table.attribute_name
```

---

## Troubleshooting

### Common Issues

**YAML Parser Errors with Special Keys**
- Problem: Keys like `on`, `off`, `yes`, `no` interpreted as booleans
- Solution: Wrap in quotes: `'on': source.fk = dim.pk`

**Measure Reference Errors**
- Problem: Trying to use measure without MEASURE() function
- Solution: Always use `MEASURE(measure_name)` syntax

**Semantic Metadata Not Working**
- Problem: Version 1.0 doesn't support display_name, format, synonyms
- Solution: Update to `version: 1.1`

**Window Measure Not Available**
- Problem: Using window measures on older runtime
- Solution: Requires Databricks Runtime 17.1+ for window measures

**Comments Removed from YAML**
- Problem: Single-line comments (#) disappear after save
- Solution: This is expected in v1.1; use `comment:` fields instead

---

## Best Practices

1. **Start Simple**: Begin with basic dimensions and measures, add complexity incrementally
2. **Use Composability**: Define atomic measures first, build complex ones with MEASURE()
3. **Add Metadata**: Include comments, display_names, and formats for better tool integration
4. **Consistent Naming**: Use clear, descriptive names (snake_case for YAML, display names for UI)
5. **Version Control**: Always specify `version: 1.1` for new metric views
6. **Test Incrementally**: Create view, test with simple queries, then add more features
7. **Document Intent**: Use comment fields to explain business logic
8. **Leverage Filters**: Apply common filters at metric view level, not in every query
9. **Optimize Joins**: Set PK/FK constraints with RELY for best performance
10. **Grant Minimal Privileges**: Only SELECT needed for consumers

---

## Additional Notes

- Single-line comments (#) in YAML are removed when saved in v1.1
- Metric views follow Unity Catalog permission model
- Use `MEASURE()` function when querying: `SELECT MEASURE(total_revenue) FROM view`
- Window measures are experimental; syntax may change
- MAP type columns not supported in joined tables
- Snowflake schemas require Databricks Runtime 17.1+