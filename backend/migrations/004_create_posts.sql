create table if not exists posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  comment text check (char_length(comment) <= 200),
  created_at timestamptz not null default now()
);

create index if not exists idx_posts_user_id on posts(user_id);
create index if not exists idx_posts_restaurant_id on posts(restaurant_id);
create index if not exists idx_posts_created_at on posts(created_at desc);
