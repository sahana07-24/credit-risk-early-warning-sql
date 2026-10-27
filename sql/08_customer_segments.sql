-- 08 · Customer value segments and cross-sell opportunities
-- Question: which customers hold the most money, and which products do they not have yet?

WITH balances AS (
    SELECT account_id, AVG(balance_after_czk) AS avg_balance_1998
    FROM transactions
    WHERE trans_date >= DATE '1998-01-01'
    GROUP BY account_id
),
products AS (
    SELECT
        a.account_id,
        b.avg_balance_1998,
        o.card_type IS NOT NULL                                                    AS has_card,
        EXISTS (SELECT 1 FROM loans l WHERE l.account_id = a.account_id)           AS has_loan,
        EXISTS (SELECT 1 FROM raw_order r WHERE CAST(r.account_id AS INT) = a.account_id
                                           AND trim(r.k_symbol) = 'POJISTNE')      AS has_insurance_order,
        o.has_joint_user
    FROM accounts a
    JOIN account_owners o USING (account_id)
    JOIN balances b USING (account_id)
),
tiered AS (
    SELECT *,
           NTILE(4) OVER (ORDER BY avg_balance_1998 DESC) AS balance_quartile
    FROM products
)
SELECT
    CASE balance_quartile WHEN 1 THEN 'Q1 (highest balance)' WHEN 2 THEN 'Q2' WHEN 3 THEN 'Q3'
                          ELSE 'Q4 (lowest balance)' END                     AS balance_tier,
    COUNT(*)                                                                 AS accounts,
    ROUND(MIN(avg_balance_1998))                                             AS min_avg_balance_czk,
    ROUND(MEDIAN(avg_balance_1998))                                          AS median_avg_balance_czk,
    ROUND(100.0 * AVG(has_card::INT), 1)                                     AS pct_with_card,
    ROUND(100.0 * AVG(has_loan::INT), 1)                                     AS pct_with_loan,
    ROUND(100.0 * AVG(has_insurance_order::INT), 1)                          AS pct_with_insurance,
    ROUND(100.0 * AVG(has_joint_user::INT), 1)                               AS pct_joint_account,
    COUNT(*) FILTER (WHERE NOT has_card AND NOT has_loan)                    AS no_card_no_loan_accounts
FROM tiered
GROUP BY balance_quartile
ORDER BY balance_quartile;
