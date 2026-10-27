-- 01 · Staging layer: translate the raw Czech tables into clean, typed, English tables
-- Raw tables (raw_*) are loaded as text exactly as published. Everything analysed later reads from
-- the tables created here, so every decoding rule lives in one place.

-- Dates are stored as YYMMDD numbers (e.g. 930705 = 5 Jul 1993). All fall in 1993–1999.
CREATE OR REPLACE MACRO yymmdd(s) AS
    make_date(1900 + CAST(substr(s, 1, 2) AS INT), CAST(substr(s, 3, 2) AS INT), CAST(substr(s, 5, 2) AS INT));

CREATE OR REPLACE TABLE districts AS
SELECT
    CAST(A1 AS INT)            AS district_id,
    A2                         AS district_name,
    A3                         AS region,
    CAST(A4 AS INT)            AS population,
    CAST(A10 AS DOUBLE)        AS urban_pct,
    CAST(A11 AS INT)           AS avg_salary_czk,
    CAST(A13 AS DOUBLE)        AS unemployment_rate_96,
    CAST(A16 AS INT) * 1000.0 / CAST(A4 AS INT) AS crimes_per_1000_96
FROM raw_district;

CREATE OR REPLACE TABLE accounts AS
SELECT
    CAST(account_id AS INT)    AS account_id,
    CAST(district_id AS INT)   AS district_id,
    CASE frequency
        WHEN 'POPLATEK MESICNE'   THEN 'Monthly statement'
        WHEN 'POPLATEK TYDNE'     THEN 'Weekly statement'
        WHEN 'POPLATEK PO OBRATU' THEN 'Statement after transaction'
    END                        AS statement_frequency,
    yymmdd(date)               AS opened_date
FROM raw_account;

-- birth_number is YYMMDD, but women have 50 added to the month (e.g. 706213 = woman born 13 Dec 1970)
CREATE OR REPLACE TABLE clients AS
SELECT
    CAST(client_id AS INT)     AS client_id,
    CAST(district_id AS INT)   AS district_id,
    CASE WHEN CAST(substr(birth_number, 3, 2) AS INT) > 50 THEN 'Female' ELSE 'Male' END AS gender,
    make_date(1900 + CAST(substr(birth_number, 1, 2) AS INT),
              CAST(substr(birth_number, 3, 2) AS INT) % 50,
              CAST(substr(birth_number, 5, 2) AS INT)) AS birth_date
FROM raw_client;

CREATE OR REPLACE TABLE dispositions AS
SELECT
    CAST(disp_id AS INT)       AS disp_id,
    CAST(client_id AS INT)     AS client_id,
    CAST(account_id AS INT)    AS account_id,
    CASE type WHEN 'OWNER' THEN 'Owner' ELSE 'Authorised user' END AS role
FROM raw_disp;

CREATE OR REPLACE TABLE cards AS
SELECT
    CAST(card_id AS INT)       AS card_id,
    CAST(disp_id AS INT)       AS disp_id,
    upper(type[1]) || lower(type[2:]) AS card_type,
    yymmdd(issued)             AS issued_date
FROM raw_card;

-- Loan status: A/B = contract finished, C/D = still running. B and D are the problem loans.
CREATE OR REPLACE TABLE loans AS
SELECT
    CAST(loan_id AS INT)       AS loan_id,
    CAST(account_id AS INT)    AS account_id,
    yymmdd(date)               AS loan_date,
    CAST(amount AS DOUBLE)     AS amount_czk,
    CAST(duration AS INT)      AS duration_months,
    CAST(payments AS DOUBLE)   AS monthly_payment_czk,
    CASE status
        WHEN 'A' THEN 'Finished, paid in full'
        WHEN 'B' THEN 'Finished, not paid'
        WHEN 'C' THEN 'Running, up to date'
        WHEN 'D' THEN 'Running, in debt'
    END                        AS status,
    status IN ('B', 'D')       AS is_bad,
    status IN ('A', 'B')       AS is_finished
FROM raw_loan;

CREATE OR REPLACE TABLE transactions AS
SELECT
    CAST(trans_id AS INT)      AS trans_id,
    CAST(account_id AS INT)    AS account_id,
    yymmdd(date)               AS trans_date,
    CASE WHEN type = 'PRIJEM' THEN 'Credit' ELSE 'Debit' END AS direction,   -- VYDAJ and VYBER are both money out
    CASE operation
        WHEN 'VKLAD'          THEN 'Cash deposit'
        WHEN 'VYBER'          THEN 'Cash withdrawal'
        WHEN 'VYBER KARTOU'   THEN 'Card withdrawal'
        WHEN 'PREVOD Z UCTU'  THEN 'Incoming transfer'
        WHEN 'PREVOD NA UCET' THEN 'Outgoing transfer'
        ELSE 'Interest / other'                                              -- blank operation = interest credited
    END                        AS operation,
    CASE trim(k_symbol)
        WHEN 'POJISTNE'    THEN 'Insurance'
        WHEN 'SLUZBY'      THEN 'Statement fee'
        WHEN 'UROK'        THEN 'Interest credited'
        WHEN 'SANKC. UROK' THEN 'Penalty interest'                           -- charged when the balance is negative
        WHEN 'SIPO'        THEN 'Household bills'
        WHEN 'DUCHOD'      THEN 'Pension'
        WHEN 'UVER'        THEN 'Loan repayment'
        ELSE NULL
    END                        AS purpose,
    CASE WHEN type = 'PRIJEM' THEN 1 ELSE -1 END * CAST(amount AS DOUBLE) AS signed_amount_czk,
    CAST(amount AS DOUBLE)     AS amount_czk,
    CAST(balance AS DOUBLE)    AS balance_after_czk
FROM raw_trans;

-- One row per account with its owner, for demographic joins
CREATE OR REPLACE TABLE account_owners AS
SELECT
    d.account_id,
    c.client_id,
    c.gender,
    c.birth_date,
    c.district_id AS client_district_id,
    EXISTS (SELECT 1 FROM dispositions d2 WHERE d2.account_id = d.account_id AND d2.role = 'Authorised user') AS has_joint_user,
    (SELECT MAX(k.card_type) FROM cards k JOIN dispositions d3 USING (disp_id) WHERE d3.account_id = d.account_id) AS card_type
FROM dispositions d
JOIN clients c USING (client_id)
WHERE d.role = 'Owner';

SELECT 'districts' AS table_name, COUNT(*) AS rows FROM districts
UNION ALL SELECT 'accounts', COUNT(*) FROM accounts
UNION ALL SELECT 'clients', COUNT(*) FROM clients
UNION ALL SELECT 'dispositions', COUNT(*) FROM dispositions
UNION ALL SELECT 'cards', COUNT(*) FROM cards
UNION ALL SELECT 'loans', COUNT(*) FROM loans
UNION ALL SELECT 'transactions', COUNT(*) FROM transactions
UNION ALL SELECT 'account_owners', COUNT(*) FROM account_owners;
