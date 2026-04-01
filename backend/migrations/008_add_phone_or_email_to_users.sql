alter table users add column if not exists phone_or_email text;
create unique index if not exists users_phone_or_email_uniq on users (phone_or_email) where phone_or_email is not null;
