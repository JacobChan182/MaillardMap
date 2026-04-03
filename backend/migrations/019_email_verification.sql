-- Email confirmation (Resend). Existing accounts are treated as already verified.
alter table users add column if not exists email_verified_at timestamptz;
alter table users add column if not exists email_confirm_token_hash text;
alter table users add column if not exists email_confirm_expires_at timestamptz;

update users
set email_verified_at = coalesce(created_at, now())
where email_verified_at is null;
