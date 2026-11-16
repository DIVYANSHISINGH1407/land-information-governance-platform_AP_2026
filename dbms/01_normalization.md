# Google Pay (UPI) Database Normalization

## 1. Introduction

This document analyzes the normalization of the Google Pay (UPI) Digital Payments Database.

The analysis is based on the actual PostgreSQL schema defined in `sql/01_schema.sql`, including its primary keys, unique constraints, foreign keys, and other constraints.

The database contains nine tables:

1. `cities`
2. `users`
3. `bank_accounts`
4. `vpas`
5. `merchants`
6. `transactions`
7. `rewards`
8. `bill_payments`
9. `disputes`

The purpose of normalization is to organize data efficiently, reduce unnecessary duplication, and prevent insertion, update, and deletion anomalies.

The database is evaluated against:

- First Normal Form (1NF)
- Second Normal Form (2NF)
- Third Normal Form (3NF)
- Boyce-Codd Normal Form (BCNF)

**Functional Dependency (FD):** A functional dependency `X → Y` means that if two rows have the same value of X, they must have the same value of Y.

A candidate key is a minimal set of attributes that uniquely identifies every row in a table. A primary key is the candidate key selected as the main identifier.

This document distinguishes between dependencies guaranteed by SQL constraints and additional business rules that may apply to the project.

## 2. Database Overview

The database consists of nine relations.

| Table | Primary Key | Other Candidate Keys | Main References |
|---|---|---|---|
| `cities` | `city_id` | None declared | — |
| `users` | `user_id` | `phone` | `city_id` → `cities` |
| `bank_accounts` | `account_id` | None | `user_id` → `users` |
| `vpas` | `vpa` | None | `user_id` → `users`; `(account_id, user_id)` → `bank_accounts` |
| `merchants` | `merchant_id` | `merchant_vpa` | `city_id` → `cities` |
| `transactions` | `txn_id` | `upi_ref` | `payer_vpa` → `vpas`; `(merchant_id, payee_vpa)` → `merchants` |
| `rewards` | `reward_id` | None | `user_id` → `users`; `txn_id` → `transactions` |
| `bill_payments` | `bill_id` | None | `user_id` → `users` |
| `disputes` | `dispute_id` | None | `txn_id` → `transactions`; `raised_by` → `users` |

### Important observations

- All nine tables have single-column primary keys.
- `users.phone` is NOT NULL and UNIQUE, so it is an alternate candidate key.
- `merchants.merchant_vpa` is NOT NULL and UNIQUE, so it is an alternate candidate key.
- `transactions.upi_ref` is NOT NULL and UNIQUE, so it is an alternate candidate key.
- `users.email` is UNIQUE but nullable. Since PostgreSQL permits multiple NULL values in a UNIQUE column, it is not an unconditional candidate key.
- `bank_accounts(account_id, user_id)` is a composite UNIQUE constraint, but it is not a minimal candidate key because `account_id` is already the primary key.
- `merchants(merchant_id, merchant_vpa)` is also not a minimal candidate key because `merchant_id` is already the primary key and `merchant_vpa` is independently unique.
- There is no UNIQUE constraint on `rewards.txn_id`, `disputes.txn_id`, `vpas.account_id`, or `bill_payments.consumer_number`.

Therefore, the schema does not enforce one reward per transaction, one dispute per transaction, one VPA per bank account, or a unique consumer number.

## 3. Functional Dependencies

The following functional dependencies are guaranteed by the declared primary keys and alternate candidate keys.

| Table | Functional Dependencies |
|---|---|
| `cities` | `city_id → city_name, state` |
| `users` | `user_id → all other attributes`; `phone → all other attributes` |
| `bank_accounts` | `account_id → all other attributes` |
| `vpas` | `vpa → user_id, account_id, is_active, created_at` |
| `merchants` | `merchant_id → all other attributes`; `merchant_vpa → all other attributes` |
| `transactions` | `txn_id → all other attributes`; `upi_ref → all other attributes` |
| `rewards` | `reward_id → all other attributes` |
| `bill_payments` | `bill_id → all other attributes` |
| `disputes` | `dispute_id → all other attributes` |

