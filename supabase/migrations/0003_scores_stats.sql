alter table public.scores
  add column rounds integer not null default 0,
  add column kills integer not null default 0,
  add column damage integer not null default 0,
  add column shots integer not null default 0,
  add column hits integer not null default 0,
  add column survival_seconds integer not null default 0;
