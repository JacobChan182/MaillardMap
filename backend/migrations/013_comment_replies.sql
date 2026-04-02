alter table comments
  add column if not exists parent_id uuid references comments(id) on delete cascade;

create index if not exists idx_comments_parent_id on comments(parent_id);
