-- =============================================================================
-- MEMBER MONTHS UNITY METRIC VIEW
-- =============================================================================
-- Source: catalog.schema.fact_membermonth (fact table)
-- Grain: One row per member per month of enrollment
-- Purpose: Enrollment facts and market/product dimensions. This is the single
--          source of truth for enrollment metrics and market/product attributes.
--          Member demographics live in mv_members (join via Member_SK in Genie).
--          Pharmacy claims reference this view via MemberMonth_SK in Genie.
-- Joins: market_product dimension flattened here
-- Excludes: ACG fields, deprecated MarketProgram_SK
-- =============================================================================

CREATE OR REPLACE VIEW catalog.schema.mv_member_months
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Member enrollment facts with market/product dimensions. Single source of truth for enrollment metrics and market segmentation. Join to mv_members via Member_SK for demographics."

source: catalog.schema.fact_membermonth

joins:
  - name: market_product
    source: catalog.schema.marketproduct
    'on': source.MarketProduct_SK = market_product.MarketProduct_SK

dimensions:
  # ── Keys for Genie Joining ────────────────────────────────────────────────
  - name: membermonth_sk
    expr: MemberMonth_SK
    display_name: 'Member Month SK'
    comment: "Primary key - used by pharmacy claims metric view to join in Genie space"

  - name: member_sk
    expr: Member_SK
    display_name: 'Member SK'
    comment: "Foreign key to mv_members for demographics in Genie space"

  # ── Time ──────────────────────────────────────────────────────────────────
  - name: enrollment_month
    expr: MemberMonthStart
    display_name: 'Enrollment Month'
    comment: "First day of the enrollment month"
    synonyms: ['month', 'member month', 'enrollment month']
    format:
      type: date
      date_format: year_month_day

  # ── Enrollment Attributes ─────────────────────────────────────────────────
  - name: cob_flag
    expr: COBFlag
    display_name: 'Has Other Insurance (COB)'
    comment: "Coordination of Benefits - Y if member has other insurance"
    synonyms: ['COB', 'coordination of benefits', 'other insurance', 'dual coverage']

  # ── Member Tenure ─────────────────────────────────────────────────────────
  - name: start_of_month_tenure
    expr: StartOfMonthAge_SK
    display_name: 'Tenure at Month Start'
    comment: "Member enrollment tenure (months) at start of month"
    synonyms: ['start tenure', 'beginning tenure']

  - name: end_of_month_tenure
    expr: EndOfMonthAge_SK
    display_name: 'Tenure at Month End'
    comment: "Member enrollment tenure (months) at end of month"
    synonyms: ['end tenure', 'ending tenure']

  # ── Market / Product (from joined dimension) ─────────────────────────────
  - name: market_code
    expr: market_product.MarketCode
    display_name: 'State Code'
    comment: "Two-letter US state code (e.g., OH, CA, TX)"
    synonyms: ['state code', 'state', 'market', 'state abbreviation']

  - name: market_desc
    expr: market_product.MarketDesc
    display_name: 'State'
    comment: "Full US state name"
    synonyms: ['state name', 'market name']

  - name: product_code
    expr: market_product.ProductCode
    display_name: 'Product Code'
    synonyms: ['product', 'product identifier']

  - name: product_desc
    expr: market_product.ProductDesc
    display_name: 'Product'
    comment: "Insurance product brand name"
    synonyms: ['product name', 'brand name', 'plan name']

  - name: sub_product_code
    expr: market_product.SubProductCode
    display_name: 'Sub-Product Code'
    synonyms: ['sub-product', 'product variant']

  - name: sub_product_desc
    expr: market_product.SubProductDesc
    display_name: 'Sub-Product'
    synonyms: ['sub-product name']

  - name: client_id
    expr: market_product.ClientID
    display_name: 'Client ID'
    synonyms: ['client', 'client number', 'account']

  - name: product_category_code
    expr: market_product.ProductCategoryCode
    display_name: 'Product Category Code'
    synonyms: ['category code']

  - name: product_category_desc
    expr: market_product.ProductCategoryDesc
    display_name: 'Product Category'
    synonyms: ['product category', 'category']

measures:
  # ── Core Enrollment Measures ──────────────────────────────────────────────
  - name: total_members
    expr: COUNT(DISTINCT Member_SK)
    display_name: 'Total Members'
    comment: "Distinct count of members enrolled in the period"
    synonyms: ['members', 'member count', 'enrollment', 'enrolled members']
    format:
      type: number
      decimal_places:
        type: all

  - name: member_months
    expr: COUNT(1)
    display_name: 'Member Months'
    comment: "Count of member-month records (total enrollment volume)"
    synonyms: ['member months', 'enrollment months', 'MM']
    format:
      type: number
      decimal_places:
        type: all

  - name: new_members
    expr: SUM(NewMemberCount)
    display_name: 'New Members'
    comment: "Count of new member enrollments this month"
    synonyms: ['new enrollment', 'new adds', 'new members']
    format:
      type: number
      decimal_places:
        type: all

  - name: continuing_members
    expr: SUM(ContinueMemberCount)
    display_name: 'Continuing Members'
    comment: "Count of members who continued from prior month"
    synonyms: ['continuing', 'retained members', 'continuing enrollment']
    format:
      type: number
      decimal_places:
        type: all

  - name: termed_members
    expr: SUM(TermedMemberCount)
    display_name: 'Termed Members'
    comment: "Count of member terminations this month"
    synonyms: ['terminations', 'disenrollment', 'churn', 'termed']
    format:
      type: number
      decimal_places:
        type: all

  # ── Enrollment Duration ───────────────────────────────────────────────────
  - name: enrollment_days
    expr: SUM(DaysInMonth)
    display_name: 'Enrollment Days'
    comment: "Total member days of enrollment"
    synonyms: ['member days', 'days enrolled']
    format:
      type: number
      decimal_places:
        type: all

  - name: enrollment_ratio
    expr: AVG(MonthDaysRatio)
    display_name: 'Avg Enrollment Ratio'
    comment: "Average ratio of days enrolled to days in month (1.0 = full month)"
    synonyms: ['proration factor', 'enrollment fraction']
    format:
      type: number
      decimal_places:
        type: exact
        places: 3

  # ── Composed Measures ─────────────────────────────────────────────────────
  - name: retention_rate
    expr: MEASURE(continuing_members) / (MEASURE(continuing_members) + MEASURE(termed_members))
    display_name: 'Retention Rate'
    comment: "Percentage of members retained (continuing / (continuing + termed))"
    synonyms: ['retention', 'retention percentage']
    format:
      type: percentage
      decimal_places:
        type: exact
        places: 2

  - name: net_enrollment_change
    expr: MEASURE(new_members) - MEASURE(termed_members)
    display_name: 'Net Enrollment Change'
    comment: "New members minus termed members"
    synonyms: ['net change', 'net growth', 'enrollment change']
    format:
      type: number
      decimal_places:
        type: all
$$
;
