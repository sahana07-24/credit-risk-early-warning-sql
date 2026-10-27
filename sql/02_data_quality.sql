-- 02 · Data quality checks
-- Question: can the tables be trusted and joined safely? Each row is one check; "issues" should be 0
-- unless the note explains why not.

SELECT 'Loans whose account does not exist'      AS check_name,
       COUNT(*) AS issues, 'Every loan must join to an account' AS note
FROM loans l LEFT JOIN accounts a USING (account_id) WHERE a.account_id IS NULL
UNION ALL
SELECT 'Accounts with more than one loan', COUNT(*), 'Bank rule: max one loan per account'
FROM (SELECT account_id FROM loans GROUP BY 1 HAVING COUNT(*) > 1)
UNION ALL
SELECT 'Accounts without exactly one owner', COUNT(*), 'Owner join must not duplicate rows'
FROM (SELECT a.account_id FROM accounts a LEFT JOIN dispositions d
        ON d.account_id = a.account_id AND d.role = 'Owner'
      GROUP BY 1 HAVING COUNT(d.disp_id) <> 1)
UNION ALL
SELECT 'Loans issued before the account was opened', COUNT(*), 'Time order must be valid'
FROM loans l JOIN accounts a USING (account_id) WHERE l.loan_date < a.opened_date
UNION ALL
SELECT 'Loan payment x duration differs from amount by > 1 CZK', COUNT(*), 'Checks the loan terms add up'
FROM loans WHERE abs(monthly_payment_czk * duration_months - amount_czk) > 1
UNION ALL
SELECT 'Transactions with unknown operation (interest / other)', COUNT(*), 'Expected: blank operation = interest'
FROM transactions WHERE operation = 'Interest / other'
UNION ALL
SELECT 'Transactions leaving a negative balance', COUNT(*), 'Real overdrafts, used as a risk signal'
FROM transactions WHERE balance_after_czk < 0
UNION ALL
SELECT 'Districts with missing 1996 unemployment rate', COUNT(*), 'Source has "?" only in 1995 columns, so 1996 figures are used'
FROM districts WHERE unemployment_rate_96 IS NULL;
