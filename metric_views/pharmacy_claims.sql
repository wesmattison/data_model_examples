-- =============================================================================
-- PHARMACY CLAIMS UNITY METRIC VIEW
-- =============================================================================
-- Source: catalog.schema.fact_pharmacy (fact table)
-- Grain: One row per pharmacy claim line
-- Purpose: Pharmacy claims with drug, pharmacy, prescriber, and date dimensions
--          flattened. Member and market/product fields are NOT included here to
--          avoid conflicting sources of truth. Use MemberMonth_SK to join to
--          mv_member_months in Genie space for enrollment/market context, and
--          Member_SK to join to mv_members for demographics.
-- Joins: dim_date (fill date), dim_ndc, dim_pharmacy, provider
-- =============================================================================

CREATE OR REPLACE VIEW catalog.schema.mv_pharmacy_claims
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Pharmacy claims with drug, pharmacy, prescriber, and date dimensions. Join to mv_member_months via MemberMonth_SK and mv_members via Member_SK in Genie space for enrollment and demographic context."

source: catalog.schema.fact_pharmacy
filter: RxClaimReversalFlag = 0 OR RxClaimReversalFlag IS NULL

joins:
  - name: fill_date
    source: catalog.schema.dim_date
    'on': source.FilledDate_Sk = fill_date.DimensionDate_sk

  - name: ndc
    source: catalog.schema.dim_ndc
    'on': source.Ndc_SK = ndc.Ndc_SK

  - name: pharmacy
    source: catalog.schema.dim_pharmacy
    'on': source.Pharmacy_SK = pharmacy.Pharmacy_Sk

  - name: prescriber
    source: catalog.schema.provider
    'on': source.Practitioner_SK = prescriber.Provider_SK

