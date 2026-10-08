-- Lets players delete their own account, guest or with e-mail, from inside
-- the game (App Store guideline 5.1.1(v)). Removing the auth user cascades to
-- scores, players, round_results and achievements, which all reference it
-- with on delete cascade.

create function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not signed in';
  end if;
  delete from auth.users where id = me;
end;
$$;

revoke execute on function public.delete_account from public, anon;
grant execute on function public.delete_account to authenticated;