### Additional dependencies arising from relationships

**1. VPA and bank account ownership**

In `bank_accounts`, `account_id` is the primary key and determines `user_id`.

The `vpas` table has a composite foreign key:

`(account_id, user_id) → bank_accounts(account_id, user_id)`

Therefore, for VPA records:

`account_id → user_id`

This dependency is enforced through the composite foreign key. However, `account_id` is not unique in `vpas`, so it is not a candidate key of that table.

**2. Merchant and transaction relationship**

For P2M transactions, the merchant's VPA is the transaction's payee VPA.

The composite foreign key:

`(merchant_id, payee_vpa) → merchants(merchant_id, merchant_vpa)`

ensures that the merchant ID and payee VPA match an existing merchant record.

This gives the conditional dependency:

`merchant_id → payee_vpa` for P2M transactions only.

It must not be treated as an unconditional dependency for the complete transactions table because P2P transactions have no merchant ID and may have external recipients.

**3. Reward and transaction relationship**

The project may require `rewards.user_id` to identify the owner of the payer VPA for the associated transaction.

Under this business rule:

`txn_id → user_id`

However, the SQL schema does not enforce this equality. It only checks separately that `user_id` references an existing user and `txn_id` references an existing transaction.

Therefore, this dependency is a business-rule dependency, not one guaranteed by the declared foreign keys.

## 4. Table-wise Normalization Analysis

### 4.1 cities

**Attributes:** `city_id`, `city_name`, `state`

**Primary Key:** `city_id`

**Functional Dependency:**

`city_id → city_name, state`

- **1NF:** Yes. All attributes contain single, atomic values.
- **2NF:** Yes. The primary key consists of one attribute, so no partial dependency exists.
- **3NF:** Yes. Both non-key attributes depend directly on the primary key. No transitive dependency is identified.
- **BCNF:** Yes. The only identified non-trivial determinant is `city_id`, which is a candidate key.

**Conclusion:** The `cities` table satisfies 1NF, 2NF, 3NF, and BCNF.

### 4.2 users

**Attributes:** `user_id`, `full_name`, `phone`, `email`, `city_id`, `kyc_status`, `is_blocked`, `created_at`

**Primary Key:** `user_id`

**Alternate Candidate Key:** `phone`

**Functional Dependencies:**

`user_id → full_name, phone, email, city_id, kyc_status, is_blocked, created_at`

`phone → all other user attributes`

- **1NF:** Yes. Each attribute stores a single value. Email is optional but still contains at most one value.
- **2NF:** Yes. Both candidate keys are single attributes, so partial dependencies cannot exist.
- **3NF:** Yes. No non-key attribute is identified as determining another non-key attribute. City information is stored separately in the `cities` table and referenced through `city_id`.
- **BCNF:** Yes. The identified non-trivial determinants, `user_id` and `phone`, are candidate keys.

**Note:** `email` is nullable and UNIQUE. It is unique when populated, but it is not an unconditional candidate key.

**Conclusion:** The `users` table satisfies 1NF, 2NF, 3NF, and BCNF.

### 4.3 bank_accounts

**Attributes:** `account_id`, `user_id`, `bank_name`, `ifsc`, `account_last4`, `account_type`, `is_primary`, `linked_at`

**Primary Key:** `account_id`

**Functional Dependency:**

`account_id → user_id, bank_name, ifsc, account_last4, account_type, is_primary, linked_at`

- **1NF:** Yes. All attributes contain atomic values.
- **2NF:** Yes. The primary key is a single attribute.
- **3NF:** Yes. No transitive dependency among non-key attributes is identified by the declared schema.
- **BCNF:** Yes. The identified non-trivial determinant is `account_id`, which is a candidate key.

The composite UNIQUE constraint on `(account_id, user_id)` is redundant for candidate-key identification because `account_id` alone is already unique.

**Conclusion:** The `bank_accounts` table satisfies 1NF, 2NF, 3NF, and BCNF.

