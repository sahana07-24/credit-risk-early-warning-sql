-- 04 · Bad-loan rate by customer and loan segment, with 95% confidence intervals
-- Question: which kinds of loan and borrower go bad most often?
-- "Bad" = finished unpaid (B) or running in debt (D). With only 76 bad loans, segments are small,
-- so each rate carries a Wilson 95% interval: overlapping intervals mean the difference may be noise.

CREATE OR REPLACE MACRO wilson_low(k, n)  AS
    GREATEST(0, (k/n + 1.96^2/(2*n) - 1.96*sqrt(k/n*(1-k/n)/n + 1.96^2/(4*n^2))) / (1 + 1.96^2/n));
CREATE OR REPLACE MACRO wilson_high(k, n) AS
    (k/n + 1.96^2/(2*n) + 1.96*sqrt(k/n*(1-k/n)/n + 1.96^2/(4*n^2))) / (1 + 1.96^2/n);

WITH loan_facts AS (
    SELECT
        l.*,
        o.gender,
        DATE_DIFF('year', o.birth_date, l.loan_date)         AS age_at_loan,
        -- only cards issued BEFORE the loan count: a later card is not known at application time
        COALESCE((SELECT MAX(k.card_type) FROM cards k JOIN dispositions dp USING (disp_id)
                  WHERE dp.account_id = l.account_id AND k.issued_date < l.loan_date), 'No card') AS card_type,
        a.statement_frequency,
        d.region,
        d.unemployment_rate_96
    FROM loans l
    JOIN accounts a       USING (account_id)
    JOIN account_owners o USING (account_id)
    JOIN districts d      ON d.district_id = a.district_id
),
segments AS (
    SELECT 'Loan duration' AS dimension, duration_months || ' months' AS segment, is_bad, duration_months AS sort_key FROM loan_facts
    UNION ALL
    SELECT 'Loan amount',
           CASE WHEN amount_czk < 50000 THEN 'Under 50K'
                WHEN amount_czk < 150000 THEN '50K–150K'
                WHEN amount_czk < 300000 THEN '150K–300K'
                ELSE '300K+' END,
           is_bad,
           CASE WHEN amount_czk < 50000 THEN 1 WHEN amount_czk < 150000 THEN 2 WHEN amount_czk < 300000 THEN 3 ELSE 4 END
    FROM loan_facts
    UNION ALL
    SELECT 'Monthly payment',
           CASE WHEN monthly_payment_czk < 3000 THEN 'Under 3K'
                WHEN monthly_payment_czk < 6000 THEN '3K–6K'
                ELSE '6K+' END,
           is_bad,
           CASE WHEN monthly_payment_czk < 3000 THEN 1 WHEN monthly_payment_czk < 6000 THEN 2 ELSE 3 END
    FROM loan_facts
    UNION ALL
    SELECT 'Gender', gender, is_bad, 0 FROM loan_facts
    UNION ALL
    SELECT 'Age at loan',
           CASE WHEN age_at_loan < 30 THEN 'Under 30' WHEN age_at_loan < 45 THEN '30–44'
                WHEN age_at_loan < 60 THEN '45–59' ELSE '60+' END,
           is_bad,
           CASE WHEN age_at_loan < 30 THEN 1 WHEN age_at_loan < 45 THEN 2 WHEN age_at_loan < 60 THEN 3 ELSE 4 END
    FROM loan_facts
    UNION ALL
    SELECT 'Card held at loan date', card_type, is_bad, 0 FROM loan_facts
    UNION ALL
    SELECT 'Statement frequency', statement_frequency, is_bad, 0 FROM loan_facts
    UNION ALL
    SELECT 'Region', region, is_bad, 0 FROM loan_facts
    UNION ALL
    SELECT 'District unemployment (1996)',
           CASE WHEN unemployment_rate_96 < 2 THEN 'Under 2%' WHEN unemployment_rate_96 < 4 THEN '2–4%'
                WHEN unemployment_rate_96 >= 4 THEN '4%+' ELSE 'Unknown' END,
           is_bad,
           CASE WHEN unemployment_rate_96 < 2 THEN 1 WHEN unemployment_rate_96 < 4 THEN 2 ELSE 3 END
    FROM loan_facts
)
SELECT
    dimension,
    segment,
    COUNT(*)                                                    AS loans,
    SUM(is_bad::INT)                                            AS bad_loans,
    ROUND(100.0 * AVG(is_bad::INT), 1)                          AS bad_rate_pct,
    ROUND(100 * wilson_low(SUM(is_bad::INT)::DOUBLE, COUNT(*)), 1)  AS ci_low_pct,
    ROUND(100 * wilson_high(SUM(is_bad::INT)::DOUBLE, COUNT(*)), 1) AS ci_high_pct,
    ROUND(100.0 * AVG(is_bad::INT) / (SELECT AVG(is_bad::INT) FROM loans), 2) / 100 AS relative_risk
FROM segments
GROUP BY dimension, segment
ORDER BY dimension, MIN(sort_key), bad_rate_pct DESC;
