-- =============================================================================
-- MEMBERS UNITY METRIC VIEW
-- =============================================================================
-- Source: catalog.schema.fact_member (dimension table)
-- Grain: One row per unique member
-- Purpose: Member demographics and identifiers. This is the single source of
--          truth for member attributes. Other metric views should join here
--          via Member_SK in the Genie space rather than duplicating fields.
-- PII EXCLUSIONS: names, addresses, phone, email
-- =============================================================================

CREATE OR REPLACE VIEW catalog.schema.mv_members
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Member demographics dimension - single source of truth for member attributes. Excludes all PII (names, addresses, phone, email)."

source: catalog.schema.fact_member

dimensions:
  # ── Member Identifiers ────────────────────────────────────────────────────
  - name: member_sk
    expr: Member_SK
    display_name: 'Member SK'
    comment: "Surrogate key for joining to other metric views in Genie space"

  - name: subscriber_id
    expr: SubscriberID
    display_name: 'Subscriber ID'
    synonyms: ['subscriber ID', 'member ID', 'policy number']

  - name: member_full_id
    expr: SubscriberIDMemberIDSuffixNumber
    display_name: 'Member Full ID'
    comment: "Combined subscriber ID + suffix (e.g., SUB123456-01)"
    synonyms: ['member ID', 'full member ID']

  - name: member_suffix
    expr: MemberIDSuffixNumber
    display_name: 'Member Suffix'
    comment: "0=subscriber/policyholder, 1+=dependents"
    synonyms: ['dependent number', 'person code']

  - name: relationship_code
    expr: MemberSubscriberRelationshipCode
    display_name: 'Relationship to Subscriber'
    comment: "01=Self, 02=Spouse, 03=Child, 19=Other"
    synonyms: ['relationship', 'dependent relationship']

  - name: medicaid_id
    expr: SubscriberMedicaidID
    display_name: 'Medicaid ID'
    synonyms: ['Medicaid ID', 'Medicaid number']

  - name: medicare_id
    expr: SubscriberMedicareID
    display_name: 'Medicare ID'
    synonyms: ['Medicare ID', 'Medicare number', 'HICN', 'MBI']

  - name: unique_health_id
    expr: MemberStandardUniqueHealthID
    display_name: 'Unique Health ID'
    synonyms: ['enterprise member ID']

  # ── Demographics ──────────────────────────────────────────────────────────
  - name: birth_date
    expr: MemberBirthDate
    display_name: 'Date of Birth'
    synonyms: ['DOB', 'birth date', 'date of birth']
    format:
      type: date
      date_format: year_month_day

  - name: gender
    expr: MemberGenderCode
    display_name: 'Gender'
    comment: "M=Male, F=Female, U=Unknown"
    synonyms: ['gender', 'sex']

  - name: ethnicity_code
    expr: MemberEthnicityCode
    display_name: 'Ethnicity Code'
    synonyms: ['ethnicity code']

  - name: ethnicity
    expr: MemberEthnicity
    display_name: 'Ethnicity'
    synonyms: ['ethnicity', 'ethnic group']

  - name: language_code
    expr: MemberLanguageCode
    display_name: 'Language Code'
    synonyms: ['language code']

  - name: language
    expr: MemberLanguageDesc
    display_name: 'Preferred Language'
    synonyms: ['language', 'preferred language']

  # ── Geography ─────────────────────────────────────────────────────────────
  - name: city
    expr: MemberCity
    display_name: 'City'
    synonyms: ['city', 'member city', 'residence city']

  - name: state
    expr: MemberState
    display_name: 'State'
    synonyms: ['state', 'member state']

  - name: zip_code
    expr: MemberZip
    display_name: 'ZIP Code'
    synonyms: ['ZIP', 'postal code', 'ZIP code']

  - name: county
    expr: MemberCountyName
    display_name: 'County'
    synonyms: ['county', 'member county']

  # ── Enrollment Status ─────────────────────────────────────────────────────
  - name: status_code
    expr: MemberStatusCode
    display_name: 'Status Code'
    synonyms: ['status code']

  - name: status
    expr: MemberStatusDesc
    display_name: 'Enrollment Status'
    synonyms: ['status', 'member status', 'enrollment status']

  - name: enrollment_date
    expr: MemberAgreementEffectiveDate
    display_name: 'Initial Enrollment Date'
    synonyms: ['enrollment date', 'effective date', 'start date']
    format:
      type: date
      date_format: year_month_day

  # ── Family ────────────────────────────────────────────────────────────────
  - name: family_case_number
    expr: FamilyMemberCaseNbr
    display_name: 'Family Case Number'
    synonyms: ['family ID', 'case number', 'household ID']

measures:
  - name: member_count
    expr: COUNT(1)
    display_name: 'Member Count'
    comment: "Total count of member records"
    synonyms: ['members', 'total members', 'headcount']
    format:
      type: number
      decimal_places:
        type: all
$$
;
