create table if not exists dismissed_notifications (
  user_id uuid not null references users(id) on delete cascade,
  notification_id text not null,
  dismissed_at timestamptz not null default now(),
  primary key (user_id, notification_id)
);

create index if not exists idx_dismissed_notifications_user_id on dismissed_notifications(user_id);
