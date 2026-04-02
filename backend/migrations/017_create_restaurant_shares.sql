create table restaurant_shares (
  id uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references users(id) on delete cascade,
  to_user_id uuid not null references users(id) on delete cascade,
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index restaurant_shares_to_user_created_idx on restaurant_shares (to_user_id, created_at desc);