dimensions:
  # ── Keys for Genie Joining ────────────────────────────────────────────────
  - name: membermonth_sk
    expr: MemberMonth_SK
    display_name: 'Member Month SK'
    comment: "Foreign key to mv_member_months - join in Genie space for enrollment and market/product context"

  - name: member_sk
    expr: Member_SK
    display_name: 'Member SK'
    comment: "Foreign key to mv_members - join in Genie space for member demographics"

  # ── Claim Identifiers ─────────────────────────────────────────────────────
  - name: rx_number
    expr: RxNumber
    display_name: 'Rx Number'
    synonyms: ['prescription number', 'Rx number', 'Rx #']

  # ── Claim Flags ───────────────────────────────────────────────────────────
  - name: is_generic
    expr: PBMGenericFlag
    display_name: 'Is Generic Drug'
    comment: "1=generic, 0=brand"
    synonyms: ['generic flag', 'generic indicator', 'brand vs generic']

  - name: is_compound
    expr: CompoundFlag
    display_name: 'Is Compound'
    comment: "1=compounded medication, 0=standard"
    synonyms: ['compound flag', 'compound drug']

  - name: is_reversal
    expr: RxClaimReversalFlag
    display_name: 'Is Reversal'
    comment: "1=reversal, 0=original. View filters to non-reversals by default."
    synonyms: ['reversal', 'voided claim']

  # ── Transaction Details ───────────────────────────────────────────────────
  - name: transaction_source
    expr: TransactionSource
    display_name: 'Transaction Source'
    synonyms: ['claim source']

  - name: transaction_type
    expr: TransactionTypeCode
    display_name: 'Transaction Type'
    synonyms: ['claim type']

  - name: adjustment_type
    expr: AdjustmentTypeCode
    display_name: 'Adjustment Type'
    synonyms: ['adjustment code']

  - name: adjustment_reason
    expr: AdjustmentReasonCode
    display_name: 'Adjustment Reason'

  # ── Refill Information ────────────────────────────────────────────────────
  - name: refill_number
    expr: RefillNumber
    display_name: 'Refill Number'
    comment: "0=original fill, 1+=refill sequence"
    synonyms: ['refill #', 'fill number']

  # ── Patient (non-PII) ────────────────────────────────────────────────────
  - name: patient_age
    expr: PatientAge
    display_name: 'Patient Age at Fill'
    synonyms: ['age', 'patient age', 'member age']

  - name: place_of_service
    expr: PatientPlaceOfServiceCode
    display_name: 'Place of Service'
    synonyms: ['service location']

  - name: patient_relationship
    expr: PatientRelationshipCode
    display_name: 'Patient Relationship'
    synonyms: ['relationship to subscriber']

  - name: patient_residence
    expr: PatientResidenceCode
    display_name: 'Patient Residence'
    synonyms: ['care setting']

  # ── Drug Classification (from claim) ──────────────────────────────────────
  - name: drug_strength
    expr: DrugStrengthQuantity
    display_name: 'Drug Strength'
    synonyms: ['strength', 'dosage strength']

  - name: drug_type
    expr: DrugTypeCode
    display_name: 'Drug Type'
    synonyms: ['drug type', 'drug category']

  - name: dosage_form
    expr: DrugDosageFormCode
    display_name: 'Dosage Form Code'
    synonyms: ['form code']

  - name: drug_category
    expr: DrugCategoryCode
    display_name: 'Drug Category'

  - name: dea_schedule
    expr: DEAClassificationCode
    display_name: 'DEA Schedule'
    comment: "Controlled substance classification (2-5)"
    synonyms: ['DEA class', 'controlled substance schedule']

  # ── Pharmacy Codes ────────────────────────────────────────────────────────
  - name: daw_code
    expr: PharmacyDAWCode
    display_name: 'DAW Code'
    comment: "0=generic substituted, 1=brand medically necessary, 2=patient requested brand"
    synonyms: ['dispense as written', 'DAW']

  - name: pharmacy_service_level
    expr: PharmacyServiceLevelCode
    display_name: 'Pharmacy Service Level'
    synonyms: ['network tier', 'pharmacy tier']

  - name: pharmacy_class
    expr: PharmacyClassCode
    display_name: 'Pharmacy Class'
    synonyms: ['pharmacy type code']

  - name: other_coverage_code
    expr: CardholderOtherCoverageCode
    display_name: 'Other Coverage Code'
    synonyms: ['COB code', 'other insurance code']

  # ── Status ────────────────────────────────────────────────────────────────
  - name: cms_status
    expr: CMSStatus
    display_name: 'CMS Status'
    synonyms: ['Medicare status']

  - name: cms_part_d_facility
    expr: CMSPartDQualifiedFacilityFlag
    display_name: 'Part D Qualified Facility'

  - name: rx_source
    expr: RxSource
    display_name: 'Rx Source'
    synonyms: ['prescription source']

  # ── Fill Date Dimension ───────────────────────────────────────────────────
  - name: fill_date
    expr: fill_date.DimensionDate
    display_name: 'Fill Date'
    synonyms: ['filled date', 'dispense date', 'date filled']
    format:
      type: date
      date_format: year_month_day

  - name: fill_month
    expr: fill_date.DimensionMonthDate
    display_name: 'Fill Month'
    synonyms: ['fill month', 'dispense month']
    format:
      type: date
      date_format: year_month_day

  - name: fill_month_name
    expr: fill_date.MonthName
    display_name: 'Fill Month Name'
    synonyms: ['month']

  - name: fill_quarter
    expr: fill_date.QuarterName
    display_name: 'Fill Quarter'
    synonyms: ['quarter']

  - name: fill_year
    expr: fill_date.DimensionYear
    display_name: 'Fill Year'
    synonyms: ['year']

  - name: fill_year_month
    expr: fill_date.YearMonth
    display_name: 'Fill Year-Month'
    comment: "YYYYMM numeric format"
    synonyms: ['year month', 'period']

  - name: fill_day_of_week
    expr: fill_date.WeekDayName
    display_name: 'Fill Day of Week'
    synonyms: ['day of week', 'weekday']

  - name: fill_is_weekend
    expr: fill_date.WeekendFlag
    display_name: 'Fill Is Weekend'
    synonyms: ['weekend', 'is weekend']

  - name: fill_is_holiday
    expr: fill_date.HolidayFlag
    display_name: 'Fill Is Holiday'
    synonyms: ['holiday', 'is holiday']

  # ── NDC / Drug Dimension ──────────────────────────────────────────────────
  - name: ndc_code
    expr: ndc.NDCCode
    display_name: 'NDC Code'
    synonyms: ['NDC', 'drug code', 'national drug code']

  - name: drug_name
    expr: ndc.DrugProductDesc
    display_name: 'Drug Name'
    synonyms: ['drug', 'medication', 'drug product']

  - name: drug_label_name
    expr: ndc.DrugLabelName
    display_name: 'Drug Label Name'
    synonyms: ['label name', 'brand label']

  - name: drug_generic_name
    expr: ndc.DrugGenericName
    display_name: 'Generic Name'
    synonyms: ['generic', 'generic drug', 'chemical name']

  - name: drug_dose_form
    expr: ndc.DrugNameDoseFormDesc
    display_name: 'Drug Dose Form'
    synonyms: ['dose form', 'formulation']

  - name: drug_manufacturer
    expr: ndc.DrugManufacturerName
    display_name: 'Manufacturer'
    synonyms: ['manufacturer', 'drug manufacturer', 'pharma company']

  - name: drug_super_group
    expr: ndc.DrugSuperGroupDesc
    display_name: 'Drug Super Group'
    synonyms: ['top level drug category']

  - name: drug_group
    expr: ndc.DrugGroupDesc
    display_name: 'Drug Group'
    synonyms: ['drug group']

  - name: drug_class
    expr: ndc.DrugClassDesc
    display_name: 'Drug Class'
    synonyms: ['therapeutic class', 'drug class']

  - name: drug_sub_class
    expr: ndc.DrugSubClassDesc
    display_name: 'Drug Sub-Class'
    synonyms: ['drug subclass', 'therapeutic subclass']

  - name: ndc_dea_class
    expr: ndc.MediSpanDEAClassCode
    display_name: 'NDC DEA Schedule'
    comment: "DEA classification from NDC dimension"
    synonyms: ['DEA class', 'controlled schedule']

  - name: is_otc
    expr: ndc.OTCCode
    display_name: 'OTC Code'
    synonyms: ['over the counter']

  - name: unit_of_measure
    expr: ndc.UnitOfMeasureCode
    display_name: 'Unit of Measure'
    synonyms: ['UOM', 'dispensing unit']

  - name: is_maintenance_drug
    expr: ndc.MaintenanceDrugFlag
    display_name: 'Is Maintenance Drug'
    comment: "1=maintenance (chronic), 0=acute/short-term"
    synonyms: ['maintenance drug', 'chronic medication']

  - name: is_brand
    expr: ndc.BrandProductFlag
    display_name: 'Is Brand Drug'
    comment: "1=brand name, 0=generic"
    synonyms: ['brand flag', 'brand vs generic']

  - name: is_controlled_substance
    expr: ndc.ControlledSubstanceFlag
    display_name: 'Is Controlled Substance'
    comment: "1=DEA controlled, 0=non-controlled"
    synonyms: ['controlled substance', 'controlled drug']

  - name: is_specialty
    expr: ndc.SpecialtyFlag
    display_name: 'Is Specialty Drug'
    comment: "1=specialty (high-cost, complex), 0=traditional"
    synonyms: ['specialty drug', 'specialty medication']

  - name: gpi_number
    expr: ndc.GPINumber
    display_name: 'GPI Number'
    comment: "Generic Product Identifier - 14-char hierarchical drug classification"
    synonyms: ['GPI', 'generic product identifier']

  - name: fda_therapeutic_class
    expr: ndc.FDATherapeuticClassDesc
    display_name: 'FDA Therapeutic Class'
    synonyms: ['FDA class', 'therapeutic class']

  # ── Pharmacy Dimension ────────────────────────────────────────────────────
  - name: pharmacy_ncpdp_id
    expr: pharmacy.PharmacyNCPDPID
    display_name: 'Pharmacy NCPDP ID'
    synonyms: ['NCPDP', 'pharmacy ID']

  - name: pharmacy_npi
    expr: pharmacy.PharmacyNPI
    display_name: 'Pharmacy NPI'
    synonyms: ['pharmacy NPI']

  - name: pharmacy_name
    expr: pharmacy.PharmacyName
    display_name: 'Pharmacy Name'
    synonyms: ['pharmacy', 'store name']

  - name: pharmacy_city
    expr: pharmacy.PharmacyCity
    display_name: 'Pharmacy City'
    synonyms: ['pharmacy city']

  - name: pharmacy_county
    expr: pharmacy.PharmacyCounty
    display_name: 'Pharmacy County'
    synonyms: ['pharmacy county']

  - name: pharmacy_state
    expr: pharmacy.PharmacyStateCode
    display_name: 'Pharmacy State'
    synonyms: ['pharmacy state']

  - name: pharmacy_zip
    expr: pharmacy.PharmacyPostalCode
    display_name: 'Pharmacy ZIP'
    synonyms: ['pharmacy ZIP code']

  - name: pharmacy_chain
    expr: pharmacy.PharmacyGroup
    display_name: 'Pharmacy Chain'
    synonyms: ['chain', 'pharmacy group', 'banner']

  - name: pharmacy_type
    expr: pharmacy.DispenserClassCodeDescription
    display_name: 'Pharmacy Type'
    comment: "Retail, Mail Order, Specialty, LTC, etc."
    synonyms: ['dispenser type', 'pharmacy channel']

  # ── Prescriber Dimension ──────────────────────────────────────────────────
  - name: prescriber_npi
    expr: prescriber.ProviderNPI
    display_name: 'Prescriber NPI'
    synonyms: ['prescriber NPI', 'provider NPI']

  - name: prescriber_name
    expr: prescriber.ProviderName
    display_name: 'Prescriber Name'
    synonyms: ['prescriber', 'doctor name', 'provider name']

  - name: prescriber_type
    expr: prescriber.ProviderTypeDesc
    display_name: 'Prescriber Type'
    synonyms: ['provider type']

  - name: prescriber_specialty
    expr: prescriber.ProviderSpecialtyDesc
    display_name: 'Prescriber Specialty'
    synonyms: ['specialty', 'medical specialty', 'provider specialty']

  - name: prescriber_secondary_specialty
    expr: prescriber.ProviderSecondarySpecialtyDesc
    display_name: 'Prescriber Secondary Specialty'
    synonyms: ['secondary specialty']

  - name: prescriber_org
    expr: prescriber.ProviderTaxIDName
    display_name: 'Prescriber Organization'
    synonyms: ['practice name', 'organization']

