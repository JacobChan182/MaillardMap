-- Visit rating per post (0.5–5 stars in half-star steps). Nullable for legacy rows.
alter table posts
  add column if not exists rating numeric(2,1);

alter table posts drop constraint if exists posts_rating_half_star;
alter table posts
  add constraint posts_rating_half_star check (
    rating is null
    or (
      rating >= 0.5
      and rating <= 5.0
      and mod((rating * 10)::integer, 5) = 0
    )
  );
