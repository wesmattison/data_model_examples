# Schema Documentation Guide for Metric View Development

## Recommended File Format: YAML

### Why YAML?
1. **Hierarchical structure** - Natural for table → column relationships
2. **Comments supported** - Can include metadata inline
3. **Easy to parse** - Both humans and LLMs can read it efficiently
4. **Type-safe** - Clear data structures
5. **Single file per table** - Easier to manage than one giant CSV

## File Structure

### Directory Layout
```
/schema_docs/
├── facts/
│   ├── fact_orders.yaml
│   ├── fact_line_items.yaml
│   └── fact_transactions.yaml
├── dimensions/
│   ├── dim_customer.yaml
│   ├── dim_product.yaml
│   └── dim_date.yaml
└── README.md (explains conventions)
```

## Table Schema Template

```yaml
# Table Metadata
table:
  name: catalog.schema.fact_orders
  type: fact|dimension|bridge|junk  # Required
  description: "Business description of what this table represents"
  grain: "Order header level - one row per order"  # For facts
  source_system: "SAP ERP"
  refresh_frequency: "daily"
  primary_key: [order_id]  # List of columns
  
  # Recommended dimension joins (for facts)
  recommended_joins:
    - dim_table: dim_customer
      join_type: inner
      on_clause: fact_orders.customer_key = dim_customer.customer_key
      relationship: many_to_one
      
    - dim_table: dim_date
      join_type: inner
      on_clause: fact_orders.order_date_key = dim_date.date_key
      relationship: many_to_one

  # Known issues or warnings
  data_quality_notes:
    - "Order dates before 2020 may be incomplete"
    - "Null customer_key indicates guest checkout"

# Column Definitions
columns:
  - name: order_id
    data_type: BIGINT
    
    # Metric View Exposure Settings
    exposure:
      include_in_metric_view: false  # True/False
      usage_category: surrogate_key|natural_key|measure_candidate|dimension_candidate|internal_only
      reason: "Surrogate key - use for joins only, not for analysis"
    
    # Genie/LLM Metadata
    genie:
      description: "Unique identifier for each order (system-generated)"
      synonyms: ["order number", "order #"]
      confidence_score: 0.95  # 0.0-1.0 scale
      needs_review: false
      review_notes: ""
    
    # Technical Metadata
    constraints:
      nullable: false
      unique: true
      foreign_key: null
    
    # Sample values (helps LLM understand the data)
    sample_values: [1001, 1002, 1003]
    
  - name: customer_key
    data_type: INTEGER
    
    exposure:
      include_in_metric_view: false
      usage_category: surrogate_key
      reason: "FK to dim_customer - use dim_customer attributes in metric view"
    
    genie:
      description: "Foreign key to customer dimension table"
      confidence_score: 1.0
      needs_review: false
    
    constraints:
      nullable: true  # Null for guest checkout
      foreign_key: dim_customer.customer_key
    
  - name: customer_natural_id
    data_type: STRING
    
    exposure:
      include_in_metric_view: true
      usage_category: natural_key
      reason: "Natural business key - useful for analysis and filtering"
    
    genie:
      description: "Customer account number from source system (e.g., 'CUST-12345')"
      synonyms: ["customer number", "account number", "customer ID"]
      confidence_score: 0.98
      needs_review: false
    
    sample_values: ["CUST-12345", "CUST-67890", "GUEST"]
    
  - name: order_date
    data_type: DATE
    
    exposure:
      include_in_metric_view: true
      usage_category: dimension_candidate
      reason: "Primary time dimension - essential for temporal analysis"
    
    genie:
      description: "Date when the order was placed by the customer"
      synonyms: ["order date", "purchase date", "transaction date"]
      confidence_score: 1.0
      needs_review: false
    
    constraints:
      nullable: false
    
    sample_values: ["2024-01-15", "2024-01-16", "2024-01-17"]
    
  - name: order_total_amount
    data_type: DECIMAL(18,2)
    
    exposure:
      include_in_metric_view: true
      usage_category: measure_candidate
      reason: "Core business metric - total order value"
    
    genie:
      description: "Total dollar amount of the order including tax and shipping"
      synonyms: ["order total", "order value", "total amount", "revenue"]
      confidence_score: 0.99
      needs_review: false
    
    # Measure suggestions
    suggested_measures:
      - name: "Total Revenue"
        expr: "SUM(order_total_amount)"
        
      - name: "Average Order Value"
        expr: "AVG(order_total_amount)"
        
      - name: "Max Order Value"
        expr: "MAX(order_total_amount)"
    
    sample_values: [125.50, 89.99, 1245.00]
    
  - name: obscure_flag_xyz
    data_type: STRING
    
    exposure:
      include_in_metric_view: false
      usage_category: internal_only
      reason: "Purpose unclear - exclude until business meaning is confirmed"
    
    genie:
      description: "UNKNOWN: Purpose and meaning unclear from field name"
      confidence_score: 0.15  # Very low confidence
      needs_review: true
      review_notes: "Field name does not indicate purpose. Common values: Y, N, NULL. Need SME input."
    
    sample_values: ["Y", "N", null]
    
    # Reverse engineering clues
    analysis_notes:
      distinct_value_count: 3
      null_percentage: 15.2
      most_common_values:
        - value: "Y"
          percentage: 45.0
        - value: "N"
          percentage: 39.8
        - value: null
          percentage: 15.2

# Metric View Recommendations
metric_view_suggestions:
  primary_time_dimension: order_date
  
  recommended_dimensions:
    - customer_natural_id
    - order_date
    - order_status
    
  recommended_measures:
    - name: "Order Count"
      expr: "COUNT(1)"
      
    - name: "Total Revenue"
      expr: "SUM(order_total_amount)"
      
    - name: "Average Order Value"
      expr: "SUM(order_total_amount) / COUNT(DISTINCT order_id)"
  
  recommended_filters:
    - "order_date >= '2020-01-01'"  # Data quality cutoff
    
  confidence_threshold: 0.70  # Only include columns with confidence >= 0.70
```

