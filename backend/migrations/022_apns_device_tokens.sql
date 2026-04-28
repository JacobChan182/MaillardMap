create table if not exists apns_device_tokens (
  user_id uuid not null references users(id) on delete cascade,
  device_token text primary key,
  platform text not null default 'ios',
  environment text not null check (environment in ('sandbox', 'production')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index if not exists idx_apns_device_tokens_user_id on apns_device_tokens(user_id);
