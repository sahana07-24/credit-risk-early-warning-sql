-- 06 · A simple, explainable early-warning scorecard
-- Question: if the bank had applied a few plain rules at application time, how many bad loans
-- would it have caught, and how many good customers would it have wrongly flagged?
-- One point per warning sign; thresholds come from the good-vs-bad comparison in 05.

CREATE OR REPLACE TABLE loan_scores AS
SELECT
    *,
    (min_balance < 5000)::INT                         AS flag_low_min_balance,
    (avg_balance < 30000)::INT                        AS flag_low_avg_balance,
    (payment_to_balance_ratio > 0.15)::INT            AS flag_payment_high_vs_balance,
    (negative_balance_txns > 0)::INT                  AS flag_went_overdrawn,
    (min_balance < 5000)::INT + (avg_balance < 30000)::INT
      + (payment_to_balance_ratio > 0.15)::INT + (negative_balance_txns > 0)::INT AS risk_score
FROM loan_features;

WITH by_score AS (
    SELECT
        risk_score,
        COUNT(*)                     AS loans,
        SUM(is_bad::INT)             AS bad_loans
    FROM loan_scores
    GROUP BY risk_score
)
SELECT
    risk_score,
    loans,
    bad_loans,
    ROUND(100.0 * bad_loans / loans, 1)                                              AS bad_rate_pct,
    ROUND(100 * wilson_low(bad_loans::DOUBLE, loans), 1)                             AS ci_low_pct,
    ROUND(100 * wilson_high(bad_loans::DOUBLE, loans), 1)                            AS ci_high_pct,
    -- If the bank declined every loan at this score or higher:
    SUM(bad_loans) OVER (ORDER BY risk_score DESC)                                   AS bad_caught_if_cutoff_here,
    ROUND(100.0 * SUM(bad_loans) OVER (ORDER BY risk_score DESC) / SUM(bad_loans) OVER (), 1) AS recall_pct,
    ROUND(100.0 * SUM(bad_loans) OVER (ORDER BY risk_score DESC)
                / SUM(loans) OVER (ORDER BY risk_score DESC), 1)                     AS precision_pct,
    SUM(loans - bad_loans) OVER (ORDER BY risk_score DESC)                           AS good_customers_declined
FROM by_score
ORDER BY risk_score;
