create table if not exists saved_places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, restaurant_id)
);

create index if not exists idx_saved_places_user_id on saved_places(user_id);
create index if not exists idx_saved_places_restaurant_id on saved_places(restaurant_id);
