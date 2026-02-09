-- =============================================================================
-- MEMBER MONTHS METRIC VIEW
-- =============================================================================
-- Source: catalog.schema.fact_membermonth (fact table)
-- Grain: One row per member per month of enrollment
-- Description: Member enrollment fact table tracking monthly enrollment status,
--              new/continuing/termed member counts, and enrollment days.
--              Excludes all ACG clinical segmentation fields and deprecated keys.
-- =============================================================================

CREATE OR REPLACE VIEW catalog.schema.mv_member_months AS
SELECT
    -- Time Dimension
    mm.MemberMonthStart,

    -- Foreign Keys (for downstream joins if needed)
    mm.Member_SK,
    mm.MarketProduct_SK,

    -- Enrollment Count Indicators
    mm.NewMemberCount,
    mm.ContinueMemberCount,
    mm.TermedMemberCount,

    -- Member Tenure
    mm.StartOfMonthAge_SK,
    mm.EndOfMonthAge_SK,

    -- Enrollment Duration
    mm.DaysInMonth,
    mm.DaysCompleted,
    mm.MonthDaysRatio,

    -- Coordination of Benefits
    mm.COBFlag

FROM catalog.schema.fact_membermonth mm
;