### 4.4 vpas

**Attributes:** `vpa`, `user_id`, `account_id`, `is_active`, `created_at`

**Primary Key:** `vpa`

**Functional Dependencies:**

`vpa → user_id, account_id, is_active, created_at`

Additionally:

`account_id → user_id`

This second dependency follows from the composite foreign key referencing `bank_accounts(account_id, user_id)`.

- **1NF:** Yes. Each attribute stores a single value.
- **2NF:** Yes. The primary key is a single attribute, so no partial dependency exists.
- **3NF:** No. There is a transitive dependency:

  `vpa → account_id → user_id`

  Here, `account_id` is a non-key attribute in the `vpas` table and determines another non-key attribute, `user_id`.

- **BCNF:** No. `account_id` determines `user_id`, but `account_id` is not a superkey of the `vpas` table because multiple VPAs may reference the same bank account.

The composite foreign key ensures that the VPA's user ID matches the owner of its linked bank account. It does not make `account_id` unique in `vpas`.

**Conclusion:** The `vpas` table satisfies 1NF and 2NF but does not satisfy 3NF or BCNF under the ownership dependency.

### 4.5 merchants

**Attributes:** `merchant_id`, `merchant_name`, `mcc`, `merchant_vpa`, `city_id`, `is_verified`, `onboarded_on`

**Primary Key:** `merchant_id`

**Alternate Candidate Key:** `merchant_vpa`

**Functional Dependencies:**

`merchant_id → merchant_name, mcc, merchant_vpa, city_id, is_verified, onboarded_on`

`merchant_vpa → all other merchant attributes`

- **1NF:** Yes. All attributes contain atomic values.
- **2NF:** Yes. Both candidate keys are single attributes.
- **3NF:** Yes. No non-key attribute is identified as determining another non-key attribute.
- **BCNF:** Yes. Both identified non-trivial determinants are candidate keys.

The composite UNIQUE constraint on `(merchant_id, merchant_vpa)` is not a minimal candidate key because both attributes are independently unique.

**Conclusion:** The `merchants` table satisfies 1NF, 2NF, 3NF, and BCNF.

### 4.6 transactions

**Attributes:** `txn_id`, `upi_ref`, `txn_type`, `payer_vpa`, `payee_vpa`, `merchant_id`, `amount`, `note`, `initiated_at`, `completed_at`, `status`, `failure_code`

**Primary Key:** `txn_id`

**Alternate Candidate Key:** `upi_ref`

**Functional Dependencies:**

`txn_id → all other transaction attributes`

`upi_ref → all other transaction attributes`

For P2M transactions only:

`merchant_id → payee_vpa`

- **1NF:** Yes. Each attribute stores one value. Optional fields such as `note`, `completed_at`, and `failure_code` contain either one value or NULL.
- **2NF:** Yes. Both candidate keys are single attributes.
- **3NF:** Yes, based on the unconditional functional dependencies guaranteed by the schema. The P2M-only merchant dependency is conditional and cannot be treated as an unconditional functional dependency of the entire transactions relation.
- **BCNF:** Yes, based on the unconditional functional dependencies guaranteed by the schema. The P2M-specific dependency does not establish a global BCNF violation for the complete table.

**Important design consideration:**

For P2M transactions, the payee VPA is already stored in the merchant record. Storing it again in `transactions` repeats information.

The composite foreign key `(merchant_id, payee_vpa)` ensures that the merchant and payee VPA match for P2M transactions. This prevents an inconsistent merchant/payee combination.

For P2P transactions, `merchant_id` is NULL and the recipient VPA may belong to an external user. Therefore, the same merchant dependency does not apply.

**Conclusion:** The `transactions` table satisfies 1NF, 2NF, 3NF, and BCNF based on the unconditional dependencies of the complete relation. The P2M subset has an additional conditional dependency and repeated recipient information.

### 4.7 rewards

**Attributes:** `reward_id`, `user_id`, `txn_id`, `reward_type`, `amount`, `status`, `issued_at`, `expires_at`, `credited_at`

