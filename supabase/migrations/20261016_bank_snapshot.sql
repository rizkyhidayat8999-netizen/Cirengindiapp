-- Preserve the exact beneficiary supplied at checkout for every bank-transfer order.
ALTER TABLE public.ci_payments ADD COLUMN IF NOT EXISTS bank_snapshot jsonb;
CREATE OR REPLACE FUNCTION public.ci_capture_transfer_bank()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF NEW.method='transfer' AND NEW.bank_snapshot IS NULL THEN
  SELECT value INTO NEW.bank_snapshot FROM public.ci_app_settings WHERE key='bank_transfer';
 END IF;
 RETURN NEW;
END;$$;
DROP TRIGGER IF EXISTS ci_payments_bank_capture ON public.ci_payments;
CREATE TRIGGER ci_payments_bank_capture BEFORE INSERT ON public.ci_payments
FOR EACH ROW EXECUTE FUNCTION public.ci_capture_transfer_bank();