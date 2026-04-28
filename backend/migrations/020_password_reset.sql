-- Password reset via one-time email link.
alter table users add column if not exists password_reset_token_hash text;
alter table users add column if not exists password_reset_expires_at timestamptz;