**Primary Key:** `reward_id`

**Functional Dependency:**

`reward_id → user_id, txn_id, reward_type, amount, status, issued_at, expires_at, credited_at`

- **1NF:** Yes. Each attribute stores a single value.
- **2NF:** Yes. The primary key is a single attribute.
- **3NF:** Yes, based on the functional dependencies guaranteed by the declared SQL constraints. No additional non-key determinant is enforced by the schema.
- **BCNF:** Yes, based on the declared SQL constraints. The only identified non-trivial determinant is `reward_id`, which is a candidate key.

**Important business-rule consideration:**

The project may require `rewards.user_id` to match the owner of the payer VPA for the associated transaction.

If this rule is guaranteed by the application or project requirements, then:

`txn_id → user_id`

This would create a transitive dependency:

`reward_id → txn_id → user_id`

Under that additional business rule, the rewards table would not satisfy 3NF or BCNF because `txn_id` is not a superkey of `rewards`. The SQL schema does not independently enforce this relationship.

There is also no UNIQUE constraint on `txn_id`, so multiple rewards can reference the same transaction.

**Conclusion:** The `rewards` table satisfies 1NF, 2NF, 3NF, and BCNF based on declared SQL constraints. If the project-level payer-owner dependency is guaranteed, it has an additional 3NF and BCNF issue.

### 4.8 bill_payments

**Attributes:** `bill_id`, `user_id`, `biller_category`, `biller_name`, `consumer_number`, `amount`, `due_date`, `status`, `paid_at`

**Primary Key:** `bill_id`

**Functional Dependency:**

`bill_id → user_id, biller_category, biller_name, consumer_number, amount, due_date, status, paid_at`

- **1NF:** Yes. All attributes contain single, atomic values.
- **2NF:** Yes. The primary key is a single attribute.
- **3NF:** Yes. No non-key attribute is identified as determining another non-key attribute.
- **BCNF:** Yes. The identified non-trivial determinant is `bill_id`, which is a candidate key.

The schema does not declare `consumer_number` as UNIQUE. Therefore, it is not assumed to be a candidate key.

**Conclusion:** The `bill_payments` table satisfies 1NF, 2NF, 3NF, and BCNF.

### 4.9 disputes

**Attributes:** `dispute_id`, `txn_id`, `raised_by`, `reason`, `raised_at`, `status`, `resolved_at`

**Primary Key:** `dispute_id`

**Functional Dependency:**

`dispute_id → txn_id, raised_by, reason, raised_at, status, resolved_at`

- **1NF:** Yes. All attributes contain single, atomic values.
- **2NF:** Yes. The primary key is a single attribute.
- **3NF:** Yes. No non-key attribute is identified as determining another non-key attribute.
- **BCNF:** Yes. The identified non-trivial determinant is `dispute_id`, which is a candidate key.

There is no UNIQUE constraint on `txn_id`, so multiple disputes may reference the same transaction.

**Conclusion:** The `disputes` table satisfies 1NF, 2NF, 3NF, and BCNF.

## 5. Possible Redundant Attributes and Design Considerations

The project schema contains some attributes that repeat information available through related tables.

These attributes are discussed below.

### 5.1 rewards.user_id and the payer of rewards.txn_id

The `rewards` table contains both `user_id` and `txn_id`.

The transaction table contains `payer_vpa`, and the VPA table identifies the VPA owner through `user_id`.

Therefore, the reward user can be derived by joining:

`rewards → transactions → vpas`

If the business rule states that a reward belongs to the payer of its associated transaction, storing `rewards.user_id` repeats that ownership information.

**Possible problem:**

If `rewards.user_id` does not match the owner of the transaction's payer VPA, the database could contain inconsistent information.

**Current schema behavior:**

- `rewards.user_id` references `users`.
- `rewards.txn_id` references `transactions`.
- There is no constraint enforcing equality between the reward user and transaction payer owner.

**Decision:** The column is retained because it is part of the existing project schema and supports direct user-based reward queries. Application logic or data validation should ensure that the relationship remains consistent.