measures:
  # ── Utilization Measures ──────────────────────────────────────────────────
  - name: script_count
    expr: COUNT(1)
    display_name: 'Total Scripts'
    comment: "Total pharmacy claims (filtered to non-reversals)"
    synonyms: ['scripts', 'prescriptions', 'claims', 'claim count']
    format:
      type: number
      decimal_places:
        type: all

  - name: unique_scripts
    expr: COUNT(DISTINCT RxNumber)
    display_name: 'Unique Prescriptions'
    comment: "Distinct Rx numbers"
    synonyms: ['distinct prescriptions', 'unique Rx']
    format:
      type: number
      decimal_places:
        type: all

  - name: utilizing_members
    expr: COUNT(DISTINCT Member_SK)
    display_name: 'Utilizing Members'
    comment: "Distinct members with at least one pharmacy claim"
    synonyms: ['members with prescriptions', 'pharmacy utilizers']
    format:
      type: number
      decimal_places:
        type: all

  - name: total_days_supply
    expr: SUM(DrugDaySupplyCount)
    display_name: 'Total Days Supply'
    synonyms: ['days supply', 'supply days']
    format:
      type: number
      decimal_places:
        type: all

  - name: avg_days_supply
    expr: AVG(DrugDaySupplyCount)
    display_name: 'Avg Days Supply'
    synonyms: ['average days supply']
    format:
      type: number
      decimal_places:
        type: exact
        places: 1

  - name: total_quantity
    expr: SUM(PrescribedQuantity)
    display_name: 'Total Quantity'
    synonyms: ['prescribed quantity', 'drug quantity']
    format:
      type: number
      decimal_places:
        type: all

  - name: total_refills_authorized
    expr: SUM(AuthorizedRefillCount)
    display_name: 'Total Authorized Refills'
    synonyms: ['refills authorized']
    format:
      type: number
      decimal_places:
        type: all

  # ── Cost Measures ─────────────────────────────────────────────────────────
  - name: ingredient_cost_paid
    expr: SUM(IngredientPaidAmount)
    display_name: 'Ingredient Cost Paid'
    comment: "Drug ingredient cost paid by plan"
    synonyms: ['ingredient paid', 'drug cost paid']
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
      abbreviation: compact

  - name: dispensing_fee_paid
    expr: SUM(DispensingPaidAmount)
    display_name: 'Dispensing Fee Paid'
    synonyms: ['dispensing paid', 'dispensing fee']
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
      abbreviation: compact

  - name: plan_paid
    expr: SUM(IngredientPaidAmount) + SUM(DispensingPaidAmount)
    display_name: 'Plan Paid Amount'
    comment: "Total plan payment (ingredient + dispensing)"
    synonyms: ['plan cost', 'plan paid', 'reimbursement', 'total plan paid']
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
      abbreviation: compact

  - name: member_paid
    expr: SUM(PatientPaidAmount)
    display_name: 'Member Paid Amount'
    comment: "Total member out-of-pocket (copay + coinsurance + deductible)"
    synonyms: ['member cost', 'patient paid', 'out of pocket']
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
      abbreviation: compact

  - name: total_copay
    expr: SUM(CopayAmount)
    display_name: 'Total Copay'
    synonyms: ['copay', 'member copay', 'copayment']
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
      abbreviation: compact

  - name: total_coinsurance
    expr: SUM(CoinsuranceAmount)
    display_name: 'Total Coinsurance'
    synonyms: ['coinsurance', 'member coinsurance']
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
      abbreviation: compact

  - name: total_deductible
    expr: SUM(AppliedPeriodicDeductableAmount)
    display_name: 'Total Deductible Applied'
    synonyms: ['deductible', 'deductible applied']
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
      abbreviation: compact

  - name: invoiced_amount
    expr: SUM(InvoicedAmount)
    display_name: 'Total Invoiced Amount'
    synonyms: ['invoiced', 'billed amount', 'invoiced cost']
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
      abbreviation: compact

  - name: admin_fee
    expr: SUM(PaidProfessionalServiceFeeAmount)
    display_name: 'Admin Fee Amount'
    comment: "Professional service fees (admin/vaccine fees, counseling)"
    synonyms: ['professional service fee', 'admin fee']
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2

  - name: gross_due
    expr: SUM(GrossDueAmount)
    display_name: 'Gross Due Amount'
    synonyms: ['gross amount', 'gross due']
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
      abbreviation: compact

  - name: moop_amount
    expr: SUM(MOOPAmount)
    display_name: 'MOOP Amount'
    comment: "Maximum Out-Of-Pocket applied"
    synonyms: ['max out of pocket', 'MOOP']
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2

  # ── Composed Measures ─────────────────────────────────────────────────────
  - name: avg_cost_per_script
    expr: MEASURE(plan_paid) / MEASURE(script_count)
    display_name: 'Avg Cost Per Script'
    comment: "Average plan cost per pharmacy claim"
    synonyms: ['average cost', 'cost per claim', 'cost per script']
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2

  - name: avg_member_cost_per_script
    expr: MEASURE(member_paid) / MEASURE(script_count)
    display_name: 'Avg Member Cost Per Script'
    synonyms: ['member cost per claim']
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2

  - name: invoiced_per_script
    expr: MEASURE(invoiced_amount) / MEASURE(script_count)
    display_name: 'Invoiced Per Script'
    synonyms: ['cost per script', 'invoiced per claim']
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2

  - name: invoiced_per_utilizer
    expr: MEASURE(invoiced_amount) / MEASURE(utilizing_members)
    display_name: 'Invoiced Per Utilizer'
    synonyms: ['cost per utilizer']
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2

  - name: scripts_per_utilizer
    expr: MEASURE(script_count) / MEASURE(utilizing_members)
    display_name: 'Scripts Per Utilizer'
    synonyms: ['prescriptions per utilizer', 'scripts per member']
    format:
      type: number
      decimal_places:
        type: exact
        places: 2

  - name: quantity_per_script
    expr: MEASURE(total_quantity) / MEASURE(script_count)
    display_name: 'Quantity Per Script'
    synonyms: ['avg quantity']
    format:
      type: number
      decimal_places:
        type: exact
        places: 2

  - name: units_per_day
    expr: MEASURE(total_quantity) / MEASURE(total_days_supply)
    display_name: 'Units Per Day'
    synonyms: ['daily units', 'units per day of supply']
    format:
      type: number
      decimal_places:
        type: exact
        places: 2

  - name: generic_rate
    expr: SUM(CASE WHEN PBMGenericFlag = 1 THEN 1 ELSE 0 END) / COUNT(1)
    display_name: 'Generic Utilization Rate'
    comment: "Percentage of scripts that are generic"
    synonyms: ['generic rate', 'generic utilization', 'generic %']
    format:
      type: percentage
      decimal_places:
        type: exact
        places: 1

  - name: member_cost_share_rate
    expr: MEASURE(member_paid) / (MEASURE(plan_paid) + MEASURE(member_paid))
    display_name: 'Member Cost Share Rate'
    comment: "Member cost as percentage of total cost"
    synonyms: ['cost share', 'member share']
    format:
      type: percentage
      decimal_places:
        type: exact
        places: 1
$$
;
