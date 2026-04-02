alter table users
  add column if not exists bio text;

alter table users drop constraint if exists users_bio_len;

alter table users
  add constraint users_bio_len check (
    bio is null
    or (char_length(trim(bio)) >= 1 and char_length(bio) <= 200)
  );
