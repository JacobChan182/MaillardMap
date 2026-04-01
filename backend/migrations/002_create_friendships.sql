create table if not exists friendships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  friend_id uuid not null references users(id) on delete cascade,
  status text not null check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  unique (user_id, friend_id)
);

create index if not exists idx_friendships_user_id on friendships(user_id);
create index if not exists idx_friendships_friend_id on friendships(friend_id);
create index if not exists idx_friendships_status on friendships(status);
