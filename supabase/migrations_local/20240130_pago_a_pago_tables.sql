create table if not exists payment_transactions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  order_id text unique not null,
  amount numeric not null,
  currency text not null,
  status text not null default 'pending', -- pending, completed, failed
  provider_data jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- RLS
alter table payment_transactions enable row level security;

create policy "Users can view their own transactions"
  on payment_transactions for select
  using (auth.uid() = user_id);

-- Function to handle timestamp update
create or replace function update_updated_at_column()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language 'plpgsql';

create trigger update_payment_transactions_updated_at
before update on payment_transactions
for each row
execute procedure update_updated_at_column();