## Confidence Score Guidelines

```yaml
confidence_scores:
  1.00: "Absolutely certain - standard field with clear meaning"
  0.90-0.99: "Very confident - field name and values align with common patterns"
  0.70-0.89: "Confident - reasonable interpretation based on context"
  0.50-0.69: "Uncertain - multiple possible interpretations"
  0.30-0.49: "Low confidence - needs validation"
  0.00-0.29: "Very low confidence - exclude from metric view until clarified"

# Automatic flags
needs_review: true  # Set when confidence < 0.70
```

## Usage Category Definitions

```yaml
usage_categories:
  
  surrogate_key:
    definition: "System-generated identifier with no business meaning"
    include_in_metric_view: false
    example: "order_id, customer_key, product_key"
    use_for: "Joins, internal referential integrity"
    
  natural_key:
    definition: "Business identifier that has meaning to users"
    include_in_metric_view: true
    example: "customer_account_number, product_sku, invoice_number"
    use_for: "Filtering, grouping, display"
    
  dimension_candidate:
    definition: "Descriptive attribute useful for slicing/dicing"
    include_in_metric_view: true
    example: "order_date, customer_segment, product_category"
    use_for: "GROUP BY, WHERE, dimensions in metric view"
    
  measure_candidate:
    definition: "Numeric field suitable for aggregation"
    include_in_metric_view: true
    example: "order_amount, quantity, discount_percent"
    use_for: "SUM, AVG, COUNT, measures in metric view"
    
  internal_only:
    definition: "Technical field with unclear business purpose"
    include_in_metric_view: false
    example: "etl_batch_id, last_modified_timestamp, obscure_flags"
    use_for: "ETL/operational use only"
```

## CSV to YAML Conversion Script

If you already have CSVs, here's a Python script to convert them:

