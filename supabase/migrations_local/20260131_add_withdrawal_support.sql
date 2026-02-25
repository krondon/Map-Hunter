-- 1. Add 'type' column to differentiate between DEPOSIT and WITHDRAWAL
alter table payment_transactions add column if not exists type text default 'DEPOSIT';

-- 2. Ensure profiles table has clovers column (just in case)
alter table profiles add column if not exists clovers numeric default 0;

-- 3. Update existing rows to have type='DEPOSIT' (if any)
update payment_transactions set type = 'DEPOSIT' where type is null;
