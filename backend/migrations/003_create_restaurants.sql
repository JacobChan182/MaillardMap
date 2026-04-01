create table if not exists restaurants (
  id uuid primary key default gen_random_uuid(),
  foursquare_id text not null unique,
  name text not null,
  lat double precision not null,
  lng double precision not null,
  cuisine text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_restaurants_foursquare_id on restaurants(foursquare_id);
create index if not exists idx_restaurants_lat_lng on restaurants(lat, lng);
create index if not exists idx_restaurants_name on restaurants using gin(to_tsvector('simple', name));
