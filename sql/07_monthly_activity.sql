-- 07 · Monthly banking activity, 1993–1998
-- Question: how fast is the bank growing, and how are customers moving from cash to cards?

WITH monthly AS (
    SELECT
        date_trunc('month', trans_date)::DATE                                  AS month,
        COUNT(DISTINCT account_id)                                             AS active_accounts,
        COUNT(*)                                                               AS transactions,
        SUM(amount_czk) FILTER (WHERE direction = 'Credit')                    AS inflow_czk,
        SUM(amount_czk) FILTER (WHERE direction = 'Debit')                     AS outflow_czk,
        COUNT(*) FILTER (WHERE operation = 'Card withdrawal')                  AS card_withdrawals,
        COUNT(*) FILTER (WHERE operation = 'Cash withdrawal')                  AS cash_withdrawals
    FROM transactions
    GROUP BY 1
)
SELECT
    month,
    active_accounts,
    transactions,
    ROUND(inflow_czk)                                                           AS inflow_czk,
    ROUND(outflow_czk)                                                          AS outflow_czk,
    ROUND(100.0 * card_withdrawals / NULLIF(card_withdrawals + cash_withdrawals, 0), 2) AS card_share_of_withdrawals_pct,
    ROUND(100 * (active_accounts::DOUBLE / LAG(active_accounts, 12) OVER (ORDER BY month) - 1), 1) AS active_accounts_yoy_pct,
    SUM(COUNT_OPENED) OVER (ORDER BY month)                                     AS cumulative_accounts_opened
FROM monthly
LEFT JOIN (SELECT date_trunc('month', opened_date)::DATE AS month, COUNT(*) AS count_opened
           FROM accounts GROUP BY 1) o USING (month)
ORDER BY month;