### 5.2 transactions.payee_vpa and merchants.merchant_vpa

For P2M transactions, the merchant's VPA is also the payee VPA.

The `transactions` table stores `payee_vpa`, while the `merchants` table already stores `merchant_vpa`.

This repeats merchant recipient information for P2M transactions.

**Possible problem:**

Without suitable constraints, a transaction could reference a merchant but contain a different payee VPA.

**Current schema behavior:**

The composite foreign key:

`(merchant_id, payee_vpa) → merchants(merchant_id, merchant_vpa)`

ensures that the merchant and payee VPA match.

The `transactions_type_merchant_match` CHECK constraint also ensures that:

- P2M transactions have a merchant ID.
- P2P transactions do not have a merchant ID.

**Decision:** The `payee_vpa` column is retained because it records the recipient directly in the transaction. It is also necessary for P2P transactions, where the recipient may be external and not registered as a local VPA.

### 5.3 vpas.user_id and bank_accounts.user_id

Both `vpas` and `bank_accounts` contain `user_id`.

A VPA is linked to a bank account, and that bank account already identifies its owner.

Therefore, the same ownership information is represented in both tables.

**Possible problem:**

If the VPA owner and bank account owner differ, the database could contain inconsistent ownership information.

**Current schema behavior:**

The composite foreign key:

`(account_id, user_id) → bank_accounts(account_id, user_id)`

ensures that the VPA's account ID and user ID match the bank account's owner.

The direct foreign key on `vpas.user_id` also ensures that the user exists.

**Decision:** The `user_id` column is retained because it is part of the existing project design and makes VPA ownership directly available.

The composite foreign key prevents an ownership mismatch. However, `account_id` is not unique in `vpas`, so multiple VPAs can still reference the same bank account.

## 6. Overall Normalization Summary

The following table summarizes normalization based on the functional dependencies guaranteed by the declared SQL schema.

| Table | 1NF | 2NF | 3NF | BCNF |
|---|---|---|---|---|
| `cities` | Yes | Yes | Yes | Yes |
| `users` | Yes | Yes | Yes | Yes |
| `bank_accounts` | Yes | Yes | Yes | Yes |
| `vpas` | Yes | Yes | No | No |
| `merchants` | Yes | Yes | Yes | Yes |
| `transactions` | Yes | Yes | Yes | Yes |
| `rewards` | Yes | Yes | Yes | Yes |
| `bill_payments` | Yes | Yes | Yes | Yes |
| `disputes` | Yes | Yes | Yes | Yes |

### Additional business-rule considerations

The following dependencies can change the normalization conclusions if they are guaranteed by the project's business rules:

| Table | Additional Dependency | Possible Effect |
|---|---|---|
| `transactions` (P2M subset) | `merchant_id → payee_vpa` | The P2M subset has a non-key determinant. |
| `rewards` | `txn_id → user_id` | The rewards table would have a transitive dependency and fail 3NF and BCNF. |

The `vpas` dependency:

`account_id → user_id`

is already guaranteed through the composite foreign key and therefore is included in the main normalization summary.

## 7. Conclusion

The Google Pay database schema contains nine tables, each with a primary key and appropriate relationships through foreign keys.

All nine tables satisfy First Normal Form (1NF) because their attributes store atomic values.

All nine tables satisfy Second Normal Form (2NF) because their candidate keys are single-column keys, so partial dependencies cannot occur.

Based on the functional dependencies guaranteed by the declared SQL schema:

- Eight tables satisfy 3NF and BCNF.
- The `vpas` table does not satisfy 3NF or BCNF because `account_id → user_id` is a non-key dependency.

The project also contains additional business-rule considerations involving rewards and P2M transactions. These may introduce further normalization issues if the corresponding dependencies are guaranteed by the application or project requirements.

The database retains certain repeated attributes because they support the existing project requirements and query workload. Foreign-key constraints are used to prevent important inconsistencies, particularly in VPA ownership and P2M merchant/payee relationships.

Overall, the schema provides a structured relational design while preserving the data and relationships required by the Google Pay project.