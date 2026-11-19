SET search_path TO gpay;



-- R1: Show all users

SELECT user_id, full_name, phone, email
FROM users
ORDER BY user_id;

-- R2: Find one user by phone number

SELECT user_id, full_name, phone, email
FROM users
WHERE phone = '9876543210';

-- R3: Show a user's UPI IDs

SELECT v.vpa, v.is_active, u.full_name
FROM vpas AS v
JOIN users AS u ON u.user_id = v.user_id
WHERE u.user_id = 1;

-- R4: Show a user's bank accounts

SELECT u.full_name, b.bank_name, b.account_last4, b.account_type
FROM users AS u
JOIN bank_accounts AS b ON b.user_id = u.user_id
WHERE u.user_id = 1;

-- R5: Show transactions made from one UPI ID

SELECT txn_id, upi_ref, payee_vpa, amount, status, initiated_at
FROM transactions
WHERE payer_vpa = 'user@bank'
ORDER BY initiated_at DESC;

-- R6: Show merchant names with their city

SELECT m.merchant_name, c.city_name, c.state
FROM merchants AS m
JOIN cities AS c ON c.city_id = m.city_id
ORDER BY m.merchant_name;

-- R7: Show a user's bills

SELECT u.full_name, b.biller_name, b.amount, b.due_date, b.status
FROM bill_payments AS b
JOIN users AS u ON u.user_id = b.user_id
WHERE b.user_id = 1
ORDER BY b.due_date;

-- R8: Show a transaction's dispute details

SELECT d.dispute_id, d.reason, d.status, t.upi_ref, t.amount
FROM disputes AS d
JOIN transactions AS t ON t.txn_id = d.txn_id
WHERE d.txn_id = 1;



-- W1: Block a user

UPDATE users
SET is_blocked = TRUE
WHERE user_id = 1;

-- W2: Deactivate a UPI ID

UPDATE vpas
SET is_active = FALSE
WHERE vpa = 'user@bank';

-- W3: Mark a bill as paid
UPDATE bill_payments
SET status = 'PAID',
    paid_at = CURRENT_TIMESTAMP
WHERE bill_id = 1
  AND status IN ('DUE', 'OVERDUE');
