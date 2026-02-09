-- =============================================================================
-- MEMBERS METRIC VIEW
-- =============================================================================
-- Source: catalog.schema.fact_member (dimension table)
-- Grain: One row per unique member
-- Description: Member demographic dimension exposing safe, non-PII attributes
--              for member analysis. Excludes names, addresses, phone, email.
-- =============================================================================
-- PII EXCLUSIONS: MemberName, MemberFirstName, MemberMiddleInitial,
--   MemberLastName, MemberAddress, MemberAddress2, PhoneNumber,
--   PhoneNumberExt, MemberEmailAddress
-- =============================================================================

CREATE OR REPLACE VIEW catalog.schema.mv_members AS
SELECT
    -- Member Identifiers (Natural Keys)
    m.SubscriberID,
    m.SubscriberIDMemberIDSuffixNumber,
    m.MemberIDSuffixNumber,
    m.MemberSubscriberRelationshipCode,
    m.SubscriberMedicaidID,
    m.SubscriberMedicareID,
    m.MemberStandardUniqueHealthID,

    -- Demographics
    m.MemberBirthDate,
    m.MemberGenderCode,
    m.MemberEthnicityCode,
    m.MemberEthnicity,
    m.MemberLanguageCode,
    m.MemberLanguageDesc,

    -- Geography (safe at aggregate level)
    m.MemberCity,
    m.MemberState,
    m.MemberZip,
    m.MemberCountyName,

    -- Enrollment Status
    m.MemberStatusCode,
    m.MemberStatusDesc,
    m.MemberAgreementEffectiveDate,

    -- Family/Group
    m.FamilyMemberCaseNbr

FROM catalog.schema.fact_member m
;
