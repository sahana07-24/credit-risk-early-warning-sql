-- 05 · Account behaviour in the 6 months BEFORE each loan was granted
-- Question: was there a warning sign in the account before the bank lent the money?
-- Only transactions strictly before the loan date are used, so nothing here "knows the future".

CREATE OR REPLACE TABLE loan_features AS
WITH window_txns AS (
    SELECT l.loan_id, t.*
    FROM loans l
    JOIN transactions t
      ON  t.account_id = l.account_id
      AND t.trans_date <  l.loan_date
      AND t.trans_date >= l.loan_date - INTERVAL 180 DAY
),
per_loan AS (
    SELECT
        loan_id,
        COUNT(*)                                                            AS txns_6m,
        AVG(balance_after_czk)                                              AS avg_balance,
        MIN(balance_after_czk)                                              AS min_balance,
        STDDEV_SAMP(balance_after_czk) / NULLIF(AVG(balance_after_czk), 0)  AS balance_cv,
        COUNT(*) FILTER (WHERE balance_after_czk < 0)                       AS negative_balance_txns,
        COUNT(*) FILTER (WHERE purpose = 'Penalty interest')                AS penalty_interest_charges,
        SUM(amount_czk) FILTER (WHERE direction = 'Credit') / 6.0           AS avg_monthly_inflow,
        SUM(amount_czk) FILTER (WHERE direction = 'Debit')  / 6.0           AS avg_monthly_outflow,
        SUM(amount_czk) FILTER (WHERE operation = 'Cash withdrawal')
            / NULLIF(SUM(amount_czk) FILTER (WHERE direction = 'Debit'), 0) AS cash_withdrawal_share
    FROM window_txns
    GROUP BY loan_id
)
SELECT
    l.loan_id, l.account_id, l.loan_date, l.amount_czk, l.duration_months, l.monthly_payment_czk,
    l.status, l.is_bad,
    p.txns_6m, p.avg_balance, p.min_balance, p.balance_cv,
    p.negative_balance_txns, p.penalty_interest_charges,
    p.avg_monthly_inflow, p.avg_monthly_outflow, p.cash_withdrawal_share,
    l.monthly_payment_czk / NULLIF(p.avg_monthly_inflow, 0)              AS payment_to_inflow_ratio,
    l.monthly_payment_czk / NULLIF(p.avg_balance, 0)                     AS payment_to_balance_ratio
FROM loans l
LEFT JOIN per_loan p USING (loan_id);

-- Compare good and bad loans on each signal (medians, because balances are skewed)
WITH long AS (
UNPIVOT (
    SELECT
        CASE WHEN is_bad THEN 'Bad loans' ELSE 'Good loans' END AS loan_group,
        COUNT(*)                                     AS loans,
        MEDIAN(avg_balance)                          AS median_avg_balance_czk,
        MEDIAN(min_balance)                          AS median_min_balance_czk,
        AVG((min_balance < 5000)::INT) * 100         AS pct_balance_fell_below_5k,
        AVG((negative_balance_txns > 0)::INT) * 100  AS pct_went_overdrawn,
        AVG((penalty_interest_charges > 0)::INT) * 100 AS pct_paid_penalty_interest,
        MEDIAN(avg_monthly_inflow)                   AS median_monthly_inflow_czk,
        MEDIAN(payment_to_inflow_ratio) * 100        AS median_payment_to_inflow_pct,
        MEDIAN(payment_to_balance_ratio) * 100       AS median_payment_to_balance_pct,
        MEDIAN(balance_cv)                           AS median_balance_volatility_cv,
        MEDIAN(cash_withdrawal_share) * 100          AS median_cash_withdrawal_share_pct
    FROM loan_features
    GROUP BY 1
)
ON COLUMNS(* EXCLUDE (loan_group))
INTO NAME signal VALUE value
)
PIVOT (SELECT signal, loan_group, ROUND(value, 2) AS value FROM long)
ON loan_group USING ANY_VALUE(value)
ORDER BY signal;
