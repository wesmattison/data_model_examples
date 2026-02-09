-- =============================================================================
-- PHARMACY CLAIMS METRIC VIEW (Flattened with All Dimensions)
-- =============================================================================
-- Source: catalog.schema.fact_pharmacy (fact table)
-- Grain: One row per pharmacy claim line
-- Description: Pharmacy claims fact table with ALL dimensions flattened via
--              LEFT JOINs to: dim_date (fill date), dim_member, dim_pharmacy,
--              dim_ndc, dim_provider (prescriber), and dim_marketproduct.
--              Only columns marked include_in_metric_view=true are included.
--              PII fields (member names, addresses, phone, email) excluded.
-- =============================================================================
-- JOINS:
--   fact_pharmacy.FilledDate_Sk       -> dim_date.DimensionDate_sk
--   fact_pharmacy.Member_SK           -> fact_member.Member_SK
--   fact_pharmacy.Pharmacy_SK         -> dim_pharmacy.Pharmacy_Sk
--   fact_pharmacy.Ndc_SK              -> dim_ndc.Ndc_SK
--   fact_pharmacy.Practitioner_SK     -> provider.Provider_SK
--   fact_pharmacy.MarketProgram_SK    -> marketproduct.MarketProduct_SK
-- =============================================================================

CREATE OR REPLACE VIEW catalog.schema.mv_pharmacy_claims AS
SELECT
    -- =========================================================================
    -- PHARMACY CLAIM FACT FIELDS
    -- =========================================================================

    -- Claim Identifiers
    rx.RxNumber,

    -- Claim Flags
    rx.PBMGenericFlag,
    rx.CompoundFlag,
    rx.RxClaimReversalFlag,

    -- Transaction Details
    rx.TransactionSource,
    rx.TransactionTypeCode,
    rx.AdjustmentTypeCode,
    rx.AdjustmentReasonCode,

    -- Refill Information
    rx.AuthorizedRefillCount,
    rx.RefillNumber,

    -- Quantity Fields
    rx.PrescribedQuantity,
    rx.DrugDaySupplyCount,
    rx.DrugMetricQuantity,
    rx.DrugStrengthQuantity,

    -- Patient Information (non-PII)
    rx.PatientAge,
    rx.PatientPlaceOfServiceCode,
    rx.PatientRelationshipCode,
    rx.PatientResidenceCode,

    -- Drug Classification
    rx.DrugTypeCode,
    rx.DrugDosageFormCode,
    rx.DrugCategoryCode,
    rx.DEAClassificationCode,

    -- Pharmacy Codes
    rx.PharmacyDAWCode,
    rx.PharmacyServiceLevelCode,
    rx.PharmacyClassCode,
    rx.CardholderOtherCoverageCode,

    -- Status Fields
    rx.CMSStatus,
    rx.CMSPartDQualifiedFacilityFlag,
    rx.RxSource,

    -- Reversal
    rx.ReversalCount,

    -- Mail Order
    rx.MailOrderDaysSupplyQuantity,

    -- =========================================================================
    -- COST / FINANCIAL MEASURES
    -- =========================================================================
    rx.CopayAmount,
    rx.DisallowIngredientAmount,
    rx.InvoicedAmount,
    rx.GrossDueAmount,
    rx.MOOPAmount,
    rx.OtherPayerRecognizedAmount,
    rx.DispensingSubmitAmount,
    rx.DispensingPaidAmount,
    rx.IngredientSubmitAmount,
    rx.IngredientPaidAmount,
    rx.PatientSubmitPaidAmount,
    rx.PatientPaidAmount,
    rx.ProfessionalServiceSubmitAmount,
    rx.UnitCostAmount,
    rx.PaidProfessionalServiceFeeAmount,
    rx.PaidFlatSalesTaxAmount,
    rx.PaidPercentageSalesTaxAmount,
    rx.AppliedPeriodicDeductableAmount,
    rx.CoinsuranceAmount,
    rx.MaximumAllowableCostPriceAmount,
    rx.UsualAndCustomaryChargeAmount,

    -- =========================================================================
    -- DATE DIMENSION (Fill Date)
    -- =========================================================================
    d.DimensionDate                   AS FillDate,
    d.DimensionMonthDate              AS FillMonthDate,
    d.MonthName                       AS FillMonthName,
    d.MonthAbbreviatedName            AS FillMonthAbbr,
    d.CurrentMonthNumber              AS FillCurrentMonthNumber,
    d.MonthOfYearNumber               AS FillMonthOfYear,
    d.MonthYearName                   AS FillMonthYearName,
    d.MonthFirstDayDate               AS FillMonthFirstDay,
    d.MonthLastDayDate                AS FillMonthLastDay,
    d.DimensionQuarterDate            AS FillQuarterDate,
    d.QuarterName                     AS FillQuarterName,
    d.YearQuarter                     AS FillYearQuarter,
    d.QuarterFirstDayDate             AS FillQuarterFirstDay,
    d.QuarterLastDayDate              AS FillQuarterLastDay,
    d.DimensionYear                   AS FillYear,
    d.YearMonth                       AS FillYearMonth,
    d.`Year-Month`                    AS FillYearMonthStr,
    d.DayNumber                       AS FillDayNumber,
    d.WeekDayName                     AS FillWeekDayName,
    d.WeekDayAbbreviatedName          AS FillWeekDayAbbr,
    d.ISOWeek                         AS FillISOWeek,
    d.WeekendFlag                     AS FillWeekendFlag,
    d.HolidayFlag                     AS FillHolidayFlag,
    d.HolidayName                     AS FillHolidayName,

    -- =========================================================================
    -- MEMBER DIMENSION (Non-PII Demographics)
    -- =========================================================================
    m.SubscriberID                    AS MemberSubscriberID,
    m.SubscriberIDMemberIDSuffixNumber AS MemberFullID,
    m.MemberIDSuffixNumber            AS MemberSuffixNumber,
    m.MemberSubscriberRelationshipCode AS MemberRelationshipCode,
    m.SubscriberMedicaidID            AS MemberMedicaidID,
    m.SubscriberMedicareID            AS MemberMedicareID,
    m.MemberStandardUniqueHealthID    AS MemberUniqueHealthID,
    m.MemberBirthDate,
    m.MemberGenderCode,
    m.MemberEthnicityCode,
    m.MemberEthnicity,
    m.MemberLanguageCode,
    m.MemberLanguageDesc,
    m.MemberCity,
    m.MemberState,
    m.MemberZip,
    m.MemberCountyName,
    m.MemberStatusCode,
    m.MemberStatusDesc,
    m.MemberAgreementEffectiveDate,
    m.FamilyMemberCaseNbr,

    -- =========================================================================
    -- PHARMACY DIMENSION
    -- =========================================================================
    ph.PharmacyNCPDPID,
    ph.PharmacyNPI                    AS PharmacyNPI,
    ph.PharmacyTaxIDNumber,
    ph.PharmacyDEANumber,
    ph.PharmacyName,
    ph.PharmacyAddress,
    ph.PharmacyAddress2,
    ph.PharmacyCity,
    ph.PharmacyCounty,
    ph.PharmacyStateCode,
    ph.PharmacyPostalCode,
    ph.PharmacyGroup,
    ph.DispenserClassCode,
    ph.DispenserClassCodeDescription  AS PharmacyTypeDesc,

    -- =========================================================================
    -- NDC (DRUG) DIMENSION
    -- =========================================================================
    ndc.NDCCode,
    ndc.DrugProductDesc,
    ndc.DrugLabelName,
    ndc.DrugGenericName,
    ndc.DrugBaseNameCode,
    ndc.DrugNameDoseFormCode,
    ndc.DrugNameDoseFormDesc,
    ndc.DrugManufacturerId,
    ndc.DrugManufacturerName,
    ndc.DrugSuperGroupCode,
    ndc.DrugSuperGroupDesc,
    ndc.DrugGroupCode,
    ndc.DrugGroupDesc,
    ndc.DrugClassCode,
    ndc.DrugClassDesc,
    ndc.DrugSubClassCode,
    ndc.DrugSubClassDesc,
    ndc.MediSpanDEAClassCode,
    ndc.OTCCode,
    ndc.UnitOfMeasureCode,
    ndc.MaintenanceDrugCode,
    ndc.MaintenanceDrugDesc,
    ndc.MaintenanceDrugFlag,
    ndc.BrandProductFlag,
    ndc.ControlledSubstanceFlag,
    ndc.SpecialtyFlag,
    ndc.GPINumber,
    ndc.MediSpanDrugProductName,
    ndc.MediSpanDrugProductGenericName,
    ndc.MediSpanDrugProductShortDesc,
    ndc.MedispanDrugAWPUnitPriceAmount,
    ndc.MedispanDrugAWPPackagePriceAmount,
    ndc.FDATherapeuticClassCode,
    ndc.FDATherapeuticClassDesc,

    -- =========================================================================
    -- PROVIDER (PRESCRIBER) DIMENSION
    -- =========================================================================
    prov.ProviderNPI                  AS PrescriberNPI,
    prov.ProviderFederalTaxID         AS PrescriberFederalTaxID,
    prov.ProviderTaxID                AS PrescriberTaxID,
    prov.ProviderName                 AS PrescriberName,
    prov.ProviderTaxIDName            AS PrescriberTaxIDName,
    prov.ProviderTypeDesc             AS PrescriberTypeDesc,
    prov.ProviderSpecialtyDesc        AS PrescriberSpecialtyDesc,
    prov.ProviderSecondarySpecialtyDesc AS PrescriberSecondarySpecialtyDesc,

    -- =========================================================================
    -- MARKET PRODUCT DIMENSION
    -- =========================================================================
    mp.ClientID                       AS MarketProductClientID,
    mp.MarketCode,
    mp.MarketDesc,
    mp.ProductCode,
    mp.ProductDesc,
    mp.SubProductCode,
    mp.SubProductDesc,
    mp.ProductCategoryCode,
    mp.ProductCategoryDesc

FROM catalog.schema.fact_pharmacy rx

-- Fill Date
LEFT JOIN catalog.schema.dim_date d
    ON rx.FilledDate_Sk = d.DimensionDate_sk

-- Member Demographics (excludes PII)
LEFT JOIN catalog.schema.fact_member m
    ON rx.Member_SK = m.Member_SK

-- Dispensing Pharmacy
LEFT JOIN catalog.schema.dim_pharmacy ph
    ON rx.Pharmacy_SK = ph.Pharmacy_Sk

-- Drug (NDC)
LEFT JOIN catalog.schema.dim_ndc ndc
    ON rx.Ndc_SK = ndc.Ndc_SK

-- Prescribing Provider
LEFT JOIN catalog.schema.provider prov
    ON rx.Practitioner_SK = prov.Provider_SK

-- Market / Product
LEFT JOIN catalog.schema.marketproduct mp
    ON rx.MarketProgram_SK = mp.MarketProduct_SK
;
