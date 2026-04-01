create table if not exists post_photos (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  url text not null,
  order_index integer not null check (order_index between 1 and 3),
  created_at timestamptz not null default now()
);

create index if not exists idx_post_photos_post_id on post_photos(post_id);
