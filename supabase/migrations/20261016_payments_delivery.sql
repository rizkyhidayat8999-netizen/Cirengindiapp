-- Cireng Indi: transfer proof, owner review, and owner-managed delivery.
ALTER TABLE public.ci_payments DROP CONSTRAINT IF EXISTS ci_payments_method_check;
ALTER TABLE public.ci_payments ADD CONSTRAINT ci_payments_method_check CHECK (method IN ('cod','transfer'));
ALTER TABLE public.ci_payments DROP CONSTRAINT IF EXISTS ci_payments_status_check;
ALTER TABLE public.ci_payments ADD CONSTRAINT ci_payments_status_check CHECK (status IN ('pending','submitted','paid','rejected','cancelled'));
ALTER TABLE public.ci_payments ADD COLUMN IF NOT EXISTS proof_storage_path text;
ALTER TABLE public.ci_payments ADD COLUMN IF NOT EXISTS proof_file_type text;
ALTER TABLE public.ci_payments ADD COLUMN IF NOT EXISTS proof_submitted_at timestamptz;
ALTER TABLE public.ci_payments ADD COLUMN IF NOT EXISTS review_note text;
ALTER TABLE public.ci_payments ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.ci_payments ADD COLUMN IF NOT EXISTS reviewed_at timestamptz;
INSERT INTO public.ci_app_settings(key,value) VALUES
 ('bank_transfer','{"enabled":false,"bank_name":"","account_number":"","account_holder":""}'::jsonb)
 ON CONFLICT(key) DO NOTHING;
-- Private bucket: no public read; only Edge Functions with service role can provide signed URLs.
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES('ci-payment-proofs','ci-payment-proofs',false,3145728,ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT(id) DO UPDATE SET public=false,file_size_limit=3145728,allowed_mime_types=EXCLUDED.allowed_mime_types;

CREATE OR REPLACE FUNCTION public.ci_checkout(
 p_member_id uuid,p_fulfillment text,p_payment_method text,
 p_address_id uuid DEFAULT NULL,p_notes text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE li record; v record; adr record; o record; total_value integer:=0;
  cart_uuid uuid; generated_number text; bank jsonb;
BEGIN
 IF p_fulfillment NOT IN ('delivery','pickup') THEN RAISE EXCEPTION 'INVALID_FULFILLMENT'; END IF;
 IF p_payment_method NOT IN ('cod','transfer') THEN RAISE EXCEPTION 'INVALID_PAYMENT_METHOD'; END IF;
 IF p_payment_method='transfer' THEN
   SELECT value INTO bank FROM public.ci_app_settings WHERE key='bank_transfer';
   IF COALESCE((bank->>'enabled')::boolean,false) IS NOT TRUE OR
      coalesce(bank->>'account_number','')='' OR coalesce(bank->>'bank_name','')='' OR coalesce(bank->>'account_holder','')='' THEN
     RAISE EXCEPTION 'TRANSFER_NOT_CONFIGURED';
   END IF;
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
 INSERT INTO public.ci_payments(order_id,method,status,amount) VALUES(o.id,p_payment_method,'pending',o.total);
 DELETE FROM public.ci_cart_items WHERE cart_id=cart_uuid;
 RETURN to_jsonb(o);
END;$$;
REVOKE ALL ON FUNCTION public.ci_checkout(uuid,text,text,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ci_checkout(uuid,text,text,uuid,text) TO service_role;

CREATE OR REPLACE FUNCTION public.ci_cancel_order_safe(p_order_id uuid,p_member_id uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE o record; p record; li record;
BEGIN
 SELECT * INTO o FROM public.ci_orders WHERE id=p_order_id FOR UPDATE;
 IF NOT FOUND OR (p_member_id IS NOT NULL AND o.member_id<>p_member_id) THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
 IF o.status NOT IN ('pending','processing') THEN RAISE EXCEPTION 'INVALID_STATUS_TRANSITION'; END IF;
 SELECT * INTO p FROM public.ci_payments WHERE order_id=o.id FOR UPDATE;
 IF p.status IN ('paid','submitted') THEN RAISE EXCEPTION 'PAYMENT_REQUIRES_REVIEW'; END IF;
 FOR li IN SELECT * FROM public.ci_order_items WHERE order_id=o.id LOOP
  UPDATE public.ci_product_variants SET stock=stock+li.quantity WHERE id=li.variant_id;
 END LOOP;
 UPDATE public.ci_orders SET status='cancelled',cancelled_at=now() WHERE id=o.id;
 UPDATE public.ci_payments SET status='cancelled' WHERE order_id=o.id;
END;$$;
REVOKE ALL ON FUNCTION public.ci_cancel_order_safe(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ci_cancel_order_safe(uuid,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.ci_assign_courier_safe(p_order_id uuid,p_courier_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE o record; c record; p record; new_fee integer;
BEGIN
 SELECT * INTO o FROM public.ci_orders WHERE id=p_order_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
 IF o.fulfillment_type<>'delivery' OR o.status IN ('completed','cancelled') THEN RAISE EXCEPTION 'INVALID_STATUS_TRANSITION'; END IF;
 SELECT * INTO c FROM public.ci_couriers WHERE id=p_courier_id AND active;
 IF NOT FOUND THEN RAISE EXCEPTION 'COURIER_NOT_FOUND'; END IF;
 SELECT * INTO p FROM public.ci_payments WHERE order_id=o.id FOR UPDATE;
 new_fee:=c.flat_fee;
 IF p.method='transfer' AND new_fee<>o.shipping_fee THEN RAISE EXCEPTION 'TRANSFER_FEE_LOCKED'; END IF;
 UPDATE public.ci_orders SET courier_id=c.id,shipping_fee=new_fee,total=subtotal+new_fee WHERE id=o.id RETURNING * INTO o;
 UPDATE public.ci_payments SET amount=o.total WHERE order_id=o.id AND method='cod';
 RETURN to_jsonb(o);
END;$$;
REVOKE ALL ON FUNCTION public.ci_assign_courier_safe(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ci_assign_courier_safe(uuid,uuid) TO service_role;