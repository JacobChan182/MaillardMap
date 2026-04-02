alter table users
  add column if not exists display_name text,
  add column if not exists avatar_url text;

alter table users drop constraint if exists users_display_name_len;

alter table users
  add constraint users_display_name_len check (
    display_name is null
    or (char_length(trim(display_name)) >= 1 and char_length(display_name) <= 50)
  );
