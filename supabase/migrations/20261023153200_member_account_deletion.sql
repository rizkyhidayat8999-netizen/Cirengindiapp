-- Allow an account to be deleted while keeping an anonymized transaction record.
-- Personal delivery details and payment proof references are scrubbed by the
-- authenticated Member API before the Auth user is removed.

ALTER TABLE public.ci_orders
  ALTER COLUMN member_id DROP NOT NULL;

ALTER TABLE public.ci_orders
  DROP CONSTRAINT IF EXISTS ci_orders_member_id_fkey;

ALTER TABLE public.ci_orders
  ADD CONSTRAINT ci_orders_member_id_fkey
  FOREIGN KEY (member_id)
  REFERENCES public.member_profiles(user_id)
  ON DELETE SET NULL;

COMMENT ON COLUMN public.ci_orders.member_id IS
  'Member account link. Null after account deletion; non-identifying transaction fields may be retained.';
