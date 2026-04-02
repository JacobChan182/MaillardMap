alter table friendships
  add column if not exists accepted_at timestamptz;
