-- Restrict application RPCs to authenticated users and keep trigger hooks private.
-- This changes privileges only; it does not alter rows or table contents.

revoke all on function public.ensure_my_saki_id() from public, anon;
grant execute on function public.ensure_my_saki_id() to authenticated;

revoke all on function public.get_my_wallet() from public, anon;
grant execute on function public.get_my_wallet() to authenticated;

revoke all on function public.claim_free_gold() from public, anon;
grant execute on function public.claim_free_gold() to authenticated;

revoke all on function public.convert_diamonds_to_gold(bigint) from public, anon;
grant execute on function public.convert_diamonds_to_gold(bigint) to authenticated;

revoke all on function public.create_topup_order(text) from public, anon;
grant execute on function public.create_topup_order(text) to authenticated;

revoke all on function public.send_room_gift(uuid, uuid, text, integer) from public, anon;
grant execute on function public.send_room_gift(uuid, uuid, text, integer) to authenticated;

revoke all on function public.room_gift_rankings(uuid, text) from public, anon;
grant execute on function public.room_gift_rankings(uuid, text) to authenticated;

revoke all on function public.handle_new_user_profile() from public, anon, authenticated;
revoke all on function public.rls_auto_enable() from public, anon, authenticated;
revoke all on function public.touch_moment_counts() from public, anon, authenticated;