```python
import csv
import yaml
from pathlib import Path

def csv_to_schema_yaml(csv_path, output_dir, table_type='dimension'):
    """
    Convert CSV with columns to YAML schema file
    
    Expected CSV columns:
    - table_name
    - column_name
    - data_type
    - genie_description (your generated comments)
    - (optional) sample_value
    """
    
    # Read CSV
    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    
    # Group by table
    tables = {}
    for row in rows:
        table = row['table_name']
        if table not in tables:
            tables[table] = []
        tables[table].append(row)
    
    # Create YAML for each table
    for table_name, columns in tables.items():
        schema = {
            'table': {
                'name': table_name,
                'type': table_type,
                'description': 'TODO: Add business description',
                'primary_key': []  # TODO: Identify from data
            },
            'columns': [],
            'metric_view_suggestions': {
                'recommended_dimensions': [],
                'recommended_measures': [],
                'confidence_threshold': 0.70
            }
        }
        
        for col in columns:
            # Infer usage category from column name patterns
            col_name = col['column_name'].lower()
            
            if any(x in col_name for x in ['_key', '_id', '_sk']):
                if col_name.endswith('_key') and not 'natural' in col_name:
                    usage_category = 'surrogate_key'
                    include = False
                else:
                    usage_category = 'natural_key'
                    include = True
            elif any(x in col_name for x in ['amount', 'total', 'quantity', 'count', 'price']):
                usage_category = 'measure_candidate'
                include = True
            elif any(x in col_name for x in ['date', 'name', 'status', 'type', 'category']):
                usage_category = 'dimension_candidate'
                include = True
            else:
                usage_category = 'internal_only'
                include = False
            
            # Estimate confidence based on description quality
            description = col.get('genie_description', 'No description')
            if 'UNKNOWN' in description or len(description) < 10:
                confidence = 0.20
                needs_review = True
            elif '?' in description or 'unclear' in description.lower():
                confidence = 0.50
                needs_review = True
            else:
                confidence = 0.85  # Default for reasonable descriptions
                needs_review = False
            
            column_def = {
                'name': col['column_name'],
                'data_type': col['data_type'],
                'exposure': {
                    'include_in_metric_view': include,
                    'usage_category': usage_category,
                    'reason': f"Auto-categorized as {usage_category}"
                },
                'genie': {
                    'description': description,
                    'confidence_score': confidence,
                    'needs_review': needs_review
                },
                'constraints': {
                    'nullable': True  # Default - update manually
                }
            }
            
            if 'sample_value' in col and col['sample_value']:
                column_def['sample_values'] = [col['sample_value']]
            
            schema['columns'].append(column_def)
        
        # Write YAML file
        safe_table_name = table_name.replace('.', '_')
        output_path = Path(output_dir) / f"{safe_table_name}.yaml"
        
        with open(output_path, 'w') as f:
            yaml.dump(schema, f, default_flow_style=False, sort_keys=False)
        
        print(f"Created: {output_path}")

# Usage
csv_to_schema_yaml('my_tables.csv', './schema_docs/dimensions/', 'dimension')
```

## How Claude Code Will Use These Files

When you ask Claude Code to create a metric view:

1. **Discovery**: Claude reads all YAML files in schema_docs/
2. **Filtering**: Only considers columns where `include_in_metric_view: true` and `confidence_score >= threshold`
3. **Join Logic**: Uses `recommended_joins` to build join clauses
4. **Dimension Selection**: Prioritizes `dimension_candidate` columns
5. **Measure Creation**: Uses `measure_candidate` columns with `suggested_measures`
6. **Genie Integration**: Copies descriptions and synonyms to metric view YAML
7. **Review Report**: Flags any columns with `needs_review: true` for your attention

## Example Prompt for Claude Code

```
Using the schema documentation in ./schema_docs/, create a metric view for order 
analysis. Include:
- fact_orders as the source
- Join with dim_customer and dim_product
- Only include columns with confidence_score >= 0.70
- Add measures for total revenue, order count, and average order value
- Generate a report of any columns that need_review: true
```

## Review Workflow

1. **Initial Load**: Convert CSVs to YAML with auto-categorization
2. **Review Pass 1**: Fix all `needs_review: true` columns
3. **Review Pass 2**: Validate `usage_category` assignments
4. **Review Pass 3**: Verify `recommended_joins` relationships
5. **Sign Off**: Set `confidence_score` to final values
6. **Generate**: Let Claude Code create metric views

## Benefits of This Approach

✅ **Single Source of Truth**: One file per table, version controlled
✅ **Self-Documenting**: Clear structure anyone can understand
✅ **LLM-Optimized**: Claude can parse and reason about relationships
✅ **Incremental**: Start rough, refine over time
✅ **Auditable**: Track which fields are uncertain vs. validated
✅ **Reusable**: Same schema docs work for metric views, DBT, documentation sites
✅ **Searchable**: Easy to grep/search across all tables
✅ **Maintainable**: Update one file when columns change