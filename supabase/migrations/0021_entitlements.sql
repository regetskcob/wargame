-- Purchases the stores confirmed, one row per pilot and product (in-app
-- purchases, prepared but not live: see docs/purchases.md).
--
-- Only the edge function verify-purchase writes here, with the service
-- role, after Apple or Google confirmed the transaction. A client can read
-- its own rows and nothing else, so nobody can grant themselves a product.
-- A restore on another device (a new guest, another account) moves the
-- product to whoever asks with the store's proof: the store account is
-- what owns it, not the pilot row.

create table public.entitlements (
  player_id uuid not null references auth.users (id) on delete cascade,
  -- Product id without the bundle prefix, e.g. 'supporter'. The edge
  -- function keeps the list of products it grants.
  product text not null check (product ~ '^[a-z][a-z0-9_]{0,31}$'),
  store text not null check (store in ('app_store', 'play')),
  -- The store's id of the original purchase, so a restore finds the row.
  transaction_id text not null check (char_length(transaction_id) <= 128),
  granted_at timestamptz not null default now(),
  primary key (player_id, product)
);

create index entitlements_transaction on public.entitlements (store, transaction_id);

comment on table public.entitlements is 'Store purchases per pilot, written by verify-purchase';

alter table public.entitlements enable row level security;
revoke all on public.entitlements from public, anon, authenticated;
grant select on public.entitlements to authenticated;

create policy "Pilots read their own purchases"
  on public.entitlements for select
  to authenticated
  using ((select auth.uid()) = player_id);
