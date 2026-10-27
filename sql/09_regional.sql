-- 09 · Regional view: does the local economy explain account balances and loan risk?

WITH by_district AS (
    SELECT
        d.district_id, d.district_name, d.region, d.avg_salary_czk, d.unemployment_rate_96,
        COUNT(DISTINCT a.account_id)                         AS accounts,
        COUNT(l.loan_id)                                     AS loans,
        SUM(l.is_bad::INT)                                   AS bad_loans
    FROM districts d
    JOIN accounts a USING (district_id)
    LEFT JOIN loans l USING (account_id)
    GROUP BY ALL
)
SELECT
    region,
    COUNT(*)                                                  AS districts,
    SUM(accounts)                                             AS accounts,
    SUM(loans)                                                AS loans,
    SUM(bad_loans)                                            AS bad_loans,
    ROUND(100.0 * SUM(bad_loans) / NULLIF(SUM(loans), 0), 1)  AS bad_rate_pct,
    ROUND(SUM(avg_salary_czk * accounts) / SUM(accounts))     AS avg_salary_czk,
    ROUND(SUM(unemployment_rate_96 * accounts) / SUM(accounts), 2) AS avg_unemployment_pct,
    -- district-level correlation across ALL districts, repeated for reference
    ROUND((SELECT CORR(unemployment_rate_96, bad_loans::DOUBLE / NULLIF(loans, 0)) FROM by_district WHERE loans >= 5), 2)
                                                              AS corr_unemployment_vs_bad_rate_all_districts
FROM by_district
GROUP BY region
ORDER BY bad_rate_pct DESC;
