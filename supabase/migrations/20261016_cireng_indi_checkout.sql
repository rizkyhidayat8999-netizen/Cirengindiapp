-- Dedicated Cireng Indi checkout, callable only by the server-side service role.
create or replace function public.ci_checkout_cod(
  p_member_id uuid, p_fulfillment text,
  p_address_id uuid default null, p_courier_id uuid default null,
  p_notes text default null
) returns jsonb
language plpgsql security definer set search_path=public,pg_temp
as $$
declare
  c record; li record; v record; adr record; cr record;
  o record; subtotal_value integer := 0; shipping_value integer := 0;
  cart_uuid uuid; generated_number text;
begin
  if p_fulfillment not in ('delivery','pickup') then raise exception 'INVALID_FULFILLMENT'; end if;
  select id into cart_uuid from public.ci_carts where member_id=p_member_id for update;
  if cart_uuid is null then raise exception 'CART_EMPTY'; end if;
  if p_fulfillment='delivery' then
    if p_address_id is null then raise exception 'ADDRESS_REQUIRED'; end if;
    select * into adr from public.ci_addresses where id=p_address_id and member_id=p_member_id;
    if not found then raise exception 'ADDRESS_NOT_FOUND'; end if;
    if p_courier_id is not null then
      select * into cr from public.ci_couriers where id=p_courier_id and active;
      if not found then raise exception 'COURIER_NOT_FOUND'; end if;
      shipping_value := cr.flat_fee;
    end if;
  else
    p_address_id := null; p_courier_id := null;
  end if;
  for li in select * from public.ci_cart_items where cart_id=cart_uuid order by variant_id loop
    select v1.*,p.active as product_active into v
      from public.ci_product_variants v1 join public.ci_products p on p.id=v1.product_id
      where v1.id=li.variant_id for update of v1;
    if not found or not v.active or not v.product_active or v.stock<li.quantity then raise exception 'INSUFFICIENT_STOCK'; end if;
    subtotal_value := subtotal_value + v.price * li.quantity;
  end loop;
  if subtotal_value=0 then raise exception 'CART_EMPTY'; end if;
  generated_number := 'CI-'||to_char(clock_timestamp(),'YYYYMMDD')||'-'||lpad(nextval('public.ci_order_seq')::text,6,'0');
  insert into public.ci_orders(order_number,member_id,fulfillment_type,address_id,address_snapshot,courier_id,status,subtotal,shipping_fee,total,notes)
  values(generated_number,p_member_id,p_fulfillment,p_address_id,
    case when p_fulfillment='delivery' then jsonb_build_object('recipient_name',adr.recipient_name,'phone',adr.phone,'address_line',adr.address_line,'city',adr.city,'province',adr.province) else null end,
    p_courier_id,'pending',subtotal_value,shipping_value,subtotal_value+shipping_value,left(p_notes,500))
  returning * into o;
  for li in select * from public.ci_cart_items where cart_id=cart_uuid order by variant_id loop
    select v1.*,p.name as product_name into v from public.ci_product_variants v1 join public.ci_products p on p.id=v1.product_id where v1.id=li.variant_id;
    insert into public.ci_order_items(order_id,product_id,variant_id,product_name,variant_name,sku,unit_price,quantity,line_total)
    values(o.id,v.product_id,li.variant_id,v.product_name,v.name,v.sku,v.price,li.quantity,v.price*li.quantity);
    update public.ci_product_variants set stock=stock-li.quantity where id=li.variant_id;
  end loop;
  insert into public.ci_payments(order_id,method,status,amount) values(o.id,'cod','pending',o.total);
  delete from public.ci_cart_items where cart_id=cart_uuid;
  return to_jsonb(o);
end;
$$;
revoke all on function public.ci_checkout_cod(uuid,text,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.ci_checkout_cod(uuid,text,uuid,uuid,text) to service_role;