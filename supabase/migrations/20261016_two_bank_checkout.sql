-- Cireng Indi: two verified recipient accounts, member selection and per-order immutable snapshot.
-- Keep legacy ci_checkout for compatibility with previously installed clients.
INSERT INTO public.ci_app_settings(key,value)
VALUES('bank_transfer',jsonb_build_object(
  'enabled',true,'bank_name','BSI','account_number','7306336217','account_holder','Intan Istiqomah',
  'accounts',jsonb_build_array(
    jsonb_build_object('code','BSI','bank_name','BSI','account_number','7306336217','account_holder','Intan Istiqomah','enabled',true,'sort_order',1),
    jsonb_build_object('code','BRI','bank_name','BRI','account_number','457901008978533','account_holder','Intan Istiqomah','enabled',true,'sort_order',2)
  )
)) ON CONFLICT(key) DO UPDATE SET value=EXCLUDED.value,updated_at=now();
INSERT INTO public.ci_app_settings(key,value)
VALUES('payment_methods','{"cod":true,"qris":false,"transfer":true}'::jsonb)
ON CONFLICT(key) DO UPDATE SET value=EXCLUDED.value,updated_at=now();
CREATE OR REPLACE FUNCTION public.ci_checkout_with_bank(
 p_member_id uuid,p_fulfillment text,p_payment_method text,
 p_address_id uuid DEFAULT NULL,p_notes text DEFAULT NULL,p_bank_code text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE li record; v record; adr record; o record; total_value integer:=0;
  cart_uuid uuid; generated_number text; bank jsonb; selected_bank jsonb;
BEGIN
 IF p_fulfillment NOT IN ('delivery','pickup') THEN RAISE EXCEPTION 'INVALID_FULFILLMENT'; END IF;
 IF p_payment_method NOT IN ('cod','transfer') THEN RAISE EXCEPTION 'INVALID_PAYMENT_METHOD'; END IF;
 IF p_payment_method='transfer' THEN
   SELECT value INTO bank FROM public.ci_app_settings WHERE key='bank_transfer';
   IF COALESCE((bank->>'enabled')::boolean,false) IS NOT TRUE THEN
     RAISE EXCEPTION 'TRANSFER_NOT_CONFIGURED';
   END IF;
   SELECT account INTO selected_bank FROM jsonb_array_elements(
     CASE WHEN jsonb_typeof(bank->'accounts')='array' THEN bank->'accounts'
          ELSE jsonb_build_array(bank) END
   ) AS account
   WHERE coalesce((account->>'enabled')::boolean,true)
     AND (p_bank_code IS NULL OR upper(account->>'code')=upper(p_bank_code)
         OR upper(account->>'bank_name')=upper(p_bank_code))
   ORDER BY coalesce((account->>'sort_order')::int,0)
   LIMIT 1;
   IF selected_bank IS NULL OR coalesce(selected_bank->>'bank_name','')='' OR
      coalesce(selected_bank->>'account_number','')='' OR
      coalesce(selected_bank->>'account_holder','')='' THEN
     RAISE EXCEPTION 'INVALID_BANK_SELECTION';
   END IF;
   selected_bank:=jsonb_build_object('code',coalesce(selected_bank->>'code',selected_bank->>'bank_name'),
     'bank_name',selected_bank->>'bank_name','account_number',selected_bank->>'account_number',
     'account_holder',selected_bank->>'account_holder');
 END IF;
 SELECT id INTO cart_uuid FROM public.ci_carts WHERE member_id=p_member_id FOR UPDATE;
 IF cart_uuid IS NULL THEN RAISE EXCEPTION 'CART_EMPTY'; END IF;
 IF p_fulfillment='delivery' THEN
   IF p_address_id IS NULL THEN RAISE EXCEPTION 'ADDRESS_REQUIRED'; END IF;
   SELECT * INTO adr FROM public.ci_addresses WHERE id=p_address_id AND member_id=p_member_id;
   IF NOT FOUND THEN RAISE EXCEPTION 'ADDRESS_NOT_FOUND'; END IF;
 ELSE p_address_id:=NULL; END IF;
 FOR li IN SELECT * FROM public.ci_cart_items WHERE cart_id=cart_uuid ORDER BY variant_id LOOP
  SELECT x.*,p.active AS product_active INTO v FROM public.ci_product_variants x
   JOIN public.ci_products p ON p.id=x.product_id WHERE x.id=li.variant_id FOR UPDATE OF x;
  IF NOT FOUND OR NOT v.active OR NOT v.product_active OR v.stock<li.quantity THEN RAISE EXCEPTION 'INSUFFICIENT_STOCK'; END IF;
  total_value:=total_value+v.price*li.quantity;
 END LOOP;
 IF total_value<=0 THEN RAISE EXCEPTION 'CART_EMPTY'; END IF;
 generated_number:='CI-'||to_char(clock_timestamp(),'YYYYMMDD')||'-'||lpad(nextval('public.ci_order_seq')::text,6,'0');
 INSERT INTO public.ci_orders(order_number,member_id,fulfillment_type,address_id,address_snapshot,courier_id,status,subtotal,shipping_fee,total,notes)
 VALUES(generated_number,p_member_id,p_fulfillment,p_address_id,
   CASE WHEN p_fulfillment='delivery' THEN jsonb_build_object('recipient_name',adr.recipient_name,'phone',adr.phone,'address_line',adr.address_line,'city',adr.city,'province',adr.province) ELSE null END,
   null,'pending',total_value,0,total_value,left(coalesce(p_notes,''),500)) RETURNING * INTO o;
 FOR li IN SELECT * FROM public.ci_cart_items WHERE cart_id=cart_uuid ORDER BY variant_id LOOP
  SELECT x.*,p.name AS product_name INTO v FROM public.ci_product_variants x
   JOIN public.ci_products p ON p.id=x.product_id WHERE x.id=li.variant_id;
  INSERT INTO public.ci_order_items(order_id,product_id,variant_id,product_name,variant_name,sku,unit_price,quantity,line_total)
  VALUES(o.id,v.product_id,li.variant_id,v.product_name,v.name,v.sku,v.price,li.quantity,v.price*li.quantity);
  UPDATE public.ci_product_variants SET stock=stock-li.quantity WHERE id=li.variant_id;
 END LOOP;
 INSERT INTO public.ci_payments(order_id,method,status,amount,bank_snapshot) VALUES(o.id,p_payment_method,'pending',o.total,selected_bank);
 DELETE FROM public.ci_cart_items WHERE cart_id=cart_uuid;
 RETURN to_jsonb(o);
END;$$;
REVOKE ALL ON FUNCTION public.ci_checkout_with_bank(uuid,text,text,uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ci_checkout_with_bank(uuid,text,text,uuid,text,text) TO service_role;
