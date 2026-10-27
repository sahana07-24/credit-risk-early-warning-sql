-- 03 · Loan portfolio overview
-- Question: how big is the loan book, and how much of it is in trouble?

SELECT
    status,
    COUNT(*)                                                AS loans,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)      AS pct_loans,
    ROUND(SUM(amount_czk))                                  AS total_amount_czk,
    ROUND(100.0 * SUM(amount_czk) / SUM(SUM(amount_czk)) OVER (), 1) AS pct_amount,
    ROUND(AVG(amount_czk))                                  AS avg_amount_czk,
    ROUND(AVG(duration_months), 1)                          AS avg_duration_months,
    ROUND(AVG(monthly_payment_czk))                         AS avg_monthly_payment_czk
FROM loans
GROUP BY status
ORDER BY MIN(CASE status WHEN 'Finished, paid in full' THEN 1 WHEN 'Finished, not paid' THEN 2
                         WHEN 'Running, up to date' THEN 3 ELSE 4 END);
